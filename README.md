# MECM / SCCM Scripts

A collection of PowerShell scripts for administering Microsoft Endpoint Configuration Manager (MECM), formerly known as System Center Configuration Manager (SCCM).

## Prerequisites

- **MECM Admin Console** installed on the machine running these scripts (provides the `ConfigurationManager` PowerShell module)
- **PowerShell 5.1** or later
- Appropriate **MECM role-based access** (Full Administrator or targeted roles as noted per script)
- **WinRM / WMI access** to target client computers for scripts that operate remotely

## Repository Structure

```
mecm/
├── Client-Management/          # Scripts for managing MECM clients
│   ├── Get-CMClientStatus.ps1      - Query client health and activity status
│   ├── Invoke-CMClientAction.ps1   - Trigger client actions (policy, inventory, etc.)
│   ├── Repair-CMClient.ps1         - Repair or reinstall the MECM client
│   └── Clear-CMClientCache.ps1     - Clear the MECM client content cache
│
├── Software-Updates/           # Scripts for software update management
│   ├── Get-CMUpdateCompliance.ps1  - Report update compliance for a collection
│   └── Invoke-CMSoftwareUpdateScan.ps1 - Trigger software update scan on clients
│
├── Collections/                # Scripts for collection management
│   ├── Get-CMCollectionMembers.ps1 - List members of a device or user collection
│   └── Add-CMDeviceToCollection.ps1 - Add devices as direct members of a collection
│
├── Reporting/                  # Scripts for reporting and auditing
│   ├── Get-CMHardwareInventoryReport.ps1 - Generate hardware inventory reports
│   └── Get-CMDeploymentStatus.ps1  - Report on application/package deployment status
│
└── Maintenance/                # Scripts for site and client maintenance
    ├── Invoke-CMSiteMaintenance.ps1 - Run MECM site maintenance tasks
    └── Remove-CMStaleDevices.ps1   - Remove inactive/stale device records
```

## Usage

All scripts support PowerShell's standard help system. Use `Get-Help` to view full documentation, examples, and parameter details for any script:

```powershell
Get-Help .\Client-Management\Get-CMClientStatus.ps1 -Full
```

### Quick Examples

**Check client health status:**
```powershell
.\Client-Management\Get-CMClientStatus.ps1 -CollectionName "All Workstations"
```

**Trigger a machine policy refresh on multiple computers:**
```powershell
"PC001", "PC002" | .\Client-Management\Invoke-CMClientAction.ps1 -Action MachinePolicy
```

**Repair the MECM client on a remote computer:**
```powershell
.\Client-Management\Repair-CMClient.ps1 -ComputerName "PC001" -SiteServer "MECM-SERVER" -SiteCode "PS1"
```

**Clear the client cache on a remote computer:**
```powershell
.\Client-Management\Clear-CMClientCache.ps1 -ComputerName "PC001" -MinAgeDays 7
```

**Check software update compliance:**
```powershell
.\Software-Updates\Get-CMUpdateCompliance.ps1 -UpdateGroupName "2024-10 Patch Tuesday" -CollectionName "All Workstations" -NonCompliantOnly
```

**Trigger a software update scan:**
```powershell
"PC001", "PC002" | .\Software-Updates\Invoke-CMSoftwareUpdateScan.ps1
```

**List members of a collection:**
```powershell
.\Collections\Get-CMCollectionMembers.ps1 -CollectionName "All Workstations" | Export-Csv .\members.csv -NoTypeInformation
```

**Add devices to a collection:**
```powershell
Get-Content .\computers.txt | .\Collections\Add-CMDeviceToCollection.ps1 -CollectionName "Pilot Group"
```

**Generate a hardware inventory report:**
```powershell
.\Reporting\Get-CMHardwareInventoryReport.ps1 -CollectionName "All Servers" -SiteServer "MECM-SERVER" -ExportPath "C:\Reports\hw_inventory.csv"
```

**Check deployment status:**
```powershell
.\Reporting\Get-CMDeploymentStatus.ps1 -DeploymentName "Deploy - 7-Zip*" | Format-Table
```

**Run site maintenance tasks:**
```powershell
.\Maintenance\Invoke-CMSiteMaintenance.ps1 -SiteServer "MECM-SERVER" -SiteCode "PS1" -Tasks All
```

**Preview stale device cleanup (WhatIf):**
```powershell
.\Maintenance\Remove-CMStaleDevices.ps1 -InactiveDays 90 -SiteCode "PS1" -WhatIf
```

## Notes

- Scripts that modify MECM data support `-WhatIf` and `-Confirm` parameters via PowerShell's `SupportsShouldProcess` mechanism.
- Always test scripts in a non-production environment before running against production systems.
- Ensure that hardware inventory has been enabled and has run on clients before using inventory-based reports.
