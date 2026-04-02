<#
.SYNOPSIS
    Triggers a software update scan and/or installation on remote MECM clients.

.DESCRIPTION
    Remotely triggers a software update scan cycle, optionally followed by an
    update deployment evaluation cycle on target computers via WMI. This is
    useful for forcing clients to check for and apply pending updates outside
    of their regular maintenance window.

.PARAMETER ComputerName
    One or more computer names to target. Accepts pipeline input.

.PARAMETER ScanOnly
    If specified, only triggers the Software Updates Scan Cycle without
    triggering the deployment evaluation cycle.

.PARAMETER Credential
    Alternate credentials for remote WMI connection.

.EXAMPLE
    Invoke-CMSoftwareUpdateScan -ComputerName "DESKTOP-001"

.EXAMPLE
    "DESKTOP-001", "DESKTOP-002" | Invoke-CMSoftwareUpdateScan -ScanOnly

.EXAMPLE
    Invoke-CMSoftwareUpdateScan -ComputerName "DESKTOP-001" -Credential (Get-Credential)

.NOTES
    Requires WMI access to the target computers and the MECM client installed.
    The scan may take several minutes to complete depending on network conditions.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [switch]$ScanOnly,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential
)

begin {
    $wmiBase = @{
        Namespace  = 'root\ccm'
        Class      = 'SMS_Client'
        Name       = 'TriggerSchedule'
        ErrorAction = 'Stop'
    }

    if ($Credential) {
        $wmiBase['Credential'] = $Credential
    }

    $scanScheduleId = '{00000000-0000-0000-0000-000000000113}'
    $evalScheduleId = '{00000000-0000-0000-0000-000000000114}'
}

process {
    foreach ($computer in $ComputerName) {
        if (-not $PSCmdlet.ShouldProcess($computer, "Trigger software update scan")) {
            continue
        }

        $wmiParams = $wmiBase.Clone()
        $wmiParams['ComputerName'] = $computer

        try {
            # Trigger Software Updates Scan Cycle
            $wmiParams['Arguments'] = @($scanScheduleId)
            Invoke-WmiMethod @wmiParams | Out-Null
            Write-Verbose "[$computer] Software Updates Scan Cycle triggered."

            if (-not $ScanOnly) {
                # Brief pause before triggering deployment evaluation
                Start-Sleep -Seconds 2

                # Trigger Software Update Deployment Evaluation Cycle
                $wmiParams['Arguments'] = @($evalScheduleId)
                Invoke-WmiMethod @wmiParams | Out-Null
                Write-Verbose "[$computer] Software Update Deployment Evaluation Cycle triggered."
            }

            [PSCustomObject]@{
                ComputerName = $computer
                ScanOnly     = $ScanOnly.IsPresent
                Status       = 'Success'
                Timestamp    = Get-Date
            }
        }
        catch {
            [PSCustomObject]@{
                ComputerName = $computer
                ScanOnly     = $ScanOnly.IsPresent
                Status       = 'Failed'
                Timestamp    = Get-Date
            }
            Write-Warning "[$computer] Failed to trigger software update scan. Error: $_"
        }
    }
}
