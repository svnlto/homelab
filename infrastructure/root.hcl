locals {
  repo_root = get_repo_root()
}

remote_state {
  backend = "local"

  config = {
    path = "${get_parent_terragrunt_dir()}/.terraform-state/${path_relative_to_include()}/terraform.tfstate"
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
