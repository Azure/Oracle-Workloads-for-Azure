---
title: Identity and Access Management for the Oracle@Azure landing zone accelerator
description: Identity and Access Management for the Oracle@Azure landing zone accelerator.
author: sihbher
ms.author: sihbher
ms.date: 11/13/2023
ms.topic: conceptual
ms.service: cloud-adoption-framework
ms.subservice: scenario
ms.custom: 
  - think-tank
  - e2e-oracle
  - engagement-fy24
---

#
# **Identity and Access Management for the Oracle@Azure landing zone accelerator**

## **In this article**

1. [Design Considerations](#design-considerations)
2. [Design Recommendations](#design-recommendations)

This article builds on some of the considerations and recommendations that are defined in the [Azure landing zone design](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/). The design Area Identity and Access Management (IAM) is part of a collection describing Oracle Database@Azure landing zone accelerator.

The goal of this document is to define the customer experience for interacting with IAM resources when deploying Oracle Database@Azure.

Following the guidance, the article provides you with the design guidelines, architecture, and recommendations to deploy Oracle Database@Azure.

## **Design Considerations**

Most databases store sensitive data. To have an Identity Access Management (IAM) architecture in which to land these workloads, implementing IAM only at the database level isn't sufficient. This article provides design considerations and recommendations for identity and access management that you can apply when you deploy Oracle database@Azure landing zone accelerator.

Learn more about the [identity and access management](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/identity-access) design area.

### Best practices.

Follow best practices in terms of how to manage groups, roles and permissions.

- **Familiarize with Built-in Roles** : Understand the built-in roles provided by Azure, such as Owner, Contributor, Reader, and User Access Administrator. Reference: [Understand the different roles](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles).
- **Custom Roles** : When built-in roles don't meet your specific needs, create custom roles with granular permissions. Reference: [Create custom roles](https://docs.microsoft.com/azure/role-based-access-control/custom-roles).
- **Use Groups for Easier Management** : Rather than assigning permissions to individual users, use groups to manage permissions for multiple users at once. Reference: [Manage access to Azure resources using RBAC and Azure AD groups](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-groups).
- **Keep Group Membership Dynamic** : Utilize Azure AD's dynamic groups to automatically add or remove users based on user attributes. Reference: [Create or update a dynamic group in Azure Active Directory](https://docs.microsoft.com/azure/active-directory/enterprise-users/groups-create-rule).
- **Scoped Assignments** : Assign permissions to the narrowest scope necessary, such as to a resource, resource group, or subscription level. Reference: [Understand scope](https://docs.microsoft.com/azure/role-based-access-control/scope-overview).
- **Review and Audit** : Regularly review and audit role assignments using Azure AD and Azure Activity Logs. Reference: [List Azure role assignments using the Azure portal](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-list-portal), and [Audit operations with Resource Logs](https://docs.microsoft.com/azure/azure-monitor/logs/resource-logs-overview).
- **Role Assignment Best Practices** : Follow best practices for role assignments, including avoiding direct assignment where possible and preferring group assignment. Reference: [Best practices for role assignments](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-best-practices).

## **Design Recommendations**
Identity management is a fundamental framework that governs access to important resources. You will have different personnel and access levels for your Oracle Database@Azure, making sure each one has the proper permission is crucial for the safety and reliability of your data and databases.

You will have three main types of identities:

1. Identities allowed to manage and monitor the Oracle Database @Azure (called Exadata, or ExaDB-D for short) infrastructure resources.
2. Identities to manage and monitor the databases in the ExaDB-D infrastructure, these will have access to OCI cloud.
3. Identities within the ExaDB-D databases to handle and access the data.

### **Centralized Identity**

Microsoft Entra ID is used to centrally manage the identities and to control access to the resources created by the Oracle Database@Azure. After completing the onboarding steps, you should have both 1) federated access between Azure and OCI. 2) predefined groups with permissions for different operations. Follow these considerations when managing your identities:

- Prevent using standing permission for tools and servers accessing and managing the databases. Use application tokens when relevant.
- Utilize Groups, Roles and Permissions to control the level of access each user has. For example, an auditor will require only read-only access to view past actions in the system, add them to the Microsoft Entra ID group with read-only permissions.
- Use 2-factor authentication for every human identity that requires access.
- An Admin user is created in OCI when a new account and tenancy is provisioned, avoid using this identity for day-to-day operations and instead manage the infrastructure administrator group to provide the relevant individuals elevated access.
- For the limited group of individuals that will require OCI access – to create Pluggable Databases (PDB) for instance – make sure they are added to the proper group in OCI identity, with the proper permissions to access only certain resources.

### **Groups, Roles and Permissions**

- Use RBAC to ensure the least privileged access to your database server and data (including backups).
- Add user to the pre-created groups based on permissions, avoiding providing users access permissions directly if not part of a group.
- When giving new permissions to groups, follow the least privileges approach.
- Enforce zero-trust [network security](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/security#zero-trust) across the network perimeter.
- Use Azure compliance capabilities to ensure compliance with industry and regulatory requirements. Use following links to get more information on industry and regulatory standards supported.
  - [Azure compliance documentation | Microsoft Learn](https://learn.microsoft.com/azure/compliance/)
  - [Azure and other Microsoft cloud services compliance offerings - Azure Compliance | Microsoft Learn](https://learn.microsoft.com/azure/compliance/offerings/)
  - [Compliance in the trusted cloud | Microsoft Azure](https://azure.microsoft.com/explore/trusted-cloud/compliance/)

#### Groups

| **Group name** | **Description** |
| --- | --- |
| **odbaa-exa-infra-administrators** | **Administrators of the ExaDB-D infrastructure**|
| **odbaa-vm-cluster-administrators** | **Administratros for the VM clusters in ExaDB-D** |

###

#### Roles

| **Role name** | **Permissions** | **Description** |
| --- | --- | --- |
| **TBD - odbaa-exa-infra-administrator** | All Infrastructure operations on ExaDB-D | Allows CRUDL operations on ExaDB-D, provisioning, deleting, viewing and changing server count, OCPUs, regions etc. |
| **TBD - odbaa-vm-cluster-administrator** | All VM Cluster operations in ExaDB-D | Allows CRUDL operations for VM clusters. Create clusters, delete, choose vNet, list ExaDB-D to name a few. |

