Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Notion2ApiRepoRoot {
    return (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

function Resolve-Notion2ApiPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $Candidate
    }

    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        return [System.IO.Path]::GetFullPath($Candidate)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Candidate))
}

function Get-Notion2ApiPaths {
    param(
        [string]$BinaryPath = "",
        [string]$ConfigPath = ""
    )

    $repoRoot = Get-Notion2ApiRepoRoot
    $runtimeRoot = Join-Path $repoRoot "runtime"
    $logRoot = Join-Path $runtimeRoot "logs"

    if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
        $BinaryPath = Join-Path $repoRoot "notion2api.exe"
    } else {
        $BinaryPath = Resolve-Notion2ApiPath -BasePath $repoRoot -Candidate $BinaryPath
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $candidate = Join-Path $repoRoot "config.json"
        if (Test-Path $candidate) {
            $ConfigPath = $candidate
        } else {
            $ConfigPath = Join-Path $repoRoot "config.example.json"
        }
    } else {
        $ConfigPath = Resolve-Notion2ApiPath -BasePath $repoRoot -Candidate $ConfigPath
    }

    return @{
        RepoRoot  = $repoRoot
        Runtime   = $runtimeRoot
        Logs      = $logRoot
        Binary    = $BinaryPath
        Config    = $ConfigPath
        Pid       = Join-Path $runtimeRoot "notion2api.pid"
        Meta      = Join-Path $runtimeRoot "notion2api.state.json"
        StdoutLog = Join-Path $logRoot "notion2api.stdout.log"
        StderrLog = Join-Path $logRoot "notion2api.stderr.log"
    }
}

function Initialize-Notion2ApiRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths
    )

    foreach ($dir in @($Paths.Runtime, $Paths.Logs, (Join-Path $Paths.RepoRoot "data"), (Join-Path $Paths.RepoRoot "probe_files"))) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
    }
}

function Get-Notion2ApiConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if (-not $config.host) {
        $config | Add-Member -NotePropertyName host -NotePropertyValue "127.0.0.1"
    }
    if (-not $config.port) {
        $config | Add-Member -NotePropertyName port -NotePropertyValue 8787
    }

    return $config
}

function Get-Notion2ApiListenAddress {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Config
    )

    $listenHost = [string]$Config.host
    if ([string]::IsNullOrWhiteSpace($listenHost)) {
        $listenHost = "127.0.0.1"
    }
    $port = [int]$Config.port
    if ($port -le 0) {
        $port = 8787
    }

    $healthHost = $listenHost
    if ($healthHost -eq "0.0.0.0" -or $healthHost -eq "::" -or $healthHost -eq "[::]") {
        $healthHost = "127.0.0.1"
    }

    return @{
        Host       = $listenHost
        Port       = $port
        HealthHost = $healthHost
        HealthUrl  = "http://{0}:{1}/healthz" -f $healthHost, $port
    }
}

function Get-Notion2ApiGoExe {
    $command = Get-Command go.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in @("C:\Program Files\Go\bin\go.exe", "C:\Go\bin\go.exe")) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "go.exe not found. Install Go or add it to PATH."
}

function Get-Notion2ApiPortListener {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    return Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1 LocalAddress, LocalPort, OwningProcess
}

function Get-Notion2ApiRunningProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PidFile,
        [string]$ExpectedBinaryPath = ""
    )

    if (-not (Test-Path $PidFile)) {
        return $null
    }

    $rawPid = (Get-Content $PidFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($rawPid)) {
        return $null
    }

    $pidValue = 0
    if (-not [int]::TryParse($rawPid, [ref]$pidValue)) {
        return $null
    }

    $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if (-not $process) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedBinaryPath)) {
        try {
            $actualPath = $process.Path
            if ($actualPath) {
                $expected = [System.IO.Path]::GetFullPath($ExpectedBinaryPath)
                $actual = [System.IO.Path]::GetFullPath($actualPath)
                if ($actual -ne $expected) {
                    Write-Warning ("PID {0} is running from {1}, expected {2}" -f $process.Id, $actual, $expected)
                }
            }
        } catch {
        }
    }

    return $process
}

function Remove-Notion2ApiStateFiles {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths
    )

    foreach ($path in @($Paths.Pid, $Paths.Meta)) {
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Stop-Notion2ApiProcess {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,
        [int]$WaitSeconds = 10
    )

    $process = Get-Notion2ApiRunningProcess -PidFile $Paths.Pid -ExpectedBinaryPath $Paths.Binary
    if (-not $process) {
        Remove-Notion2ApiStateFiles -Paths $Paths
        return $false
    }

    Stop-Process -Id $process.Id -Force

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            break
        }
        Start-Sleep -Milliseconds 300
    }

    Remove-Notion2ApiStateFiles -Paths $Paths
    return $true
}

function Write-Notion2ApiState {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [hashtable]$Listen
    )

    Set-Content -LiteralPath $Paths.Pid -Value $Process.Id -Encoding ascii

    $state = [ordered]@{
        pid        = $Process.Id
        started_at = (Get-Date).ToString("o")
        binary     = $Paths.Binary
        config     = $Paths.Config
        health_url = $Listen.HealthUrl
        stdout_log = $Paths.StdoutLog
        stderr_log = $Paths.StderrLog
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $Paths.Meta -Encoding utf8
}
