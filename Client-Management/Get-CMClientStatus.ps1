<#
.SYNOPSIS
    Retrieves the MECM/SCCM client health status for one or more computers.

.DESCRIPTION
    Queries the MECM site server to return client health information including
    client activity, client check results, and last policy request time for
    the specified computers or collection.

.PARAMETER ComputerName
    One or more computer names to query. Accepts pipeline input.

.PARAMETER CollectionName
    The name of an MECM device collection to query.

.PARAMETER SiteServer
    The MECM site server hostname. Defaults to the current site server.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1"). Defaults to the current site code.

.EXAMPLE
    Get-CMClientStatus -ComputerName "DESKTOP-001", "DESKTOP-002"

.EXAMPLE
    Get-CMClientStatus -CollectionName "All Workstations"

.EXAMPLE
    "DESKTOP-001" | Get-CMClientStatus

.NOTES
    Requires the ConfigurationManager PowerShell module and appropriate MECM permissions.
#>
[CmdletBinding(DefaultParameterSetName = 'ByComputerName')]
param(
    [Parameter(ParameterSetName = 'ByComputerName', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter(ParameterSetName = 'ByCollection', Mandatory)]
    [string]$CollectionName,

    [Parameter()]
    [string]$SiteServer = $env:COMPUTERNAME,

    [Parameter()]
    [string]$SiteCode
)

begin {
    # Import the ConfigurationManager module if not already loaded
    if (-not (Get-Module -Name ConfigurationManager)) {
        try {
            Import-Module "$($env:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
        }
        catch {
            throw "Failed to import ConfigurationManager module. Ensure MECM admin console is installed. Error: $_"
        }
    }

    # Detect site code if not provided
    if (-not $SiteCode) {
        $SiteCode = (Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue | Select-Object -First 1).Name
        if (-not $SiteCode) {
            throw "Could not detect site code. Please provide the -SiteCode parameter."
        }
    }

    $originalLocation = Get-Location
    Set-Location "$($SiteCode):\"
}

process {
    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByCollection') {
            $devices = Get-CMDevice -CollectionName $CollectionName -ErrorAction Stop
        }
        else {
            $devices = foreach ($name in $ComputerName) {
                Get-CMDevice -Name $name -ErrorAction SilentlyContinue
            }
        }

        foreach ($device in $devices) {
            [PSCustomObject]@{
                ComputerName         = $device.Name
                ClientVersion        = $device.ClientVersion
                IsActive             = $device.IsActive
                ClientCheckPassed    = $device.ClientCheckPass
                LastActiveTime       = $device.LastActiveTime
                LastPolicyRequest    = $device.LastPolicyRequest
                OSName               = $device.OperatingSystemNameandVersion
                IsVirtualMachine     = $device.IsVirtualMachine
                SiteCode             = $device.SiteCode
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve client status: $_"
    }
}

end {
    Set-Location $originalLocation
}
