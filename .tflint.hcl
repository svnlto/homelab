config {
  call_module_type    = "all"
  force               = false
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Terragrunt generates provider.tf (with required_version + required_providers)
# and provider_variables.tf at runtime. TFLint runs against source files where
# these don't exist, so these rules produce false positives.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}

rule "terraform_unused_declarations" {
  enabled = false
}
