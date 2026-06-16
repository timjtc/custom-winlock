# Re-enables Win+L temporarily for custom lock logic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RegPath   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
$ValueName = 'DisableLockWorkstation'

try {
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value 0

    $current = (Get-ItemProperty -Path $RegPath -Name $ValueName).$ValueName
    if ($current -ne 0) {
        throw "Registry write appeared to succeed but value is still '$current'."
    }
} catch {
    Write-Error "Failed to re-enable workstation lock: $_"
    exit 1
}

Start-Process -FilePath 'rundll32.exe' -ArgumentList 'user32.dll,LockWorkStation' -WindowStyle Hidden