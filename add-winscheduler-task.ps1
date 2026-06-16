# Registers a Task Scheduler task that sets DisableLockWorkstation = 1 in HKCU
# on every logon and session unlock for Win+L custom hotkeys
#
# Run once as admin. After this, all subsequent registry writes (winlock.ps1,
# the scheduled task) run without elevation.

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName = 'Restore-DisableLockWorkstation'
$TaskPath = '\'
$RegPath  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'

# Fix ACL — grant current user FullControl on the Policies\System key
Write-Host "Fixing ACL on $RegPath..."

try {
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    $Acl  = Get-Acl -Path $RegPath
    $Rule = New-Object System.Security.AccessControl.RegistryAccessRule(
        "$env:USERDOMAIN\$env:USERNAME",
        'FullControl',
        'ContainerInherit,ObjectInherit',
        'None',
        'Allow'
    )
    $Acl.SetAccessRule($Rule)
    Set-Acl -Path $RegPath -AclObject $Acl

    # Verify
    $UpdatedAcl = Get-Acl -Path $RegPath
    $HasFullControl = $UpdatedAcl.Access | Where-Object {
        $_.IdentityReference -like "*$env:USERNAME*" -and
        $_.RegistryRights    -eq 'FullControl' -and
        $_.AccessControlType -eq 'Allow'
    }
    if (-not $HasFullControl) {
        throw "ACL was set but FullControl rule for '$env:USERNAME' was not found afterwards."
    }

    Write-Host "  ACL updated: $env:USERDOMAIN\$env:USERNAME now has FullControl."
} catch {
    Write-Error "Failed to update ACL: $_"
    exit 1
}

# Register the scheduled task
Write-Host "Registering scheduled task '$TaskName'..."

# Inline action: the ACL fix above guarantees the key exists and is writable,
# so the task just needs to set the value — no path creation or elevation needed.
$InlineCommand = @'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisableLockWorkstation' -Value 1
'@

$Action = New-ScheduledTaskAction `
    -Execute  'powershell.exe' `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$InlineCommand`""

# Trigger 1: on logon of this specific user
$TriggerLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit    (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -MultipleInstances     IgnoreNew `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd

# Limited = no UAC elevation; ACL fix above ensures HKCU write succeeds without it
$Principal = New-ScheduledTaskPrincipal `
    -UserId    "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel  Limited

# Remove existing task cleanly before re-registering
if (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing task '$TaskName'..."
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
}

# Register with the logon trigger first
Register-ScheduledTask `
    -TaskName  $TaskName `
    -TaskPath  $TaskPath `
    -Action    $Action `
    -Trigger   $TriggerLogon `
    -Settings  $Settings `
    -Principal $Principal | Out-Null

# Patch in the SessionUnlock trigger via XML — no native cmdlet exposes this trigger type
$TaskXml = [xml](Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath)
$Ns      = 'http://schemas.microsoft.com/windows/2004/02/mit/task'

$UnlockTrigger                         = $TaskXml.CreateElement('SessionStateChangeTrigger', $Ns)
$EnabledNode                           = $TaskXml.CreateElement('Enabled', $Ns)
$EnabledNode.InnerText                 = 'true'
$StateChangeNode                       = $TaskXml.CreateElement('StateChange', $Ns)
$StateChangeNode.InnerText             = 'SessionUnlock'
$UnlockTrigger.AppendChild($EnabledNode)     | Out-Null
$UnlockTrigger.AppendChild($StateChangeNode) | Out-Null
$TaskXml.Task.Triggers.AppendChild($UnlockTrigger) | Out-Null

# Re-register with the patched XML containing both triggers
Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath $TaskPath `
    -Xml      $TaskXml.OuterXml `
    -Force | Out-Null

# Confirm
$Imported = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
if ($Imported) {
    Write-Host "Task '$TaskName' registered successfully."
    Write-Host "  Run As   : $($Imported.Principal.UserId)"
    Write-Host "  Triggers : $(($Imported.Triggers | ForEach-Object { $_.GetType().Name }) -join ', ')"
    Write-Host ""
    Write-Host "Setup complete. winlock.ps1 and the scheduled task no longer need elevation."
} else {
    Write-Error "Task registration failed."
    exit 1
}

# Import variables declared in local-use-dest.ps1 to place a copy of winlock.ps1 by custom app/window manager.
. "$PSScriptRoot\local-use-dest.ps1"

# Copy winlock.ps1 to defined path in local-use-dest.ps1 $Destination
# Create the destination folder if it doesn't exist
$Source = Join-Path $PSScriptRoot 'winlock.ps1'
if (-not (Test-Path (Split-Path $Destination))) {
    New-Item -ItemType Directory -Path (Split-Path $Destination) | Out-Null
}
Copy-Item -Path $Source -Destination $Destination | Out-Null
if (Test-Path $Destination) {
    Write-Host "winlock.ps1 copied to $Destination successfully."
} else {
    Write-Error "Failed to copy winlock.ps1 to $Destination."
    exit 1
}