This is a set of PowerShell scripts written because I just wanted to use Vim-style keybinds (Win+HJKL) in GlazeWM, but the Win+L bind is hardcoded by Windows for locking the workstation.


Usage:

1. Check `local-use-dest.ps1` and update the `$Destination` variable to a location of your choice (it is currently set to glazewm's local config dir, change if you use a different window manager like komorebi, etc.).

2. Run `add-winscheduler-task.ps1` with admin privileges to set up a scheduled task that sets `DisableLockWorkstation` in the Windows registry.

3. Modify your window manager / hotkey software configs to run `winlock.ps1` when you want to lock the workstation (e.g. I bound Win+Alt+L to run `winlock.ps1` in GlazeWM).