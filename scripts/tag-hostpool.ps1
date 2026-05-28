<#
.SYNOPSIS
Tags Azure Virtual Desktop session host VMs, NICs, and OS disks.

.DESCRIPTION
This script retrieves session hosts from an Azure Virtual Desktop host pool
and applies tags to:
- Virtual Machines
- Network Interfaces
- OS Disks

Features:
- Bulk tagging
- Single VM tagging
- Merge with existing tags
- Idempotent tag checks
- Logging
- Error handling
- Supports -WhatIf and -Confirm

.PARAMETER SubscriptionId
Azure subscription ID.

.PARAMETER ResourceGroupName
Resource group containing the AVD host pool.

.PARAMETER HostPoolName
Name of the Azure Virtual Desktop host pool.

.PARAMETER Tags
Hashtable of tags to apply.

.PARAMETER VMName
Optional single VM name.

.PARAMETER MergeWithExistingTags
Merge supplied tags with existing tags.

.EXAMPLE
.\tag-hostpool.ps1 `
    -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ResourceGroupName "rg-avd-prod" `
    -HostPoolName "hp-prod-01" `
    -Tags @{ Environment="Prod"; Owner="VDI" } `
    -MergeWithExistingTags

.EXAMPLE
.\tag-hostpool.ps1 `
    -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ResourceGroupName "rg-avd-prod" `
    -HostPoolName "hp-prod-01" `
    -VMName "avd-01" `
    -Tags @{ PatchGroup="A" }

.NOTES
Author: Aakash
#>

[CmdletBinding(SupportsShouldProcess)]
param (

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $true)]
    [hashtable]$Tags,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [switch]$MergeWithExistingTags
)

# ── Logging ───────────────────────────────────────────────────────────────────
$ScriptRootSafe = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

$LogFile = Join-Path $ScriptRootSafe "tag-hostpool.log"

