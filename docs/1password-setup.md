# 1Password Integration Setup

This guide covers migrating homelab secrets from `.env` files to 1Password vault for secure credential management.

## Why 1Password?

**Benefits**:

- Secrets stored encrypted in 1Password, never in plaintext files
- Biometric authentication (Touch ID) for local development
- Audit trail of all secret access
- Easy secret rotation (update once, applies everywhere)
- Team-ready (share vault instead of copying .env files)
- Future-proof for CI/CD automation with service accounts

**Architecture**:

- **Local Development**: 1Password CLI fetches secrets using Touch ID
- **CI/CD** (future): Service account tokens for GitHub Actions
- **Fallback**: .env file still works if 1Password CLI unavailable

## Prerequisites

1. **1Password Account**: You already have this (using 1Password SSH agent)
2. **1Password CLI**: Installed via Nix flake

   ```bash
   # Verify installation
   which op
   # Should show: /nix/store/.../bin/op
   ```

3. **1Password Desktop App**: Must be running for Touch ID authentication

## Migration Steps

### Step 1: Sign in to 1Password CLI

```bash
# Sign in using your account
eval $(op signin)

# Or if you have multiple accounts
eval $(op signin my.1password.com)
```

**Note**: If Touch ID is configured in 1Password desktop app, the CLI will use it automatically.

### Step 2: Create 1Password Items

Create these items in your **Personal** vault (or create a dedicated "Homelab" vault):

#### Item 1: Proxmox API Token

```text
Type: API Credential
Name: Proxmox API Token
Vault: Personal (or Homelab)

Fields:
  - token_id (text): terraform@pam!terraform
  - token_secret (password): <your-proxmox-token-secret>
```

**How to create**:

1. Open 1Password desktop app
2. Click "+" → "API Credential"
3. Title: "Proxmox API Token"
4. Add custom field: "token_id" (text type)
5. Add custom field: "token_secret" (password type)
6. Copy values from current `.env` file
7. Save

#### Item 2: MikroTik Terraform API

```text
Type: API Credential
Name: MikroTik Terraform API
Vault: Personal (or Homelab)

Fields:
  - username (text): terraform
  - credential (password): <strong-password-for-terraform-user>
  - notes: MikroTik REST API credentials for Terraform/Terragrunt
```

**How to create**:

1. Click "+" → "API Credential"
2. Title: "MikroTik Terraform API"
3. Username: terraform
4. Credential: <strong-password-for-terraform-user>
5. Notes: "MikroTik REST API credentials for Terraform/Terragrunt. User has API permissions to manage network configuration via infrastructure code."
6. Save

**Note**: Separate from admin credentials (stored in "MikroTik Router" item). The `terraform` user is created on the MikroTik during initial setup with `full` group permissions for API access.

#### Item 3: Backblaze B2

```text
Type: API Credential
Name: Backblaze B2
Vault: Personal (or Homelab)

Fields:
  - key_id (text): <your-b2-key-id>
  - application_key (password): <your-b2-application-key>
```

**How to create**:

1. Click "+" → "API Credential"
2. Title: "Backblaze B2"
3. Add custom field: "key_id" (text type)
4. Add custom field: "application_key" (password type)
5. Save

**Note**: This is for future B2 remote state migration (Phase 4).

#### Item 4: OpenVPN

```text
Type: Login
Name: OpenVPN
Vault: Personal (or Homelab)

Fields:
  - username (text): <your-openvpn-username>
  - password (password): <your-b2-password>
```

**How to create**:

1. Click "+" → "Login"
2. Title: "OpenVPN"
3. Username: <your-openvpn-username>
4. Password: <your-b2-password>
5. Save

#### Item 5: Soulseek

```text
Type: Login
Name: Soulseek
Vault: Personal (or Homelab)

Fields:
  - username (text): <your-soulseek-username>
  - password (password): <your-soulseek-password>
```

**How to create**:

1. Click "+" → "Login"
2. Title: "Soulseek"
3. Username: <your-soulseek-username>
4. Password: <your-soulseek-password>
5. Save

### Step 3: Test 1Password CLI Access

```bash
# Test fetching Proxmox credentials
op read "op://Personal/Proxmox API Token/token_id"
op read "op://Personal/Proxmox API Token/token_secret"

# Should return the values you saved (may prompt for Touch ID first)
```

If this works, you're ready to use the integration!

### Step 4: Reload direnv

```bash
# Navigate out and back in to trigger direnv reload
cd .. && cd ~/Projects/homelab

# Check output - should see 1Password CLI being used
# If secrets load successfully, you'll see no warnings
```

### Step 5: Verify Secrets Loaded

```bash
# Check that environment variables are set
echo $PROXMOX_TOKEN_ID
echo $TF_VAR_proxmox_api_token_id

# Both should show the token value from 1Password
```

### Step 6: Test Terragrunt

```bash
# Try running a Terragrunt plan to verify credentials work
cd infrastructure/prod/storage/truenas-primary
terragrunt plan

# Should connect to Proxmox API successfully
```

### Step 7: Backup and Archive .env

Once you've verified everything works:

```bash
# Backup .env to a secure location (NOT in git)
cp .env ~/.homelab-env-backup

# Add deprecation notice to .env
cat > .env << 'EOF'
# DEPRECATED - Secrets migrated to 1Password
# This file is kept as fallback only
# See docs/1password-setup.md for 1Password integration
#
# To restore .env usage, comment out 1Password section in .envrc
# and uncomment dotenv_if_exists

# Backup date: $(date)
EOF
```

