<#
.SYNOPSIS
    Clears the MECM/SCCM client cache on one or more computers.

.DESCRIPTION
    Connects to the MECM client on remote computers and removes cached content
    items from the CCM cache. Optionally filters by a minimum age to only
    remove old cached items, or targets a specific cached package/application.

.PARAMETER ComputerName
    One or more computer names to target. Accepts pipeline input.

.PARAMETER MinAgeDays
    Only delete cache items older than this many days. Default is 0 (all items).

.PARAMETER WhatIf
    Shows what would be deleted without actually deleting.

.PARAMETER Credential
    Alternate credentials for remote connection.

.EXAMPLE
    Clear-CMClientCache -ComputerName "DESKTOP-001"

.EXAMPLE
    "DESKTOP-001", "DESKTOP-002" | Clear-CMClientCache -MinAgeDays 7

.EXAMPLE
    Clear-CMClientCache -ComputerName "DESKTOP-001" -WhatIf

.NOTES
    Requires WMI/WinRM access to target computers and the MECM client installed.
    Running this script will remove cached software packages which may need to
    be re-downloaded on next deployment.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [int]$MinAgeDays = 0,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential
)

begin {
    $invokeParams = @{}
    if ($Credential) {
        $invokeParams['Credential'] = $Credential
    }
}

process {
    foreach ($computer in $ComputerName) {
        if (-not $PSCmdlet.ShouldProcess($computer, "Clear MECM client cache")) {
            continue
        }

        Write-Verbose "[$computer] Clearing client cache (MinAgeDays: $MinAgeDays)..."

        try {
            $result = Invoke-Command -ComputerName $computer @invokeParams -ScriptBlock {
                param($MinAge)

                $cacheManager = New-Object -ComObject UIResource.UIResourceMgr
                $cache = $cacheManager.GetCacheInfo()
                $items = $cache.GetCacheElements()

                $cutoff = (Get-Date).AddDays(-$MinAge)
                $removed = 0
                $freedMB = 0

                foreach ($item in $items) {
                    if ($MinAge -eq 0 -or $item.LastReferenceTime -lt $cutoff) {
                        $freedMB += [math]::Round($item.ContentSize / 1024, 2)
                        $cache.DeleteCacheElement($item.CacheElementId)
                        $removed++
                    }
                }

                [PSCustomObject]@{
                    ItemsRemoved = $removed
                    FreedSpaceMB = $freedMB
                }
            } -ArgumentList $MinAgeDays -ErrorAction Stop

            [PSCustomObject]@{
                ComputerName = $computer
                ItemsRemoved = $result.ItemsRemoved
                FreedSpaceMB = $result.FreedSpaceMB
                Status       = 'Success'
                Timestamp    = Get-Date
            }
        }
        catch {
            [PSCustomObject]@{
                ComputerName = $computer
                ItemsRemoved = 0
                FreedSpaceMB = 0
                Status       = 'Failed'
                Timestamp    = Get-Date
            }
            Write-Warning "[$computer] Failed to clear cache. Error: $_"
        }
    }
}
