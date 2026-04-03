dsregcmd /join /debug | Out-File -FilePath "C:\Windows\Temp\dsregcmd-join-osd.log" -Encoding UTF8

$taskName = "\Microsoft\Windows\Workplace Join\Automatic-Device-Join"

try {
    $task = Get-ScheduledTask -TaskName "Automatic-Device-Join" -TaskPath "\Microsoft\Windows\Workplace Join\" -ErrorAction Stop
    Start-ScheduledTask -InputObject $task
    "[$(Get-Date)] Started scheduled task: $taskName" | Out-File -FilePath "C:\Windows\Temp\dsregcmd-join-osd.log" -Append -Encoding UTF8
}
catch {
    "[$(Get-Date)] FAILED to start scheduled task $taskName : $($_.Exception.Message)" | Out-File -FilePath "C:\Windows\Temp\dsregcmd-join-osd.log" -Append -Encoding UTF8
    exit 1
}
