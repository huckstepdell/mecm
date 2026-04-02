<#
.SYNOPSIS
    Removes inactive or stale MECM client records from the database.

.DESCRIPTION
    Identifies MECM devices that have not been active for a specified number
    of days and optionally removes them from the MECM database. Useful for
    keeping the MECM device inventory clean by removing retired or decommissioned
    computers.

.PARAMETER InactiveDays
    Number of days of inactivity before a device is considered stale.
    Default is 90 days.

.PARAMETER CollectionName
    Scope the cleanup to a specific collection. If not specified,
    all managed devices are evaluated.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.PARAMETER WhatIf
    Shows what devices would be removed without actually removing them.

.EXAMPLE
    Remove-CMStaleDevices -InactiveDays 90 -SiteCode "PS1"

.EXAMPLE
    Remove-CMStaleDevices -InactiveDays 60 -CollectionName "All Workstations" -WhatIf

.NOTES
    Requires the ConfigurationManager PowerShell module and MECM full administrator rights.
    Removed devices can be re-added if the client re-registers with the site.
    Always use -WhatIf first to review what will be deleted before running.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [int]$InactiveDays = 90,

    [Parameter()]
    [string]$CollectionName,

    [Parameter()]
    [string]$SiteCode
)

begin {
    if (-not (Get-Module -Name ConfigurationManager)) {
        try {
            Import-Module "$($env:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
        }
        catch {
            throw "Failed to import ConfigurationManager module. Error: $_"
        }
    }

    if (-not $SiteCode) {
        $SiteCode = (Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue | Select-Object -First 1).Name
        if (-not $SiteCode) {
            throw "Could not detect site code. Please provide the -SiteCode parameter."
        }
    }

    $originalLocation = Get-Location
    Set-Location "$($SiteCode):\"

    $cutoffDate = (Get-Date).AddDays(-$InactiveDays)
}

process {
    try {
        $deviceParams = @{}
        if ($CollectionName) {
            $deviceParams['CollectionName'] = $CollectionName
        }

        $allDevices = Get-CMDevice @deviceParams -ErrorAction Stop

        $staleDevices = $allDevices | Where-Object {
            $_.LastActiveTime -lt $cutoffDate -or -not $_.LastActiveTime
        }

        Write-Host "Found $($staleDevices.Count) stale device(s) inactive for more than $InactiveDays days."

        $results = foreach ($device in $staleDevices) {
            if ($PSCmdlet.ShouldProcess($device.Name, "Remove stale MECM device record")) {
                try {
                    Remove-CMDevice -InputObject $device -Force -ErrorAction Stop

                    [PSCustomObject]@{
                        ComputerName   = $device.Name
                        LastActiveTime = $device.LastActiveTime
                        Status         = 'Removed'
                        Timestamp      = Get-Date
                    }
                    Write-Verbose "Removed stale device: $($device.Name) (Last active: $($device.LastActiveTime))"
                }
                catch {
                    [PSCustomObject]@{
                        ComputerName   = $device.Name
                        LastActiveTime = $device.LastActiveTime
                        Status         = "Failed: $_"
                        Timestamp      = Get-Date
                    }
                    Write-Warning "Failed to remove device '$($device.Name)'. Error: $_"
                }
            }
            else {
                [PSCustomObject]@{
                    ComputerName   = $device.Name
                    LastActiveTime = $device.LastActiveTime
                    Status         = 'WhatIf'
                    Timestamp      = Get-Date
                }
            }
        }

        $results
    }
    catch {
        Write-Error "Failed to retrieve or remove stale devices: $_"
    }
}

end {
    Set-Location $originalLocation
}
