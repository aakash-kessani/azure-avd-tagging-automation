# Azure AVD Tagging Automation

PowerShell automation script for tagging Azure Virtual Desktop (AVD) session host resources.

This script applies tags to:
- Virtual Machines
- Network Interfaces (NICs)
- OS Disks

Supports:
- Bulk tagging
- Single VM tagging
- Merge with existing tags
- Idempotent updates
- Logging
- WhatIf support

---

# Features

- Enterprise-ready logging
- Safe re-runnable execution
- Skips already tagged resources
- Supports Azure PowerShell modules
- Operational automation friendly

---

# Requirements

- PowerShell 7+
- Az PowerShell Modules
- Azure permissions:
  - Virtual Machine Contributor
  - Reader
  - Tag Contributor (optional)

Install modules:

```powershell
Install-Module Az -Scope CurrentUser
```

---

# Usage

## Bulk Tagging

```powershell
.\tag-hostpool.ps1 `
  -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
  -ResourceGroupName "rg-avd-prod" `
  -HostPoolName "hp-prod-01" `
  -Tags @{
      Environment = "Production"
      Owner       = "VDI"
  } `
  -MergeWithExistingTags
```

---

## Single VM Tagging

```powershell
.\tag-hostpool.ps1 `
  -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
  -ResourceGroupName "rg-avd-prod" `
  -HostPoolName "hp-prod-01" `
  -VMName "avd-01" `
  -Tags @{
      PatchGroup = "A"
  }
```

---

# WhatIf Mode

```powershell
.\tag-hostpool.ps1 `
  -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
  -ResourceGroupName "rg-avd-prod" `
  -HostPoolName "hp-prod-01" `
  -Tags @{
      Environment = "Test"
  } `
  -WhatIf
```

---

# Logging

Logs are written to:

```text
tag-hostpool.log
```

---

# Example Output

```text
[2026-05-28 10:10:01][INFO] Processing VM: avd-01
[2026-05-28 10:10:04][INFO] VM 'avd-01' tagged successfully
[2026-05-28 10:10:05][INFO] NIC 'avd-01-nic' tagged successfully
[2026-05-28 10:10:07][INFO] OS Disk 'avd-01-osdisk' tagged successfully
```

---

# Future Improvements

- Azure Automation Runbook support
- Parallel execution
- Azure Policy integration
- Terraform module
- GitHub Actions CI/CD
- Pester unit tests

---

# License

MIT
