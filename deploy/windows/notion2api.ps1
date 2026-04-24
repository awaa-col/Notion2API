[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("build", "start", "stop", "status", "restart")]
    [string]$Action = "status",
    [string]$BinaryPath = "",
    [string]$ConfigPath = "",
    [switch]$BuildIfMissing,
    [switch]$Force,
    [int]$StartupTimeoutSec = 15,
    [int]$WaitSeconds = 10
)

. (Join-Path $PSScriptRoot "common.ps1")

switch ($Action) {
    "build" {
        & (Join-Path $PSScriptRoot "build.ps1") -BinaryPath $BinaryPath
    }
    "start" {
        & (Join-Path $PSScriptRoot "start.ps1") `
            -BinaryPath $BinaryPath `
            -ConfigPath $ConfigPath `
            -BuildIfMissing:$BuildIfMissing `
            -Force:$Force `
            -StartupTimeoutSec $StartupTimeoutSec
    }
    "stop" {
        & (Join-Path $PSScriptRoot "stop.ps1") `
            -BinaryPath $BinaryPath `
            -ConfigPath $ConfigPath `
            -WaitSeconds $WaitSeconds
    }
    "status" {
        & (Join-Path $PSScriptRoot "status.ps1") `
            -BinaryPath $BinaryPath `
            -ConfigPath $ConfigPath
    }
    "restart" {
        & (Join-Path $PSScriptRoot "restart.ps1") `
            -BinaryPath $BinaryPath `
            -ConfigPath $ConfigPath `
            -BuildIfMissing:$BuildIfMissing `
            -StartupTimeoutSec $StartupTimeoutSec
    }
}
