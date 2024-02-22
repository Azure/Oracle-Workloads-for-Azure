resource "azurerm_monitor_diagnostic_setting" "oracle_vm" {
  count                          = var.is_diagnostic_settings_enabled ? var.database_server_count : 0
  name                           = "${var.vm_name}-${count.index}-diag"
  target_resource_id             = azurerm_linux_virtual_machine.oracle_vm[count.index].id
  storage_account_id             = var.diagnostic_target == "Storage_Account" ? var.storage_account_id : null
  log_analytics_workspace_id     = var.diagnostic_target == "Log_Analytics_Workspace" ? var.log_analytics_workspace_id : null
  eventhub_authorization_rule_id = var.diagnostic_target == "Event_Hubs" ? var.eventhub_authorization_rule_id : null
  partner_solution_id            = var.diagnostic_target == "Partner_Solutions" ? var.partner_solution_id : null

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.oracle_vm[count.index].log_category_types
    content {
      category = each.value
      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }

  metric {
    category = "AllMetrics"
    retention_policy {
      enabled = false
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "oracle_vm" {
  count       = var.is_diagnostic_settings_enabled ? var.database_server_count : 0
  resource_id = data.azurerm_virtual_machine.oracle_vm[count.index].id
}

resource "azurerm_virtual_machine_extension" "diag_setting" {
  count                      = var.is_diagnostic_settings_enabled ? var.database_server_count : 0
  name                       = "${var.vm_name}-${count.index}-diag"
  virtual_machine_id         = azurerm_linux_virtual_machine.oracle_vm[count.index].id
  publisher                  = "Microsoft.Azure.Diagnostics"
  type                       = "LinuxDiagnostic"
  type_handler_version       = "4.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = <<SETTINGS
  {
    "StorageAccount": "${substr(var.storage_account_id, -24, -1)}",
    "ladCfg": {
        "diagnosticMonitorConfiguration": {
            "eventVolume": "Medium",
            "metrics": {
                "metricAggregation": [
                    {
                        "scheduledTransferPeriod": "PT1H"
                    },
                    {
                        "scheduledTransferPeriod": "PT1M"
                    }
                ],
                "syslogEvents": ${file("${path.module}/azure_extension_diagnostics_linux_syslogevents.json")},
                "resourceId": "${azurerm_linux_virtual_machine.oracle_vm[count.index].id}",
                "performanceCounters": {
                    "performanceCounterConfiguration": [
                    {
                        "annotation": [
                        {
                            "displayName": "Disk read guest OS", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "readbytespersecond", 
                        "counterSpecifier": "/builtin/disk/readbytespersecond", 
                        "type": "builtin", 
                        "unit": "BytesPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk writes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "writespersecond", 
                        "counterSpecifier": "/builtin/disk/writespersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk transfer time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "averagetransfertime", 
                        "counterSpecifier": "/builtin/disk/averagetransfertime", 
                        "type": "builtin", 
                        "unit": "Seconds"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk transfers", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "transferspersecond", 
                        "counterSpecifier": "/builtin/disk/transferspersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk write guest OS", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "writebytespersecond", 
                        "counterSpecifier": "/builtin/disk/writebytespersecond", 
                        "type": "builtin", 
                        "unit": "BytesPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk read time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "averagereadtime", 
                        "counterSpecifier": "/builtin/disk/averagereadtime", 
                        "type": "builtin", 
                        "unit": "Seconds"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk write time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "averagewritetime", 
                        "counterSpecifier": "/builtin/disk/averagewritetime", 
                        "type": "builtin", 
                        "unit": "Seconds"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk total bytes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "bytespersecond", 
                        "counterSpecifier": "/builtin/disk/bytespersecond", 
                        "type": "builtin", 
                        "unit": "BytesPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk reads", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "readspersecond", 
                        "counterSpecifier": "/builtin/disk/readspersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Disk queue length", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "disk", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "averagediskqueuelength", 
                        "counterSpecifier": "/builtin/disk/averagediskqueuelength", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Network in guest OS", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "bytesreceived", 
                        "counterSpecifier": "/builtin/network/bytesreceived", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Network total bytes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "bytestotal", 
                        "counterSpecifier": "/builtin/network/bytestotal", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Network out guest OS", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "bytestransmitted", 
                        "counterSpecifier": "/builtin/network/bytestransmitted", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Network collisions", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "totalcollisions", 
                        "counterSpecifier": "/builtin/network/totalcollisions", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Packets received errors", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "totalrxerrors", 
                        "counterSpecifier": "/builtin/network/totalrxerrors", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Packets sent", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "packetstransmitted", 
                        "counterSpecifier": "/builtin/network/packetstransmitted", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Packets received", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "packetsreceived", 
                        "counterSpecifier": "/builtin/network/packetsreceived", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Packets sent errors", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "network", 
                        "counter": "totaltxerrors", 
                        "counterSpecifier": "/builtin/network/totaltxerrors", 
                        "type": "builtin", 
                        "unit": "Count"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem transfers/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "transferspersecond", 
                        "counterSpecifier": "/builtin/filesystem/transferspersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem % free space", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentfreespace", 
                        "counterSpecifier": "/builtin/filesystem/percentfreespace", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem % used space", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentusedspace", 
                        "counterSpecifier": "/builtin/filesystem/percentusedspace", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem used space", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "usedspace", 
                        "counterSpecifier": "/builtin/filesystem/usedspace", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem read bytes/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "bytesreadpersecond", 
                        "counterSpecifier": "/builtin/filesystem/bytesreadpersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem free space", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "freespace", 
                        "counterSpecifier": "/builtin/filesystem/freespace", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem % free inodes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentfreeinodes", 
                        "counterSpecifier": "/builtin/filesystem/percentfreeinodes", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem bytes/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "bytespersecond", 
                        "counterSpecifier": "/builtin/filesystem/bytespersecond", 
                        "type": "builtin", 
                        "unit": "BytesPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem reads/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "readspersecond", 
                        "counterSpecifier": "/builtin/filesystem/readspersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem write bytes/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "byteswrittenpersecond", 
                        "counterSpecifier": "/builtin/filesystem/byteswrittenpersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem writes/sec", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "writespersecond", 
                        "counterSpecifier": "/builtin/filesystem/writespersecond", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Filesystem % used inodes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "filesystem", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentusedinodes", 
                        "counterSpecifier": "/builtin/filesystem/percentusedinodes", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU IO wait time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentiowaittime", 
                        "counterSpecifier": "/builtin/processor/percentiowaittime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU user time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentusertime", 
                        "counterSpecifier": "/builtin/processor/percentusertime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU nice time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentnicetime", 
                        "counterSpecifier": "/builtin/processor/percentnicetime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU percentage guest OS", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentprocessortime", 
                        "counterSpecifier": "/builtin/processor/percentprocessortime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU interrupt time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentinterrupttime", 
                        "counterSpecifier": "/builtin/processor/percentinterrupttime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU idle time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentidletime", 
                        "counterSpecifier": "/builtin/processor/percentidletime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "CPU privileged time", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "processor", 
                        "condition": "IsAggregate=TRUE", 
                        "counter": "percentprivilegedtime", 
                        "counterSpecifier": "/builtin/processor/percentprivilegedtime", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Memory available", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "availablememory", 
                        "counterSpecifier": "/builtin/memory/availablememory", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Swap percent used", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "percentusedswap", 
                        "counterSpecifier": "/builtin/memory/percentusedswap", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Memory used", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "usedmemory", 
                        "counterSpecifier": "/builtin/memory/usedmemory", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Page reads", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "pagesreadpersec", 
                        "counterSpecifier": "/builtin/memory/pagesreadpersec", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Swap available", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "availableswap", 
                        "counterSpecifier": "/builtin/memory/availableswap", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Swap percent available", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "percentavailableswap", 
                        "counterSpecifier": "/builtin/memory/percentavailableswap", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Mem. percent available", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "percentavailablememory", 
                        "counterSpecifier": "/builtin/memory/percentavailablememory", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Pages", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "pagespersec", 
                        "counterSpecifier": "/builtin/memory/pagespersec", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Swap used", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "usedswap", 
                        "counterSpecifier": "/builtin/memory/usedswap", 
                        "type": "builtin", 
                        "unit": "Bytes"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Memory percentage", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "percentusedmemory", 
                        "counterSpecifier": "/builtin/memory/percentusedmemory", 
                        "type": "builtin", 
                        "unit": "Percent"
                    }, 
                    {
                        "annotation": [
                        {
                            "displayName": "Page writes", 
                            "locale": "en-us"
                        }
                        ], 
                        "class": "memory", 
                        "counter": "pageswrittenpersec", 
                        "counterSpecifier": "/builtin/memory/pageswrittenpersec", 
                        "type": "builtin", 
                        "unit": "CountPerSecond"
                    }
                    ]
                }
            },
            "sampleRateInSeconds": 60
        }
    }
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "storageAccountName": "${substr(var.storage_account_id, -24, -1)}",
    "storageAccountSasToken": "${var.storage_account_sas_token}",
    "sinksConfig": {
        "sink": [
            {
                "name": "SyslogJsonBlob",
                "type": "JsonBlob"
            },
            {
                "name": "LinuxCpuJsonBlob",
                "type": "JsonBlob"
            }
        ]
    }
  }
  PROTECTED_SETTINGS
}
