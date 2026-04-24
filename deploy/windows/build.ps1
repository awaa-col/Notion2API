[CmdletBinding()]
param(
    [string]$BinaryPath = ""
)

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-Notion2ApiPaths -BinaryPath $BinaryPath
$goExe = Get-Notion2ApiGoExe

Write-Host ("[build] repo   : {0}" -f $paths.RepoRoot)
Write-Host ("[build] go     : {0}" -f $goExe)
Write-Host ("[build] output : {0}" -f $paths.Binary)

Push-Location $paths.RepoRoot
try {
    & $goExe build -o $paths.Binary .\cmd\notion2api
} finally {
    Pop-Location
}

Write-Host "[build] completed"
