[CmdletBinding()]
param(
    [string]$BinaryPath = "",
    [string]$ConfigPath = "",
    [switch]$BuildIfMissing,
    [int]$StartupTimeoutSec = 15
)

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-Notion2ApiPaths -BinaryPath $BinaryPath -ConfigPath $ConfigPath
[void](Stop-Notion2ApiProcess -Paths $paths)
& (Join-Path $PSScriptRoot "start.ps1") -BinaryPath $paths.Binary -ConfigPath $paths.Config -BuildIfMissing:$BuildIfMissing -StartupTimeoutSec $StartupTimeoutSec
