[CmdletBinding()]
param(
    [string]$BinaryPath = "",
    [string]$ConfigPath = ""
)

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-Notion2ApiPaths -BinaryPath $BinaryPath -ConfigPath $ConfigPath
$config = Get-Notion2ApiConfig -ConfigPath $paths.Config
$listen = Get-Notion2ApiListenAddress -Config $config
$process = Get-Notion2ApiRunningProcess -PidFile $paths.Pid -ExpectedBinaryPath $paths.Binary

$health = "unreachable"
try {
    $response = Invoke-WebRequest -Uri $listen.HealthUrl -UseBasicParsing -TimeoutSec 3
    $health = "{0} ({1})" -f $response.StatusCode, $listen.HealthUrl
} catch {
    $health = "unreachable ($($listen.HealthUrl))"
}

Write-Host ("[status] binary : {0}" -f $paths.Binary)
Write-Host ("[status] config : {0}" -f $paths.Config)
Write-Host ("[status] pidfile: {0}" -f $paths.Pid)
Write-Host ("[status] health : {0}" -f $health)

if ($process) {
    Write-Host ("[status] state  : running (PID {0})" -f $process.Id)
} else {
    Write-Host "[status] state  : stopped"
}

if (Test-Path $paths.StdoutLog) {
    Write-Host ("[status] stdout : {0}" -f $paths.StdoutLog)
}
if (Test-Path $paths.StderrLog) {
    Write-Host ("[status] stderr : {0}" -f $paths.StderrLog)
}
