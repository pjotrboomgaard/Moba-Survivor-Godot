# Hook: alert when the Cursor agent finishes a task.
# Fires on the "stop" event. Shows a Windows tray notification balloon and plays
# a system sound. Best-effort: never blocks the agent.
$ErrorActionPreference = "SilentlyContinue"

$done = "Cursor agent finished its task."

# 1) Play a system "correct" beep so it's audible.
try { [System.Media.SystemSounds]::Correct.Play() } catch {}

# 2) Show a tray balloon notification (NotifyIcon). This works reliably on
#    Windows without needing msg.exe or WinRT activation factories.
try {
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Application
    $notify.Visible = $true
    $notify.ShowBalloonTip(6000, "Cursor agent done", $done, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 6
    $notify.Dispose()
} catch {}

exit 0
