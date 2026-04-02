<#
.SYNOPSIS
    Adds one or more computers to an MECM device collection as direct membership rules.

.DESCRIPTION
    Creates direct membership rules in an MECM device collection for one or
    more specified computer names. If a computer is already a direct member,
    it is skipped with a warning.

.PARAMETER ComputerName
    One or more computer names to add to the collection. Accepts pipeline input.

.PARAMETER CollectionName
    The name of the target MECM device collection.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.EXAMPLE
    Add-CMDeviceToCollection -ComputerName "DESKTOP-001" -CollectionName "Pilot Group"

.EXAMPLE
    "DESKTOP-001", "DESKTOP-002" | Add-CMDeviceToCollection -CollectionName "Pilot Group"

.EXAMPLE
    Get-Content .\computers.txt | Add-CMDeviceToCollection -CollectionName "Patch Group A"

.NOTES
    Requires the ConfigurationManager PowerShell module and appropriate MECM permissions.
    Collection membership updates may take time to reflect depending on the
    collection update schedule.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter(Mandatory)]
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

    $collection = Get-CMDeviceCollection -Name $CollectionName -ErrorAction Stop
    if (-not $collection) {
        throw "Collection '$CollectionName' not found."
    }
}

process {
    foreach ($computer in $ComputerName) {
        if (-not $PSCmdlet.ShouldProcess($computer, "Add to collection '$CollectionName'")) {
            continue
        }

        try {
            $device = Get-CMDevice -Name $computer -ErrorAction Stop
            if (-not $device) {
                Write-Warning "[$computer] Device not found in MECM. Skipping."
                continue
            }

            # Check if already a direct member
            $existingRule = Get-CMDeviceCollectionDirectMembershipRule `
                -CollectionName $CollectionName `
                -ResourceId $device.ResourceID `
                -ErrorAction SilentlyContinue

            if ($existingRule) {
                Write-Warning "[$computer] Already a direct member of '$CollectionName'. Skipping."
                continue
            }

            Add-CMDeviceCollectionDirectMembershipRule `
                -CollectionName $CollectionName `
                -ResourceId $device.ResourceID `
                -ErrorAction Stop

            [PSCustomObject]@{
                ComputerName   = $computer
                CollectionName = $CollectionName
                Status         = 'Added'
                Timestamp      = Get-Date
            }
            Write-Verbose "[$computer] Added to '$CollectionName'."
        }
        catch {
            [PSCustomObject]@{
                ComputerName   = $computer
                CollectionName = $CollectionName
                Status         = 'Failed'
                Timestamp      = Get-Date
            }
            Write-Warning "[$computer] Failed to add to collection. Error: $_"
        }
    }
}

end {
    Set-Location $originalLocation
}
