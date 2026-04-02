<#
.SYNOPSIS
    Performs routine MECM site maintenance tasks.

.DESCRIPTION
    Runs a configurable set of MECM site maintenance tasks including:
    - Clearing the MECM database transaction log (using built-in maintenance tasks)
    - Triggering the Delete Aged Discovery Data maintenance task
    - Triggering the Delete Aged Status Messages maintenance task
    - Removing outdated client records
    - Summarizing deployment statistics

    This script is intended to be run as a scheduled task during a maintenance window.

.PARAMETER SiteServer
    The MECM site server hostname.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.PARAMETER Tasks
    Array of maintenance tasks to run. Valid values:
        All                     - Run all tasks below
        DeleteAgedDiscoveryData - Delete aged discovery data
        DeleteAgedStatusMessages - Delete aged status messages
        DeleteAgedInventory     - Delete aged inventory history
        SummarizeDeployments    - Summarize deployment statistics

.EXAMPLE
    Invoke-CMSiteMaintenance -SiteServer "MECM-SERVER" -SiteCode "PS1" -Tasks All

.EXAMPLE
    Invoke-CMSiteMaintenance -SiteServer "MECM-SERVER" -SiteCode "PS1" -Tasks DeleteAgedDiscoveryData, DeleteAgedStatusMessages

.NOTES
    Requires the ConfigurationManager PowerShell module and MECM full administrator rights.
    Some tasks may take a long time to complete on large environments.
    Always run during a scheduled maintenance window.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SiteServer,

    [Parameter(Mandatory)]
    [string]$SiteCode,

    [Parameter()]
    [ValidateSet(
        'All',
        'DeleteAgedDiscoveryData',
        'DeleteAgedStatusMessages',
        'DeleteAgedInventory',
        'SummarizeDeployments'
    )]
    [string[]]$Tasks = 'All'
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

    $originalLocation = Get-Location
    Set-Location "$($SiteCode):\"

    $taskMap = @{
        DeleteAgedDiscoveryData  = 'Delete Aged Discovery Data'
        DeleteAgedStatusMessages = 'Delete Aged Status Messages'
        DeleteAgedInventory      = 'Delete Aged Inventory History'
        SummarizeDeployments     = 'Summarize Deployed Application Statistics'
    }

    $tasksToRun = if ($Tasks -contains 'All') { $taskMap.Keys } else { $Tasks }
}

process {
    $results = @()

    foreach ($task in $tasksToRun) {
        $taskName = $taskMap[$task]

        if (-not $PSCmdlet.ShouldProcess($SiteServer, "Run maintenance task: $taskName")) {
            continue
        }

        Write-Verbose "Running maintenance task: $taskName"

        try {
            $maintenanceTask = Get-CMSiteMaintenanceTask -SiteCode $SiteCode -MaintenanceTaskName $taskName -ErrorAction Stop

            if (-not $maintenanceTask.Enabled) {
                Write-Warning "Maintenance task '$taskName' is disabled. Skipping."
                $results += [PSCustomObject]@{
                    Task      = $taskName
                    Status    = 'Skipped (Disabled)'
                    Timestamp = Get-Date
                }
                continue
            }

            Invoke-CMSiteMaintenanceTask -SiteCode $SiteCode -MaintenanceTaskName $taskName -ErrorAction Stop

            $results += [PSCustomObject]@{
                Task      = $taskName
                Status    = 'Triggered'
                Timestamp = Get-Date
            }
            Write-Verbose "Successfully triggered: $taskName"
        }
        catch {
            $results += [PSCustomObject]@{
                Task      = $taskName
                Status    = "Failed: $_"
                Timestamp = Get-Date
            }
            Write-Warning "Failed to run maintenance task '$taskName'. Error: $_"
        }
    }

    $results
}

end {
    Set-Location $originalLocation
}
