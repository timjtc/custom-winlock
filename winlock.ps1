# CONFIG
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$valueName = "DisableLockWorkstation"

# ensure admin
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    exit 1
}

# enable lock temporarily
Set-ItemProperty -Path $regPath -Name $valueName -Value 0

# force policy refresh
Start-Process "gpupdate.exe" -ArgumentList "/target:computer /force" -WindowStyle Hidden

# wait + verify
$maxWait = 5
$elapsed = 0
$success = $false

while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds 1
    $elapsed++

    $check = (Get-ItemProperty -Path $regPath -Name $valueName).$valueName
    if ($check -eq 0) {
        $success = $true
        break
    }
}

# lock fallback logic
if ($success) {
    Start-Process "rundll32.exe" "user32.dll,LockWorkStation"
} else {
    # fallback: always lock even if policy didn't reflect
    rundll32.exe user32.dll,LockWorkStation
}