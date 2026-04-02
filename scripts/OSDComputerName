param(
    [Parameter(Mandatory = $true)]
    [string]$Prefix
)

$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment

try {
    # Basic prefix check
    if ([string]::IsNullOrWhiteSpace($Prefix)) {
        throw "Prefix parameter is empty or whitespace."
    }

    # Detect platform
    $cs = Get-CimInstance Win32_ComputerSystem
    $manufacturer = $cs.Manufacturer

    if ($manufacturer -like "*VMware*") {

        # VMware: use MAC – must have valid last 4 hex chars
        $nic = Get-CimInstance Win32_NetworkAdapterConfiguration |
               Where-Object { $_.IPEnabled -eq $true -and $_.MACAddress } |
               Select-Object -First 1

        if (-not $nic -or -not $nic.MACAddress) {
            throw "VMware detected but no IP-enabled NIC with MAC address was found."
        }

        $macClean = ($nic.MACAddress -replace '[:-]', '')

        if ([string]::IsNullOrWhiteSpace($macClean) -or $macClean.Length -lt 4) {
            throw "VMware detected but MAC '$($nic.MACAddress)' is invalid or shorter than 4 characters."
        }

        $last4 = $macClean.Substring($macClean.Length - 4, 4)

        if ($last4 -notmatch '^[0-9A-Fa-f]{4}$') {
            throw "VMware MAC suffix '$last4' is not 4 hex characters."
        }

        $name = "$Prefix-vmw$last4"
    }
    else {
        # Physical / Proxmox: use serial; must yield at least 1 character
        $bios = Get-CimInstance Win32_BIOS

        if (-not $bios -or [string]::IsNullOrWhiteSpace($bios.SerialNumber)) {
            throw "Non-VMware system but BIOS serial number is missing."
        }

        $serial      = $bios.SerialNumber.Trim()
        $serialClean = ($serial -replace '[^A-Za-z0-9]', '')

        if ([string]::IsNullOrWhiteSpace($serialClean)) {
            throw "Serial number '$serial' cleaned to nothing; cannot build computer name."
        }

        $name = "$Prefix-$serialClean"
    }

    # Enforce NetBIOS 15-char limit (truncate but keep non-empty)
    if ($name.Length -gt 15) {
        $name = $name.Substring(0,15)
    }

    # Final sanity checks: non-empty, starts with prefix
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Resulting computer name is empty."
    }

    if ($name.StartsWith($Prefix) -eq $false) {
        throw "Resulting computer name '$name' doesn't start with expected prefix '$Prefix'."
    }

    $tsenv.Value("OSDComputerName") = $name
    Write-Host "OSDComputerName set to $name"
}
catch {
    Write-Error $_.Exception.Message
    # Explicit non-zero exit so the TS step fails
    [Environment]::Exit(1)
}
