locals {
  repo_root   = get_repo_root()
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  backend     = local.global_vars.locals.backend
}

remote_state {
  backend = "s3"

  config = {
    bucket = local.backend.bucket_name
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = local.backend.region

    # S3-compatible endpoint for Backblaze B2
    endpoints = {
      s3 = "https://${local.backend.endpoint}"
    }

    # S3-compatible settings for Backblaze B2
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    # Encryption at rest
    encrypt = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform {
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()

    arguments = [
      "-lock-timeout=20m",
    ]
  }

  extra_arguments "format_on_apply" {
    commands = [
      "apply",
      "plan",
    ]

    arguments = []
  }

  before_hook "before_hook" {
    commands = ["apply", "plan"]
    execute  = ["echo", "Running Terragrunt for ${path_relative_to_include()}"]
  }

  after_hook "after_hook" {
    commands     = ["apply"]
    execute      = ["echo", "Successfully applied ${path_relative_to_include()}"]
    run_on_error = false
  }
}

inputs = {
  # Each module can override or add to these inputs
}