**Important**: DO NOT delete `.env` yet. Keep it as a fallback for 30 days, then delete once you're confident 1Password integration is working.

## 1Password Item Reference Paths

For your reference, here are the paths used in `.envrc`:

```bash
# Proxmox
op://Personal/Proxmox API Token/token_id
op://Personal/Proxmox API Token/token_secret

# MikroTik
op://Personal/MikroTik Router/username
op://Personal/MikroTik Router/password

# Backblaze B2
op://Personal/Backblaze B2/key_id
op://Personal/Backblaze B2/application_key

# OpenVPN
op://Personal/OpenVPN/username
op://Personal/OpenVPN/password

# Soulseek
op://Personal/Soulseek/username
op://Personal/Soulseek/password
```

**Path Format**: `op://<vault>/<item-name>/<field-name>`

## Troubleshooting

### Error: "op: command not found"

**Cause**: 1Password CLI not in PATH

**Fix**:

```bash
# Ensure you're in Nix environment
nix develop

# Or reload direnv
direnv allow
```

### Error: "You are not currently signed in"

**Cause**: Need to authenticate with 1Password

**Fix**:

```bash
# Sign in (will prompt for Touch ID)
eval $(op signin)

# Then reload direnv
cd .. && cd ~/Projects/homelab
```

### Warning: "Some 1Password secrets failed to load"

**Cause**: Item names or field names don't match expected paths

**Fix**:

1. Check item exists in 1Password:

   ```bash
   op item list | grep "Proxmox"
   ```

2. Check item structure:

   ```bash
   op item get "Proxmox API Token" --format json
   ```

3. Verify vault name is correct in `.envrc` (default: "Personal")

### Secrets not loading but no errors

**Cause**: 1Password desktop app not running

**Fix**:

1. Open 1Password desktop app
2. Enable Touch ID in Settings → Developer
3. Reload direnv

### Terragrunt fails with authentication error

**Cause**: Environment variables not exported correctly

**Fix**:

```bash
# Check if variables are set
env | grep PROXMOX
env | grep TF_VAR

# If missing, reload direnv
direnv allow
```

## Security Best Practices

### Do's

- ✅ Use Touch ID for local authentication
- ✅ Keep 1Password desktop app locked when not in use
- ✅ Rotate API tokens every 90 days
- ✅ Use separate vaults for different environments (prod/dev)
- ✅ Review 1Password activity log periodically

### Don'ts

- ❌ Don't commit .env file to git (already in .gitignore)
- ❌ Don't store 1Password master password in plaintext
- ❌ Don't share vault access without proper review
- ❌ Don't use same credentials for prod and dev

## Future Enhancements

### Phase 1 (Current): Local Development

- ✅ 1Password CLI integration
- ✅ Touch ID authentication
- ✅ .env fallback

### Phase 2 (Future): CI/CD Automation

When you set up GitHub Actions for automated deploys:

1. **Create 1Password Service Account**:
   - Requires 1Password Teams/Business subscription
   - Create service account with read-only access to Homelab vault

2. **Configure GitHub Actions**:

   ```yaml
   # .github/workflows/terraform.yml
   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Load secrets from 1Password
           uses: 1password/load-secrets-action@v1
           with:
             export-env: true
           env:
             OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
             PROXMOX_TOKEN_ID: op://homelab/proxmox/token_id
             PROXMOX_TOKEN_SECRET: op://homelab/proxmox/token_secret

         - name: Terragrunt Apply
           run: |
             cd infrastructure/prod
             terragrunt run-all apply --terragrunt-non-interactive
   ```

3. **Add service account token to GitHub Secrets**:
   - Settings → Secrets and variables → Actions
   - New repository secret: `OP_SERVICE_ACCOUNT_TOKEN`

### Phase 3 (Future): 1Password Connect

For self-hosted automation (e.g., GitLab CI, Jenkins):

1. Deploy 1Password Connect server (Docker container)
2. Use Connect API for secret retrieval
3. No need for service account tokens

## References

- [1Password CLI Documentation](https://developer.1password.com/docs/cli)
- [1Password GitHub Actions](https://github.com/1password/load-secrets-action)
- [mirceanton/mikrotik-terraform](https://github.com/mirceanton/mikrotik-terraform) (inspiration)

## Migration Checklist

Use this checklist to track your migration:

- [ ] Install 1Password CLI (`which op`)
- [ ] Sign in to 1Password (`eval $(op signin)`)
- [ ] Create "Proxmox API Token" item
- [ ] Create "MikroTik Router" item (for future use)
- [ ] Create "Backblaze B2" item (for future use)
- [ ] Create "OpenVPN" item
- [ ] Create "Soulseek" item
- [ ] Test CLI access (`op read "op://Personal/Proxmox API Token/token_id"`)
- [ ] Reload direnv (`cd .. && cd ~/Projects/homelab`)
- [ ] Verify secrets loaded (`echo $PROXMOX_TOKEN_ID`)
- [ ] Test Terragrunt (`terragrunt plan` in any module)
- [ ] Backup .env file (`cp .env ~/.homelab-env-backup`)
- [ ] Add deprecation notice to .env
- [ ] Wait 30 days before deleting .env
- [ ] Document any custom fields in this guide
- [ ] Review 1Password activity log
