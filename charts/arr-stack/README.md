# arr-stack

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Media automation stack (Sonarr, Radarr, Lidarr, SABnzbd, and more)

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| buildarr | object | `{"image":"callum027/buildarr:0.7.8@sha256:57e2343fefe5d5701364b5e93b4985dbf08310d7b152f70556bdaba7e9475447","resources":{"limits":{"cpu":"200m","memory":"256Mi"},"requests":{"cpu":"25m","memory":"64Mi"}}}` | Buildarr deployment |
| csi | object | `{"basePath":"/mnt/ssd/kubernetes/nfs-dynamic","driver":"org.democratic-csi.nfs-fast","mountOptions":["nfsvers=4.2","nconnect=8","hard","noatime","nodiratime"],"server":"","storageClassName":"truenas-nfs-fast","volumes":[]}` | CSI storage for app config volumes |
| downloaders | object | `{"flaresolverr":{"image":"ghcr.io/flaresolverr/flaresolverr:v3.4.6@sha256:7962759d99d7e125e108e0f5e7f3cdbcd36161776d058d1d9b7153b92ef1af9e","port":8191,"resources":{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}},"gluetun":{"firewallInputPorts":"8080,9696,8191,5030","firewallOutboundSubnets":"10.96.0.0/12,10.244.0.0/16","image":"qmcgaw/gluetun:v3.41.1@sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab","resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}},"serverCountries":"Sweden","vpnProvider":"protonvpn"},"prowlarr":{"image":"lscr.io/linuxserver/prowlarr:2.3.0.5236-ls139@sha256:9ef5d8bf832edcacb6082f9262cb36087854e78eb7b1c3e1d4375056055b2d82","port":9696,"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}},"sabnzbd":{"image":"lscr.io/linuxserver/sabnzbd:4.5.5-ls244@sha256:1a26f56dfc047b62d5ddc20bc92bdebfbe7c3cb58d2d3523958838a09182d77a","incomplete":{"enabled":true,"mountPath":"/incomplete","size":"100Gi","storageClassName":"truenas-nfs-fast"},"port":8080,"resources":{"limits":{"cpu":"1000m","memory":"1536Mi"},"requests":{"cpu":"100m","memory":"512Mi"}}},"slskd":{"image":"slskd/slskd:0.25.1@sha256:ab9ed50e028b524cefdb7c1dd8ebca368a076e18441ee8ac2326473eb850b4c3","port":5030,"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}}}` | Downloaders pod (gluetun VPN + download clients) |
| externalSecret | object | `{"keys":["WIREGUARD_PRIVATE_KEY","WIREGUARD_ADDRESSES","RADARR_API_KEY","SONARR_API_KEY","PROWLARR_API_KEY","LIDARR_API_KEY","JELLYFIN_API_KEY"],"onePasswordItem":"arr-stack-secrets","refreshInterval":"1h","secretStoreKind":"ClusterSecretStore","secretStoreName":"onepassword","targetSecretName":"arr-secrets"}` | External secrets configuration |
| glance.image | string | `"glanceapp/glance:v0.8.5@sha256:32ab73d80f2b8b5fb0735b0431deb36b93fbb6b2fb43592449b0178c8b83e350"` |  |
| glance.jellyfinLibraries[0] | string | `"Shows"` |  |
| glance.jellyfinLibraries[1] | string | `"Movies"` |  |
| glance.jellyfinUserName | string | `""` |  |
| glance.port | int | `8080` |  |
| glance.resources.limits.cpu | string | `"200m"` |  |
| glance.resources.limits.memory | string | `"256Mi"` |  |
| glance.resources.requests.cpu | string | `"25m"` |  |
| glance.resources.requests.memory | string | `"64Mi"` |  |
| global.annotations | object | `{}` |  |
| ingress | object | `{"annotations":{},"domain":"","enabled":false,"hosts":[]}` | Ingress configuration |
| iscsi | object | `{"driver":"org.democratic-csi.iscsi","iqnPrefix":"iqn.2005-10.org.freenas.ctl:csi-","iqnSuffix":"-shared","portal":"","storageClassName":"truenas-iscsi-rwo","volumes":[]}` | iSCSI storage for app config volumes (SQLite-safe) |
| lidarr.image | string | `"ghcr.io/hotio/lidarr:pr-plugins-3.0.0.4856"` |  |
| lidarr.port | int | `8686` |  |
| lidarr.probePath | string | `"/ping"` |  |
| lidarr.resources.limits.cpu | string | `"1000m"` |  |
| lidarr.resources.limits.memory | string | `"1Gi"` |  |
| lidarr.resources.requests.cpu | string | `"100m"` |  |
| lidarr.resources.requests.memory | string | `"256Mi"` |  |
| nfs | object | `{"mountOptions":["nfsvers=4.2","rsize=1048576","wsize=1048576","hard","noatime","nconnect=8"],"server":"","volumes":[]}` | NFS storage for media |
| radarr | object | `{"image":"lscr.io/linuxserver/radarr:6.0.4.10291-ls295@sha256:ca43905eaf2dd11425efdcfe184892e43806b1ae0a830440c825cecbc2629cfb","port":7878,"probePath":"/ping","resources":{"limits":{"cpu":"1000m","memory":"1Gi"},"requests":{"cpu":"100m","memory":"256Mi"}}}` | Arr apps (radarr, sonarr, lidarr) |
| recyclarr | object | `{"image":"ghcr.io/recyclarr/recyclarr:8.7.0@sha256:2d6107f758d882a59fe9d646aa54fa8a5a4fb7a40995125fade575652a3f7871","resources":{"limits":{"cpu":"200m","memory":"256Mi"},"requests":{"cpu":"25m","memory":"64Mi"}},"schedule":"0 4 * * 1"}` | Recyclarr CronJob |
| sonarr.image | string | `"lscr.io/linuxserver/sonarr:4.0.19.2979-ls320@sha256:24acea2956a0ccb11f103877d9f4f8576600fb34bff34820ed749c2256dab89f"` |  |
| sonarr.port | int | `8989` |  |
| sonarr.probePath | string | `"/ping"` |  |
| sonarr.resources.limits.cpu | string | `"1000m"` |  |
| sonarr.resources.limits.memory | string | `"1Gi"` |  |
| sonarr.resources.requests.cpu | string | `"100m"` |  |
| sonarr.resources.requests.memory | string | `"256Mi"` |  |
| timezone | string | `"Europe/Berlin"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
