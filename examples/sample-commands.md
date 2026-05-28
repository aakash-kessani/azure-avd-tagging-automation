# Sample Commands

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