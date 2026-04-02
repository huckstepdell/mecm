<#
.SYNOPSIS
    Generates a hardware inventory report for MECM-managed devices.

.DESCRIPTION
    Queries the MECM site server WMI (SMS Provider) to produce a hardware
    inventory report including CPU, RAM, disk space, OS, and BIOS information
    for devices in a specified collection.

.PARAMETER CollectionName
    The name of the MECM device collection to report on.

.PARAMETER SiteServer
    The MECM site server (SMS Provider) hostname.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.PARAMETER ExportPath
    If specified, exports the report to a CSV file at the given path.

.EXAMPLE
    Get-CMHardwareInventoryReport -CollectionName "All Workstations" -SiteServer "MECM-SERVER"

.EXAMPLE
    Get-CMHardwareInventoryReport -CollectionName "All Servers" -SiteServer "MECM-SERVER" -ExportPath "C:\Reports\HWInventory.csv"

.NOTES
    Requires WMI access to the SMS Provider on the site server and
    the ConfigurationManager PowerShell module.
    Hardware inventory must be enabled and have run on client devices.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CollectionName,

    [Parameter(Mandatory)]
    [string]$SiteServer,

    [Parameter()]
    [string]$SiteCode,

    [Parameter()]
    [string]$ExportPath
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
        $collection = Get-CMDeviceCollection -Name $CollectionName -ErrorAction Stop
        if (-not $collection) {
            throw "Collection '$CollectionName' not found."
        }

        $members = Get-CMCollectionMember -CollectionId $collection.CollectionID -ErrorAction Stop

        $report = foreach ($member in $members) {
            $resourceId = $member.ResourceID

            # Query hardware inventory from SMS Provider
            $computer = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_COMPUTER_SYSTEM `
                -Filter "ResourceID = '$resourceId'" `
                -ErrorAction SilentlyContinue

            $processor = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_PROCESSOR `
                -Filter "ResourceID = '$resourceId'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1

            $memory = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_X86_PC_MEMORY `
                -Filter "ResourceID = '$resourceId'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1

            $disk = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_LOGICAL_DISK `
                -Filter "ResourceID = '$resourceId' AND DeviceID = 'C:'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1

            $os = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_OPERATING_SYSTEM `
                -Filter "ResourceID = '$resourceId'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1

            $bios = Get-WmiObject -ComputerName $SiteServer `
                -Namespace "root\SMS\site_$SiteCode" `
                -Class SMS_G_System_PC_BIOS `
                -Filter "ResourceID = '$resourceId'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1

            [PSCustomObject]@{
                ComputerName     = $member.Name
                Manufacturer     = $computer.Manufacturer
                Model            = $computer.Model
                SerialNumber     = $bios.SerialNumber
                BIOSVersion      = $bios.SMBIOSBIOSVersion
                CPUName          = $processor.Name
                CPUCores         = $processor.NumberOfCores
                RAMGb            = if ($memory.TotalPhysicalMemory) { [math]::Round($memory.TotalPhysicalMemory / 1MB, 2) } else { $null }
                DiskCFreeSizeGb  = if ($disk.FreeSpace) { [math]::Round($disk.FreeSpace / 1024, 2) } else { $null }
                DiskCSizeTotalGb = if ($disk.Size) { [math]::Round($disk.Size / 1024, 2) } else { $null }
                OSCaption        = $os.Caption
                OSVersion        = $os.Version
                LastHWScan       = $member.LastActiveTime
            }
        }

        if ($ExportPath) {
            $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-Host "Report exported to: $ExportPath"
        }

        $report
    }
    catch {
        Write-Error "Failed to generate hardware inventory report: $_"
    }
}

end {
    Set-Location $originalLocation
}