function Write-Log {

    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry  = "[$timestamp][$Level] $Message"

    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# ── Helper Function ───────────────────────────────────────────────────────────
function Test-TagsNeedUpdate {

    param (
        [hashtable]$ExistingTags,
        [hashtable]$DesiredTags
    )

    if (-not $ExistingTags) {
        return $true
    }

    foreach ($key in $DesiredTags.Keys) {

        if (-not $ExistingTags.ContainsKey($key)) {
            return $true
        }

        if ($ExistingTags[$key] -ne $DesiredTags[$key]) {
            return $true
        }
    }

    return $false
}

# ── Azure Context ─────────────────────────────────────────────────────────────
try {

    Write-Log "Setting Azure context to subscription: $SubscriptionId"

    Set-AzContext `
        -SubscriptionId $SubscriptionId `
        -ErrorAction Stop | Out-Null

    Write-Log "Azure context set successfully"
}
catch {

    Write-Log "Failed to set Azure context: $_" "ERROR"
    throw
}

# ── Validate Host Pool ────────────────────────────────────────────────────────
try {

    Write-Log "Validating host pool: $HostPoolName"

    Get-AzWvdHostPool `
        -ResourceGroupName $ResourceGroupName `
        -Name $HostPoolName `
        -ErrorAction Stop | Out-Null

    Write-Log "Host pool '$HostPoolName' found"
}
catch {

    Write-Log "Host pool '$HostPoolName' not found: $_" "ERROR"
    throw
}

# ── Fetch Session Hosts ───────────────────────────────────────────────────────
try {

    Write-Log "Fetching session hosts from host pool: $HostPoolName"

    $sessionHosts = Get-AzWvdSessionHost `
        -ResourceGroupName $ResourceGroupName `
        -HostPoolName $HostPoolName `
        -ErrorAction Stop

    if (-not $sessionHosts -or $sessionHosts.Count -eq 0) {

        Write-Log "No session hosts found in host pool '$HostPoolName'" "WARN"
        exit 0
    }

    Write-Log "Found $($sessionHosts.Count) session host(s)"

    # ── Single VM Mode ───────────────────────────────────────────────────────
    if ($VMName) {

        $targetVM = $VMName.Trim()

        $sessionHosts = $sessionHosts | Where-Object {
            $_.Name.Split("/")[-1].Split(".")[0].Trim() -eq $targetVM
        }

        if (-not $sessionHosts -or $sessionHosts.Count -eq 0) {

            Write-Log "VM '$VMName' not found in host pool '$HostPoolName'" "ERROR"
            exit 1
        }

        Write-Log "Single VM mode enabled. Target VM: $VMName"
    }
    else {

        Write-Log "Bulk mode enabled"
    }
}
catch {

    Write-Log "Error fetching session hosts: $_" "ERROR"
    throw
}

# ── Counters ──────────────────────────────────────────────────────────────────
$successCount = 0
$failCount    = 0
$skipCount    = 0

# ── Process Session Hosts ─────────────────────────────────────────────────────
foreach ($sh in $sessionHosts) {

    $vmName = $sh.Name.Split("/")[-1].Split(".")[0]

    Write-Log "=========================================="
    Write-Log "Processing VM: $vmName"

    try {

        $vm = Get-AzVM `
            -ResourceGroupName $ResourceGroupName `
            -Name $vmName `
            -ErrorAction Stop

        # ── Build Effective Tags ─────────────────────────────────────────────
        if ($MergeWithExistingTags -and $vm.Tags) {

            $effectiveTags = @{}

            foreach ($key in $vm.Tags.Keys) {
                $effectiveTags[$key] = $vm.Tags[$key]
            }

            foreach ($key in $Tags.Keys) {
                $effectiveTags[$key] = $Tags[$key]
            }

            Write-Log "Merging supplied tags with existing tags"
        }
        else {

            $effectiveTags = $Tags
        }

        # ── Tag VM ───────────────────────────────────────────────────────────
        if (Test-TagsNeedUpdate `
            -ExistingTags $vm.Tags `
            -DesiredTags $effectiveTags) {

            if ($PSCmdlet.ShouldProcess($vmName, "Apply VM tags")) {

                Set-AzResource `
                    -ResourceId $vm.Id `
                    -Tag $effectiveTags `
                    -Force `
                    -ErrorAction Stop | Out-Null

                Write-Log "VM '$vmName' tagged successfully"
            }
        }
        else {

            Write-Log "VM '$vmName' already has required tags. Skipping."
            $skipCount++
        }

        # ── Tag NICs ─────────────────────────────────────────────────────────
        foreach ($nicRef in $vm.NetworkProfile.NetworkInterfaces) {

            try {

                $nic = Get-AzResource -ResourceId $nicRef.Id
                $nicName = $nicRef.Id.Split("/")[-1]

                if (Test-TagsNeedUpdate `
                    -ExistingTags $nic.Tags `
                    -DesiredTags $effectiveTags) {

                    if ($PSCmdlet.ShouldProcess($nicName, "Apply NIC tags")) {

                        Set-AzResource `
                            -ResourceId $nicRef.Id `
                            -Tag $effectiveTags `
                            -Force `
                            -ErrorAction Stop | Out-Null

                        Write-Log "NIC '$nicName' tagged successfully"
                    }
                }
                else {

                    Write-Log "NIC '$nicName' already has required tags. Skipping."
                }
            }
            catch {

                Write-Log "Error tagging NIC '$($nicRef.Id)': $_" "ERROR"
            }
        }

        # ── Tag OS Disk ──────────────────────────────────────────────────────
        try {

            $osDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
            $diskName = $osDiskId.Split("/")[-1]

            $disk = Get-AzResource -ResourceId $osDiskId

            if (Test-TagsNeedUpdate `
                -ExistingTags $disk.Tags `
                -DesiredTags $effectiveTags) {

                if ($PSCmdlet.ShouldProcess($diskName, "Apply OS disk tags")) {

                    Set-AzResource `
                        -ResourceId $osDiskId `
                        -Tag $effectiveTags `
                        -Force `
                        -ErrorAction Stop | Out-Null

                    Write-Log "OS Disk '$diskName' tagged successfully"
                }
            }
            else {

                Write-Log "OS Disk '$diskName' already has required tags. Skipping."
            }
        }
        catch {

            Write-Log "Error tagging OS disk for VM '$vmName': $_" "ERROR"
        }

        $successCount++
    }
    catch {

        Write-Log "Error processing VM '$vmName': $_" "ERROR"
        $failCount++
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Log "=========================================="
Write-Log "Tagging complete"
Write-Log "Success : $successCount"
Write-Log "Skipped : $skipCount"
Write-Log "Failed  : $failCount"
Write-Log "Total   : $($sessionHosts.Count)"