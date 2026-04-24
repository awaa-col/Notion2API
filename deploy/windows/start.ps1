[CmdletBinding()]
param(
    [string]$BinaryPath = "",
    [string]$ConfigPath = "",
    [switch]$BuildIfMissing,
    [switch]$Force,
    [int]$StartupTimeoutSec = 15
)

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-Notion2ApiPaths -BinaryPath $BinaryPath -ConfigPath $ConfigPath
Initialize-Notion2ApiRuntime -Paths $paths

if (-not (Test-Path $paths.Config)) {
    throw "Config file not found: $($paths.Config)"
}

if (-not (Test-Path $paths.Binary)) {
    if ($BuildIfMissing) {
        & (Join-Path $PSScriptRoot "build.ps1") -BinaryPath $paths.Binary
    } else {
        throw "Binary not found: $($paths.Binary). Run build.ps1 first or use -BuildIfMissing."
    }
}

$config = Get-Notion2ApiConfig -ConfigPath $paths.Config
$listen = Get-Notion2ApiListenAddress -Config $config
$running = Get-Notion2ApiRunningProcess -PidFile $paths.Pid -ExpectedBinaryPath $paths.Binary
$listener = Get-Notion2ApiPortListener -Port $listen.Port

if ($running) {
    if ($Force) {
        [void](Stop-Notion2ApiProcess -Paths $paths)
    } else {
        throw "Notion2API is already running with PID $($running.Id). Use stop.ps1 first or rerun with -Force."
    }
}

if ($listener) {
    throw "Port $($listen.Port) is already in use by PID $($listener.OwningProcess). Stop that process before starting Notion2API."
}

Write-Host ("[start] binary : {0}" -f $paths.Binary)
Write-Host ("[start] config : {0}" -f $paths.Config)
Write-Host ("[start] health : {0}" -f $listen.HealthUrl)

$process = Start-Process `
    -FilePath $paths.Binary `
    -ArgumentList @("--config", $paths.Config) `
    -WorkingDirectory $paths.RepoRoot `
    -RedirectStandardOutput $paths.StdoutLog `
    -RedirectStandardError $paths.StderrLog `
    -PassThru

Write-Notion2ApiState -Paths $paths -Process $process -Listen $listen

$deadline = (Get-Date).AddSeconds($StartupTimeoutSec)
$healthy = $false

while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 700

    $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if (-not $current) {
        Remove-Notion2ApiStateFiles -Paths $paths
        throw "Process exited during startup. Check $($paths.StderrLog)"
    }

    try {
        $response = Invoke-WebRequest -Uri $listen.HealthUrl -UseBasicParsing -TimeoutSec 3
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            $healthy = $true
            break
        }
    } catch {
    }
}

if (-not $healthy) {
    Write-Warning ("Startup health check timed out. Process is still running with PID {0}. Check {1}" -f $process.Id, $listen.HealthUrl)
} else {
    Write-Host ("[start] running with PID {0}" -f $process.Id)
}

Write-Host ("[start] stdout : {0}" -f $paths.StdoutLog)
Write-Host ("[start] stderr : {0}" -f $paths.StderrLog)
