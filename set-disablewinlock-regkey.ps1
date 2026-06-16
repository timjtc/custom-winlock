# Ask the user if they want to disable or enable the Win+L lock shortcut with a menu option (1 or 2)

#Requires -RunAsAdministrator

Write-Host "1. Disable Win+L lock shortcut"
Write-Host "2. Enable Win+L lock shortcut"
$Choice = Read-Host "Select an option: "
if ($Choice -eq "1") {
    $Value = 1
} elseif ($Choice -eq "2") {
    $Value = 0
} else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit
}

# Create registry path and value
$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$Name = "DisableLockWorkstation"

# Create path if it doesn't exist
if (-not (Test-Path $Path)) {
    New-Item -Path $Path -Force | Out-Null
}

# Set registry value
New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWORD -Force | Out-Null
Write-Host "Successfully disabled Win+L lock shortcut." -ForegroundColor Green
