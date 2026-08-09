# Terraform Standards

Version: 1.1

Last updated: 2026-07-27

Purpose
-------

Document recommended Terraform standards for infrastructure-as-code, module design, and deployment practices. This is a living document and will be updated over time as new Terraform capabilities, security guidance, and best practices are established.

Scope
-----

- Terraform module structure and naming.
- Terraform code quality, validation, and testing.
- Secrets handling and remote state management.
- CI/CD and deployment readiness for Terraform changes.

Basic Standards
---------------

- Use Terraform version constraints and lock the provider versions.
  - Example: `terraform { required_version = ">= 1.5, < 2.0" }`.
  - Pin provider versions in `required_providers` and commit the generated lock file.
- Keep modules small, reusable, and purpose-driven.
  - Each module should do one thing and expose an explicit set of inputs and outputs.
  - Avoid deep nesting and overly broad "root" modules.
  - Always use standardized, approved modules for IL4 and IL5 resources so compliance controls are built into resource creation.
  - All standardized modules should meet the requirements defined in IL4, IL5, and NIST policies as enforced by Defender.
    - For example, VM and VMSS module implementations should require double encryption for all disks.
- Use consistent naming for resources, variables, outputs, and modules.
  - Require snake_case for variables, outputs, resource names, and module names.
  - Avoid hardcoded names and use interpolation only for user-provided values.
- Enforce formatting and validation on every change.
  - Run `terraform fmt` before commit and use `terraform validate` in CI.
  - Use `terraform init -backend-config` and `terraform plan` as part of validation.
- Protect secrets and sensitive values.
  - Never store secrets in Terraform code or source control.
  - Use environment variables, remote state secrets, or Vault-style secret providers.
  - When storing secrets in a key vault, always include a `content_type` that describes the type of secret and an expiration date for the secret.
    - Example: `content_type = "password"` for credentials.
  - Customer-managed keys should include a dynamic rotation policy configured by variable, with a minimum rotation interval of 18 months.
  - For redeployments prior to rotation expiration, ignore rotation-policy changes unless the expiration or policy itself is intentionally updated.
  - For external calls such as licensing or activation, use `lifecycle { ignore_changes = [...] }` when reapplying would cause side effects; document the reason and scope of the ignore.
  - Mark sensitive outputs with `sensitive = true`.

Example key vault secret
------------------------

```hcl
resource "azurerm_key_vault_secret" "db_password" {
  name            = "db-password"
  value           = var.db_password
  key_vault_id    = azurerm_key_vault.example.id
  content_type    = "password"
  expiration_date = timeadd(timestamp(), var.db_password_ttl) # ISO 8601 datetime string
  tags            = local.standard_tags
}
```

Example customer-managed key with rotation
------------------------------------------

```hcl
resource "azurerm_key_vault_key" "cmk" {
  name         = "cmk-key"
  key_vault_id = azurerm_key_vault.example.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  tags = local.standard_tags

  rotation_policy {
    automatic {
      time_before_expiry = var.cmk_rotation_trigger_before_expiry # ISO 8601 duration, e.g. "P30D"
    }

    expire_after         = var.cmk_rotation_interval # ISO 8601 duration, e.g. "P18M"
    notify_before_expiry = var.cmk_rotation_notify_before_expiry # ISO 8601 duration, e.g. "P29D"
  }
}
```

Example disk encryption set for VM/VMSS double-encrypted disks
----------------------------------------------------------------

```hcl
resource "azurerm_disk_encryption_set" "vm_disk_set" {
  name                = "vm-disk-encryption-set"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  key_vault_id        = azurerm_key_vault.example.id
  key_url             = azurerm_key_vault_key.cmk.key_vault_key_id
  encryption_type     = "EncryptionAtRestWithPlatformAndCustomerKeys"
  identity {
    type = "SystemAssigned"
  }

  tags = local.standard_tags
}

resource "azurerm_role_assignment" "disk_encryption_set_reader" {
  scope                = azurerm_disk_encryption_set.vm_disk_set.id
  role_definition_name = "Reader"
  principal_id         = azurerm_disk_encryption_set.vm_disk_set.identity[0].principal_id
}

resource "null_resource" "wait_for_rbac_propagation" {
  depends_on = [azurerm_role_assignment.disk_encryption_set_reader]

  provisioner "local-exec" {
    command = "sleep 30"
  }
}
```

Use this `azurerm_disk_encryption_set` in VM or VMSS modules to enforce customer-managed key encryption on all managed disks. The underlying Azure platform encryption remains active, providing the required double encryption posture for IL4 and IL5 workloads.

Example storage account with a customer-managed key
---------------------------------------------------

