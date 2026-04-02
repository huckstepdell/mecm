<#
.SYNOPSIS
    Retrieves members of one or more MECM device or user collections.

.DESCRIPTION
    Queries the MECM site server to list all members of the specified
    device or user collections. Output can be exported to CSV for reporting.

.PARAMETER CollectionName
    The name of one or more collections to query. Supports wildcards.

.PARAMETER CollectionId
    One or more collection IDs to query (e.g. "SMS00001").

.PARAMETER CollectionType
    Filter by collection type. Valid values: Device, User, Any.
    Default is Any.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.EXAMPLE
    Get-CMCollectionMembers -CollectionName "All Workstations"

.EXAMPLE
    Get-CMCollectionMembers -CollectionName "All *" -CollectionType Device

.EXAMPLE
    Get-CMCollectionMembers -CollectionId "SMS00001"

.EXAMPLE
    Get-CMCollectionMembers -CollectionName "All Workstations" | Export-Csv -Path ".\members.csv" -NoTypeInformation

.NOTES
    Requires the ConfigurationManager PowerShell module and appropriate MECM permissions.
#>
[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(ParameterSetName = 'ByName', Mandatory)]
    [SupportsWildcards()]
    [string[]]$CollectionName,

    [Parameter(ParameterSetName = 'ById', Mandatory)]
    [string[]]$CollectionId,

    [Parameter()]
    [ValidateSet('Device', 'User', 'Any')]
    [string]$CollectionType = 'Any',

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

    $typeFilter = switch ($CollectionType) {
        'Device' { 2 }
        'User'   { 1 }
        default  { $null }
    }
}

process {
    try {
        $collections = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            foreach ($name in $CollectionName) {
                Get-CMCollection -Name $name -ErrorAction SilentlyContinue |
                    Where-Object { -not $typeFilter -or $_.CollectionType -eq $typeFilter }
            }
        }
        else {
            foreach ($id in $CollectionId) {
                Get-CMCollection -Id $id -ErrorAction SilentlyContinue |
                    Where-Object { -not $typeFilter -or $_.CollectionType -eq $typeFilter }
            }
        }

        foreach ($collection in $collections) {
            $members = Get-CMCollectionMember -CollectionId $collection.CollectionID -ErrorAction Stop

            foreach ($member in $members) {
                [PSCustomObject]@{
                    CollectionName = $collection.Name
                    CollectionId   = $collection.CollectionID
                    MemberName     = $member.Name
                    ResourceId     = $member.ResourceID
                    Domain         = $member.Domain
                    IsActive       = $member.IsActive
                    LastLogonUser  = $member.LastLogonUserName
                }
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve collection members: $_"
    }
}

end {
    Set-Location $originalLocation
}
