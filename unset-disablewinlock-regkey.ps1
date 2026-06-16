# Sets DisableLockWorkstation = 1 in HKCU so Win+L is suppressed.

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RegPath   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
$ValueName = 'DisableLockWorkstation'

try {
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value 1
} catch {
    Write-Error "Failed to set DisableLockWorkstation: $_"
    exit 1
}
