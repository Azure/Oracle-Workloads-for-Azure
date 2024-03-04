---
title: Manage and monitor Oracle Database@Azure landing zone accelerator
description: Learn about managing and monitoring Oracle Database@Azure.
author: jfaurskov
ms.author: janfaurs
ms.date: 11/15/2023
ms.topic: conceptual
ms.service: cloud-adoption-framework
ms.subservice: scenario
---

# Manage and monitor Oracle Database@Azure landing zone accelerator

This article describes how to successfully manage and monitor Oracle Database@Azure landing zone accelerator. This scenario outlines important considerations and recommendations for your environment. The guidance builds upon Azure landing zone recommendations as described in [Design area: Management for Azure environments](/azure/cloud-adoption-framework/ready/landing-zone/design-area/management). Monitoring Oracle Database@Azure to discover failures and abnormalities is critical to ensure the health of your workloads.

## Design considerations

- A subset of Oracle Database Metrics are available through Azure Log Analytics integration, i.e. the metrics are transferred from Oracle Cloud Infrastructure (OCI) to Azure Log Analytics. For more details on available metrics please refer to [fixme product documentation, Metrics in the oracle\_oci\_database](https://docs.oracle.com/en-us/iaas/database-management/doc/oracle-cloud-database-metrics.html). Available metrics depends on whether you have selected Basic or Full management option for your Oracle Database@Azure in Oracle Cloud, for more details on what is included in Basic and Full management options please refer to [About Management Options](https://docs.oracle.com/en-us/iaas/database-management/doc/enable-database-management-oracle-cloud-databases.html#GUID-82E59C37-A1EA-4355-8216-769D22F8EFDD).
- Service messages regarding planned maintenance events or outages for Oracle Cloud Infrastructure (OCI) are not available through Azure Service Health. Rather this is managed through Oracle Cloud notifications.
- There is no native database management tooling in Azure. Databases in Oracle Database@Azure are managed through Oracle Cloud Infrastructure (OCI) and the management tooling provided by Oracle.

## Design Recommendations

- Configure the following monitoring baselines for your production databases in Azure Monitor and configure alerts and notifications for same. Note that the list is not necessarily exhaustive and you may want to add additional metrics and thresholds based on your specific requirements. For more details on available metrics please refer to [fixme product documentation, Metrics in the oracle\_oci\_database](https://docs.oracle.com/en-us/iaas/database-management/doc/oracle-cloud-database-metrics.html).
  - fixme table of thresholds and metrics
- Enable Database management with Full management options for production databases on Oracle Database@Azure to get the most out of the monitoring capabilities. Full management options are recommended due to the limited feature set on Basic management options such as only 14 avavailable metrics as well as lack of RAC database monitoring.
- Configure notifications for planned maintenance events or outages for Oracle Cloud Infrastructure (OCI) through [Oracle Cloud notifications](https://docs.oracle.com/en/cloud/get-started/subscriptions-cloud/mmocs/monitoring-notifications.html#GUID-8ADF98C9-2C4C-458A-9134-67F6CDFB301A).
- For the resource management of your Oracle Database@Azure, leverage Oracle Enterprise Manager Cloud Control (EMCC) integrated with the standard management tool provided with the version of the database:
  - For Oracle Database 18c, or later, use Oracle Enterprise Manager Database Express. See [Accessing Enterprise Manager Database Express 18c, or later](https://docs.oracle.com/en/cloud/paas/exadata-cloud/csexa/access-em-database-express-18c-or-later.html).
  - For Oracle Database 12c, use Oracle Enterprise Manager Database Express 12c. See[Accessing Enterprise Manager Database Express 12c](https://docs.oracle.com/en/cloud/paas/exadata-cloud/csexa/access-em-database-express-12c.html).
- fixme Data collection rules if possible, to be investigated.

**Next steps**

Review the critical design considerations and recommendations for security and compliance specific to the deployment of Oracle databases @ Azure.

https://docs.oracle.com/en-us/iaas/database-management/doc/oracle-cloud-database-metrics.html
https://docs.oracle.com/en-us/iaas/performance-hub/doc/perf-hub-features.html
https://docs.oracle.com/en-us/iaas/Content/Monitoring/Tasks/managingalarms.htm
https://docs.oracle.com/en-us/iaas/database-management/doc/oracle-cloud-database-metrics.html
https://docs.oracle.com/pls/topic/lookup?ctx=en/cloud/paas/database-common/performancehub&id=oci-enable-db-mgmt
https://docs.oracle.com/pls/topic/lookup?ctx=en/cloud/paas/database-common/performancehub&id=oci-db-management-home