```hcl
resource "azurerm_user_assigned_identity" "storage_msi" {
  name                = "storage-account-cmk-identity"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_storage_account" "secure_storage" {
  name                              = "stcmkexample"
  resource_group_name               = azurerm_resource_group.example.name
  location                          = azurerm_resource_group.example.location
  account_tier                      = "Standard"
  account_replication_type          = "GRS"
  infrastructure_encryption_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_msi.id]
  }

  customer_managed_key {
    key_vault_key_id = azurerm_key_vault_key.cmk.id
    identity_id      = azurerm_user_assigned_identity.storage_msi.id
  }

  tags = local.standard_tags
}

# RBAC on the key will require propagation time after the user-assigned identity is created and granted permissions on the CMK.
# Allow at least 120 seconds for Azure RBAC propagation before creating the storage account with the CMK.
# Note: enabling infrastructure encryption on an existing storage account will require recreating the account.
resource "null_resource" "wait_for_cmk_rbac_propagation" {
  depends_on = [azurerm_user_assigned_identity.storage_msi, azurerm_role_assignment.disk_encryption_set_reader]

  provisioner "local-exec" {
    command = "sleep 120"
  }
}
```

Note: The storage account customer-managed key configuration uses the same Key Vault key and user-assigned identity in a single resource definition without azapi. Ensure the identity has the required permissions on the CMK before Terraform creates the storage account and the sleep created to allow the RBAC for the UMI to be propogated.

Note: To meet the infrastructure encryption requirement on older storage accounts, create a new storage account with `infrastructure_encryption_enabled = true`, migrate data to the new storage account, and then destroy the old storage account.

Example variables for dynamic rotation and expiration
-----------------------------------------------------

```hcl
variable "db_password_ttl" {
  type        = string
  description = "Time-to-live for the database password secret relative to now, in ISO 8601 duration format."
  default     = "P365D"
}

variable "cmk_rotation_interval" {
  type        = string
  description = "Rotation interval for the customer-managed key in ISO 8601 duration format. Minimum 18 months."
  default     = "P18M"
}

variable "cmk_rotation_trigger_before_expiry" {
  type        = string
  description = "Time before CMK expiry to trigger rotation actions, in ISO 8601 duration format."
  default     = "P30D"
}

variable "cmk_rotation_notify_before_expiry" {
  type        = string
  description = "Time before CMK expiry to notify or trigger alerts, in ISO 8601 duration format."
  default     = "P29D"
}
```

Example output referencing a module
-----------------------------------

```hcl
output "db_password_secret_id" {
  value       = module.key_vault.db_password_secret_id
  description = "Database password secret ID returned from the key vault module."
  sensitive   = true
}
```

Example import when resources already exist and need to be imported into state
-------------------------------------------------------------------------------

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "my-tf-example-rg"
  location = "eastus"
}

import {
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/existing-rg"
  to = azurerm_resource_group.example
}
```



- Use remote state storage with locking enabled for shared environments.
  - Store remote state in a secure backend such as Azure Storage, AWS S3 with locking, or HashiCorp Cloud.
  - Enable state locking and versioning.

Azure Storage remote state example
----------------------------------

Use an Azure Storage account for Terraform state with a container and blob key. Store secrets in secure variables or Azure Key Vault.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = "terraform.tfstate"
    tenant_id            = var.azure_tenant_id
    subscription_id      = var.azure_subscription_id
    use_azuread_auth     = true
  }
}
```

Recommended variable names for Azure remote state configuration:

```hcl
variable "state_resource_group_name" {
  type        = string
  description = "Azure resource group containing the Terraform remote state storage account."
}

variable "state_storage_account_name" {
  type        = string
  description = "Azure Storage account name used for Terraform remote state."
}

variable "state_container_name" {
  type        = string
  description = "Blob container name used for storing the Terraform state file."
}
```

- Use service principals or managed identity authentication for CI agents.
- Protect access to the storage account and container with Azure RBAC.

Code and Module Quality
-----------------------

- Use input validation for variables with `validation {}` blocks.
- Require every variable and output to include a `description` attribute.
- Document variables and outputs using `description` attributes.
- Provide default values only when they are safe and appropriate.
- Avoid `count`/`for_each` misuse by making resource structures explicit when possible.
- Use `locals` for repeated expressions and complex computed values.
- Prefer data sources over hardcoded values wherever possible.

Security and Compliance
-----------------------

- Use static analysis tools such as `tflint`, `checkov`, or `terraform validate` with policy checks.
- Run infrastructure-as-code security scans in CI for every merge request.
- Use `terraform-docs` or similar tooling to keep module documentation current.
- Ensure resource tags and metadata include environment, application, and owner information.

Testing and Deployment
----------------------

- Validate Terraform code in CI before merge.
- Use `terraform plan` to review changes and ensure drift is intentional.
- Keep a clear separation between module code and environment-specific configuration.
- Use workspaces or separate state files for different environments.
- Review state changes and drift reports as part of deployment readiness.

Future Work
-----------

- Define standard reusable Terraform module templates.
- Add guidance for Terraform Cloud / Enterprise policy enforcement.
- Standardize Terraform drift detection and remediation workflows.
- Capture lessons learned and update this living document as practices evolve.
