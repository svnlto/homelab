# MikroTik CRS Router Setup Guide

## Prerequisites

- MikroTik CRS310-8G+2S+IN with factory default configuration
- MikroTik is the primary gateway at 192.168.0.1 (post-migration from Beryl AX)

## Phase 0: Initial Router Setup (Before Terragrunt)

### Step 1: Connect and Access

Connect your Mac directly to the router's 1GbE port. Use WinBox (<https://mt.lv/winbox>)
and connect via MAC address from the **Neighbors** tab. Default login: `admin` with the
password printed on the sticker on the device.

**Factory reset (if second-hand):** Hold reset button during power-on until the user LED
flashes, then release immediately. Holding longer enters Netinstall mode.

### Step 2: Set Static IP, Gateway, and DNS

Use the **Quick Set** tab in WebFig to configure basic networking:

| Field               | Value             |
| ------------------- | ----------------- |
| Mode                | Bridge            |
| Address Acquisition | Static            |
| IP Address          | 192.168.0.1       |
| Netmask             | 255.255.255.0     |
| Gateway             | 192.168.8.1       |
| DNS Servers         | 192.168.0.53      |
| Router Identity     | nevarro           |

> **Note:** This is the post-migration configuration where MikroTik is the primary
> gateway. The upstream gateway (192.168.8.1) is the ISP router/modem.

Click **Apply Configuration**. The remaining steps require the **Terminal** tab in
WebFig or SSH (`ssh admin@192.168.0.1`).

### Step 3: Set Password and Update Firmware

```routeros
/user set admin password=<STRONG_PASSWORD>
/system package update check-for-updates
/system package update install
```

Ensure RouterOS is v7.13 or later.

### Step 4: Create Terraform User

```routeros
/user add name=terraform group=full password=<STRONG_PASSWORD>
```

Store password in 1Password item `MikroTik Terraform API` (credential field).
`.envrc` fetches it via: `op read "op://Personal/MikroTik Terraform API/credential"`

### Step 5: Enable REST API with SSL

RouterOS 7.x requires a CA before signing server certs:

```routeros
/certificate add name=local-ca common-name=local-ca key-usage=key-cert-sign,crl-sign
/certificate sign local-ca
/certificate add name=api-cert common-name=mikrotik-api
/certificate sign api-cert ca=local-ca
/ip service set www-ssl certificate=api-cert disabled=no port=443
/ip service set api-ssl certificate=api-cert disabled=no
```

Signing takes 10-30 seconds on the ARM CPU.

### Step 6: Test API Access

```bash
curl -k -u terraform:<password> https://192.168.0.1/rest/system/resource
```

### Step 7: Verify Credentials

```bash
cd ~/Projects/homelab && direnv allow
echo "Username: $MIKROTIK_USERNAME"
[ -n "$MIKROTIK_PASSWORD" ] && echo "Password: [SET]" || echo "Password: [NOT SET]"
```

## Phase 3: Terragrunt Deployment

**Schedule a maintenance window** — this reconfigures the router network.

### Step 1: Deploy Base Networking (CRITICAL)

```bash
just tg-plan-module prod/mikrotik/base
just tg-apply-module prod/mikrotik/base

ping 192.168.0.1   # Router
ping 192.168.0.10  # Proxmox grogu
ping 192.168.0.53  # Pi-hole
```

**If network breaks:** SSH to `admin@192.168.0.1` and run `/system reset-configuration`,
or hold the physical reset button during boot.

### Step 2: Deploy DHCP Servers

```bash
just tg-apply-module prod/mikrotik/dhcp/vlan-20-lan
just tg-apply-module prod/mikrotik/dhcp/vlan-30-k8s-shared
just tg-apply-module prod/mikrotik/dhcp/vlan-31-k8s-apps
just tg-apply-module prod/mikrotik/dhcp/vlan-32-k8s-test
```

### Step 3: Deploy Firewall Rules

```bash
just tg-plan-module prod/mikrotik/firewall
just tg-apply-module prod/mikrotik/firewall
```

### Step 4: Deploy DNS Forwarding

```bash
just tg-apply-module prod/mikrotik/dns
nslookup google.com 192.168.0.1
```

## Troubleshooting

```routeros
/interface vlan print
/interface bridge print
/ip address print
/ip dhcp-server print detail
/ip firewall filter print stats
/ip dns print
```

**Emergency access:** SSH to `admin@192.168.0.1`, or use WinBox Neighbors tab to connect
via MAC address (works without IP).

## Next Steps

1. Update Proxmox bridge configuration for new VLANs
2. Deploy Kubernetes clusters on K8s VLANs
3. Add router to observability stack
