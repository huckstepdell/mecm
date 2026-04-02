<#
.SYNOPSIS
    Triggers an MECM client action on one or more computers.

.DESCRIPTION
    Remotely triggers standard MECM client actions such as machine policy retrieval,
    software update scan, hardware inventory, software inventory, and more on
    target computers via WMI.

.PARAMETER ComputerName
    One or more computer names to target. Accepts pipeline input.

.PARAMETER Action
    The client action to trigger. Valid values:
        MachinePolicy       - Machine Policy Retrieval & Evaluation Cycle
        UserPolicy          - User Policy Retrieval & Evaluation Cycle
        DiscoveryData       - Discovery Data Collection Cycle
        HardwareInventory   - Hardware Inventory Cycle
        SoftwareInventory   - Software Inventory Cycle
        SoftwareUpdateScan  - Software Updates Scan Cycle
        SoftwareUpdateEval  - Software Update Deployment Evaluation Cycle
        ApplicationEval     - Application Deployment Evaluation Cycle
        FileCollection      - File Collection Cycle
        WindowsInstaller    - Windows Installer Source List Update Cycle

.PARAMETER Credential
    Alternate credentials for remote WMI connection.

.EXAMPLE
    Invoke-CMClientAction -ComputerName "DESKTOP-001" -Action MachinePolicy

.EXAMPLE
    "DESKTOP-001", "DESKTOP-002" | Invoke-CMClientAction -Action SoftwareUpdateScan

.EXAMPLE
    Invoke-CMClientAction -ComputerName "DESKTOP-001" -Action HardwareInventory -Credential (Get-Credential)

.NOTES
    Requires WMI/WinRM access to target computers and appropriate permissions.
    The MECM client must be installed and running on the target computers.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter(Mandatory)]
    [ValidateSet(
        'MachinePolicy',
        'UserPolicy',
        'DiscoveryData',
        'HardwareInventory',
        'SoftwareInventory',
        'SoftwareUpdateScan',
        'SoftwareUpdateEval',
        'ApplicationEval',
        'FileCollection',
        'WindowsInstaller'
    )]
    [string]$Action,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential
)

begin {
    # Map action names to their MECM WMI schedule IDs
    $actionMap = @{
        MachinePolicy      = '{00000000-0000-0000-0000-000000000021}'
        UserPolicy         = '{00000000-0000-0000-0000-000000000026}'
        DiscoveryData      = '{00000000-0000-0000-0000-000000000003}'
        HardwareInventory  = '{00000000-0000-0000-0000-000000000001}'
        SoftwareInventory  = '{00000000-0000-0000-0000-000000000002}'
        SoftwareUpdateScan = '{00000000-0000-0000-0000-000000000113}'
        SoftwareUpdateEval = '{00000000-0000-0000-0000-000000000114}'
        ApplicationEval    = '{00000000-0000-0000-0000-000000000121}'
        FileCollection     = '{00000000-0000-0000-0000-000000000010}'
        WindowsInstaller   = '{00000000-0000-0000-0000-000000000032}'
    }

    $scheduleId = $actionMap[$Action]
    $wmiParams = @{
        Namespace  = 'root\ccm'
        Class      = 'SMS_Client'
        Name       = 'TriggerSchedule'
        Arguments  = @($scheduleId)
        ErrorAction = 'Stop'
    }

    if ($Credential) {
        $wmiParams['Credential'] = $Credential
    }
}

process {
    foreach ($computer in $ComputerName) {
        if ($PSCmdlet.ShouldProcess($computer, "Trigger MECM action: $Action")) {
            try {
                $wmiParams['ComputerName'] = $computer
                Invoke-WmiMethod @wmiParams | Out-Null

                [PSCustomObject]@{
                    ComputerName = $computer
                    Action       = $Action
                    Status       = 'Success'
                    Timestamp    = Get-Date
                }
                Write-Verbose "[$computer] Successfully triggered $Action"
            }
            catch {
                [PSCustomObject]@{
                    ComputerName = $computer
                    Action       = $Action
                    Status       = 'Failed'
                    Timestamp    = Get-Date
                }
                Write-Warning "[$computer] Failed to trigger $Action. Error: $_"
            }
        }
    }
}
