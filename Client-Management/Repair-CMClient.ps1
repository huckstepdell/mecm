<#
.SYNOPSIS
    Repairs the MECM/SCCM client on one or more computers.

.DESCRIPTION
    Attempts to repair the MECM client installation on remote computers by
    re-running the client installation from the site server, or by restarting
    the SMS Agent Host service. Optionally forces a full reinstall.

.PARAMETER ComputerName
    One or more computer names to repair. Accepts pipeline input.

.PARAMETER SiteServer
    The MECM site server hostname used to pull the client installer.

.PARAMETER ForceReinstall
    If specified, uninstalls then reinstalls the MECM client entirely.

.PARAMETER Credential
    Alternate credentials for remote operations.

.PARAMETER SiteCode
    The MECM site code (e.g. "PS1"). Used to construct the client installation
    share path on the site server.

.EXAMPLE
    Repair-CMClient -ComputerName "DESKTOP-001" -SiteServer "MECM-SERVER" -SiteCode "PS1"

.EXAMPLE
    "DESKTOP-001", "DESKTOP-002" | Repair-CMClient -SiteServer "MECM-SERVER" -SiteCode "PS1" -ForceReinstall

.NOTES
    Requires administrative access to the target computers and access to the
    MECM client installation share on the site server.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter(Mandatory)]
    [string]$SiteServer,

    [Parameter(Mandatory)]
    [string]$SiteCode,

    [Parameter()]
    [switch]$ForceReinstall,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential
)

begin {
    $clientInstallPath = "\\$SiteServer\SMS_$SiteCode\Client\ccmsetup.exe"
    $invokeParams = @{}
    if ($Credential) {
        $invokeParams['Credential'] = $Credential
    }
}

process {
    foreach ($computer in $ComputerName) {
        if (-not $PSCmdlet.ShouldProcess($computer, "Repair MECM client")) {
            continue
        }

        Write-Verbose "[$computer] Starting client repair..."

        try {
            if ($ForceReinstall) {
                # Uninstall first
                Write-Verbose "[$computer] Uninstalling MECM client..."
                Invoke-Command -ComputerName $computer @invokeParams -ScriptBlock {
                    $ccmSetup = "$env:SystemRoot\ccmsetup\ccmsetup.exe"
                    if (Test-Path $ccmSetup) {
                        Start-Process -FilePath $ccmSetup -ArgumentList '/uninstall' -Wait
                    }
                } -ErrorAction Stop

                Start-Sleep -Seconds 30
            }

            # Run ccmsetup from site server
            Write-Verbose "[$computer] Running ccmsetup from $SiteServer..."
            Invoke-Command -ComputerName $computer @invokeParams -ScriptBlock {
                param($InstallPath)
                Start-Process -FilePath $InstallPath -Wait
            } -ArgumentList $clientInstallPath -ErrorAction Stop

            [PSCustomObject]@{
                ComputerName  = $computer
                SiteServer    = $SiteServer
                ForceReinstall = $ForceReinstall.IsPresent
                Status        = 'Success'
                Timestamp     = Get-Date
            }
        }
        catch {
            [PSCustomObject]@{
                ComputerName  = $computer
                SiteServer    = $SiteServer
                ForceReinstall = $ForceReinstall.IsPresent
                Status        = 'Failed'
                Timestamp     = Get-Date
            }
            Write-Warning "[$computer] Client repair failed. Error: $_"
        }
    }
}
