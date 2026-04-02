<#
.SYNOPSIS
    Reports on MECM application and package deployment status.

.DESCRIPTION
    Queries the MECM site server to return a summary of deployment status
    for applications or packages, including per-device success, failure,
    and in-progress counts. Can be scoped to a specific deployment or collection.

.PARAMETER DeploymentName
    The name of the deployment to report on. Supports wildcards.

.PARAMETER CollectionName
    The name of the device collection to scope the report to.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1").

.PARAMETER ExportPath
    If specified, exports the report to a CSV file at the given path.

.EXAMPLE
    Get-CMDeploymentStatus -DeploymentName "Deploy - 7-Zip*"

.EXAMPLE
    Get-CMDeploymentStatus -CollectionName "All Workstations" | Format-Table

.EXAMPLE
    Get-CMDeploymentStatus -DeploymentName "Deploy - 7-Zip*" -ExportPath "C:\Reports\deploy.csv"

.NOTES
    Requires the ConfigurationManager PowerShell module and MECM reporting permissions.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [SupportsWildcards()]
    [string]$DeploymentName,

    [Parameter()]
    [string]$CollectionName,

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
        $deployParams = @{}
        if ($DeploymentName) { $deployParams['Name'] = $DeploymentName }
        if ($CollectionName) { $deployParams['CollectionName'] = $CollectionName }

        $deployments = Get-CMDeployment @deployParams -ErrorAction Stop

        $report = foreach ($deployment in $deployments) {
            $summary = Get-CMDeploymentSummary -DeploymentId $deployment.DeploymentID -ErrorAction SilentlyContinue

            [PSCustomObject]@{
                DeploymentName        = $deployment.ApplicationName
                CollectionName        = $deployment.CollectionName
                DeploymentType        = $deployment.FeatureType
                Purpose               = if ($deployment.DeploymentIntent -eq 1) { 'Required' } else { 'Available' }
                TotalDevices          = $summary.NumberTargeted
                SuccessCount          = $summary.NumberSuccess
                FailureCount          = $summary.NumberErrors
                InProgressCount       = $summary.NumberInProgress
                UnknownCount          = $summary.NumberUnknown
                SuccessPercentage     = if ($summary.NumberTargeted -gt 0) {
                    [math]::Round(($summary.NumberSuccess / $summary.NumberTargeted) * 100, 1)
                } else { 0 }
                StartTime             = $deployment.StartTime
                DeadlineTime          = $deployment.EnforcementDeadline
                DeploymentId          = $deployment.DeploymentID
            }
        }

        if ($ExportPath) {
            $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-Host "Report exported to: $ExportPath"
        }

        $report
    }
    catch {
        Write-Error "Failed to retrieve deployment status: $_"
    }
}

end {
    Set-Location $originalLocation
}
