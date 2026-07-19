# ==============================================================================
# TrueNAS VM Module - Version Requirements
# ==============================================================================

# Provider requirements come from the generated provider.tf (prod/provider.hcl),
# matching the modules/images pattern. Declaring required_providers here too
# would duplicate the root provider config and fail init.
terraform {
  required_version = ">= 1.14.0"
}
