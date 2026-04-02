<#
.SYNOPSIS
    Retrieves the software update compliance status for devices in MECM.

.DESCRIPTION
    Queries the MECM site server to return software update compliance details
    for a specific update group, software update, or collection. Useful for
    identifying non-compliant devices ahead of a patching deadline.

.PARAMETER UpdateGroupName
    The name of the software update group to check compliance for.

.PARAMETER CollectionName
    The name of the device collection to scope the report to.

.PARAMETER SiteServer
    The MECM site server hostname.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.PARAMETER NonCompliantOnly
    If specified, returns only devices that are not compliant.

.EXAMPLE
    Get-CMUpdateCompliance -UpdateGroupName "2024-10 Patch Tuesday" -CollectionName "All Workstations"

.EXAMPLE
    Get-CMUpdateCompliance -UpdateGroupName "2024-10 Patch Tuesday" -NonCompliantOnly

.NOTES
    Requires the ConfigurationManager PowerShell module and MECM reporting permissions.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UpdateGroupName,

    [Parameter()]
    [string]$CollectionName,

    [Parameter()]
    [string]$SiteServer = $env:COMPUTERNAME,

    [Parameter()]
    [string]$SiteCode,

    [Parameter()]
    [switch]$NonCompliantOnly
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
}

process {
    try {
        $updateGroup = Get-CMSoftwareUpdateGroup -Name $UpdateGroupName -ErrorAction Stop

        if (-not $updateGroup) {
            Write-Error "Software update group '$UpdateGroupName' not found."
            return
        }

        $complianceParams = @{
            SoftwareUpdateGroupId = $updateGroup.CI_ID
        }

        if ($CollectionName) {
            $collection = Get-CMCollection -Name $CollectionName -ErrorAction Stop
            $complianceParams['CollectionId'] = $collection.CollectionID
        }

        $complianceData = Get-CMSoftwareUpdateComplianceSummary @complianceParams

        $results = foreach ($item in $complianceData) {
            $status = switch ($item.Status) {
                0 { 'Unknown' }
                1 { 'Not Required' }
                2 { 'Required' }
                3 { 'Installed' }
                default { "Status $($item.Status)" }
            }

            $isCompliant = $item.Status -in @(1, 3)

            if ($NonCompliantOnly -and $isCompliant) {
                continue
            }

            [PSCustomObject]@{
                DeviceName      = $item.DeviceName
                UpdateGroup     = $UpdateGroupName
                Status          = $status
                IsCompliant     = $isCompliant
                LastUpdateTime  = $item.LastStatusMessageTime
            }
        }

        $results
    }
    catch {
        Write-Error "Failed to retrieve update compliance data: $_"
    }
}

end {
    Set-Location $originalLocation
}
