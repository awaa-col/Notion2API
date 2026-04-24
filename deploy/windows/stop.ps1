[CmdletBinding()]
param(
    [string]$BinaryPath = "",
    [string]$ConfigPath = "",
    [int]$WaitSeconds = 10
)

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-Notion2ApiPaths -BinaryPath $BinaryPath -ConfigPath $ConfigPath
$stopped = Stop-Notion2ApiProcess -Paths $paths -WaitSeconds $WaitSeconds

if ($stopped) {
    Write-Host "[stop] stopped"
} else {
    Write-Host "[stop] no running process found"
}
