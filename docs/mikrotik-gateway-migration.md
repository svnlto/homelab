# MikroTik Gateway Migration (Completed 2026-02-11)

> Migrated MikroTik CRS310 from VLAN switch (behind Beryl AX) to main gateway
> with NAT. Beryl is now a WiFi-only access point.

## Previous State

```text
Internet -> O2 Homespot (192.168.8.1) -> Beryl AX (192.168.8.2, NAT/DHCP/WiFi)
            -> MikroTik ether1 (192.168.0.4, VLAN switch only)
```

- **Beryl AX (sorgan, 192.168.0.1)**: Main gateway, NAT, DHCP for LAN, WiFi AP
- **MikroTik CRS310 (nevarro, 192.168.0.4)**: VLAN-aware bridge, K8s DHCP
- **Default route on MikroTik**: `0.0.0.0/0 -> 192.168.0.1` (Beryl)

## Current State

```text
Internet -> O2 Homespot (192.168.8.1) -> MikroTik ether1 (192.168.8.2, WAN)
                                          MikroTik ether2 -> Pi-hole (VLAN 20)
                                          MikroTik ether3 -> Beryl AP (VLAN 20)
                                          MikroTik ether4 -> din iDRAC (VLAN 1)
                                          MikroTik ether5 -> grogu iDRAC (VLAN 1)
                                          MikroTik sfp+1/2 -> grogu/din (trunks)
```

- **MikroTik CRS310 (nevarro, 192.168.0.1)**: Main gateway, NAT, DHCP, firewall
- **Beryl AX**: AP mode only — bridges WiFi to VLAN 20
- **Default route on MikroTik**: `0.0.0.0/0 -> 192.168.8.1` (O2 Homespot)

### Benefits

- Single DHCP/firewall authority (MikroTik)
- No double-NAT between Beryl and MikroTik
- All devices use consistent gateway (192.168.0.1) and DNS (192.168.0.53)
- Input chain firewall protects internet-facing router

## Code Changes

| File | Change |
| ---- | ------ |
| `globals.hcl` | Added `wan` section, updated access_ports, api_url, gateway |
| `base/main.tf` | Added WAN IP resource, parameterized default route |
| `base/variables.tf` | Added wan_interface, wan_address, wan_gateway |
| `base/outputs.tf` | Added wan_interface output |
| `base/terragrunt.hcl` | Added WAN inputs from globals |
| `firewall/main.tf` | Input chain (8 rules), forward rules, `routeros_move_items` |
| `firewall/terragrunt.hcl` | WAN source: `wan.interface` |
| `dhcp/*/main.tf` | Added `dynamic_lease_identifiers` |
| All test files | Updated api_url, added WAN/input chain assertions |

## Migration Steps (as executed)

### 1. Manual Preparation

- Added ether3 to bridge-vlans (had to remove from factory `bridge` first)
- Added temporary ether6 for Mac management access

### 2. Switch Beryl to AP Mode

Connected to Beryl admin over WiFi, switched to AP mode. Beryl reboots
and bridges WiFi onto ether3 -> VLAN 20.

### 3. MikroTik Switchover (via WinBox MAC access)

```routeros
/interface bridge port remove [find where interface=ether1]
/ip address set [find where interface=vlan-20-lan] address=192.168.0.1/24
/ip address add address=192.168.8.2/24 interface=ether1 comment="WAN to O2 Homespot"
/ip route remove [find where dst-address="0.0.0.0/0"]
/ip route add dst-address=0.0.0.0/0 gateway=192.168.8.1
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

Then moved O2 Homespot cable to MikroTik ether1.

### 4. Terragrunt Apply (aligned state with reality)

Imported manually-created resources, then applied:

```bash
# Imports (bridge port, WAN IP, default route, DHCP pool/server/network, NAT)
terragrunt import 'routeros_interface_bridge_port.access_ports["beryl_ap"]' '*D'
terragrunt import 'routeros_ip_address.wan' '*8'
terragrunt import 'routeros_ip_route.default' '*80000003'
# ... DHCP and NAT imports

just tg-apply-module prod/mikrotik/base
just tg-apply-module prod/mikrotik/firewall
just tg-apply-module prod/mikrotik/dhcp/vlan-20-lan
```

### 5. Cleanup

- Removed temporary ether6 from bridge-vlans
- Deleted old factory `bridge` (had ether7/ether8, both inactive)
- Verified: internet, DNS, WiFi all working

## No Changes Required

These already used `192.168.0.1` as gateway:

- **Proxmox hosts**: `gateway 192.168.0.1` (Ansible-managed)
- **NixOS configs**: Pi-hole and arr-stack `defaultGateway = "192.168.0.1"`

## Provider Quirks

- `routeros_ip_address`: Sends `vrf` parameter that CRS310 rejects. Workaround:
  match comments on import to avoid unnecessary updates.
- `routeros_ip_dhcp_server`: Requires explicit `dynamic_lease_identifiers`; nulling
  it out causes a 400 error.
- RouterOS normalizes `24h` to `1d` for lease times — use `1d` in config.
