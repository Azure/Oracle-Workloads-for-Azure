<!-- markdownlint-disable -->
# Telemetry Tracking Using Customer Usage Attribution (PID)
<!-- markdownlint-restore -->

Microsoft can identify the deployments of the Azure Resource Manager and Bicep templates with the deployed Azure resources. Microsoft can correlate these resources used to support the deployments. Microsoft collects this information to provide the best experiences with their products and to operate their business. The telemetry is collected through [customer usage attribution](https://docs.microsoft.com/azure/marketplace/azure-partner-customer-usage-attribution). The data is collected and governed by Microsoft's privacy policies, located at the [trust center](https://www.microsoft.com/trustcenter).

## Terraform Module Telemetry Tracking

To disable this tracking, we have included a variable called `disable_telemetry` to the following Terraform files in this repo with a simple boolean flag. The default value `false` which **does not** disable the telemetry. If you would like to disable this tracking, then simply set this value to `true` and this module will not be included in deployments and **therefore disables** the telemetry tracking.

- ./terraform/bootstrap/data_guard/variables_global.tf
- ./terraform/bootstrap/single_instance/variables_global.tf

If you are happy with leaving telemetry tracking enabled, no changes are required.

In the variables_global.tf file, you will see the following:

```terraform
variable "disable_telemetry" {
  type        = bool
  description = "If set to true, will disable telemetry for the module. See https://aka.ms/alz-terraform-module-telemetry."
  default     = false
}
```

The default value is `false`, but by changing the parameter value to `true` and saving this file, when you deploy this module regardless of the deployment method telemetry will not be tracked.

## Bicep Module Telemetry Tracking

To disable this tracking, we have included a parameter called `enableTelemetry` to the following Bicep parameter files in this repo with a simple boolean flag. The default value is `true` which enableds telemetry. If you would like to disable this tracking, then simply set this value to `false` and this module will not be included in deployments and **therefore disables** the telemetry tracking.

- ./bicep/bootstrap/data_guard/default/data_guard.bicepparam
- ./bicep/bootstrap/single_instance/default/single_instance.bicepparam

If you are happy with leaving telemetry tracking enabled, no changes are required.

In the above bicepparam files, you will see the following:

```bicep
param enableTelemetry = true
```

The default value is `true`, but by changing the parameter value to `false` and saving this file, when you deploy this module regardless of the deployment method, telemetry will not be tracked.

## Module PID Value Mapping

The following are the unique ID's (also known as PIDs) used in each of the files:

| File Name                     | PID                                  |
| ------------------------------- | ------------------------------------ |
| ./terraform/bootstrap/data_guard/variables_global.tf            | 440d81eb-6657-4a7d-ad93-c7e9cc09e5da |
| ./terraform/bootstrap/single_instance/variables_global.tf | e43d2d9e-0482-48ed-a38e-aa3e63c52954 |
| ./bicep/bootstrap/data_guard/default/data_guard.bicepparam            | 53df3afd-6e55-4930-a481-69938a5b8f0a |
| ./bicep/bootstrap/single_instance/default/single_instance.bicepparam | 5cb0073e-724a-428b-a5ba-1a6d3343effb |
