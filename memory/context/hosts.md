# SSH Hosts

SSH config: `C:\Users\zuhai\.ssh\config`
Tailscale network: `spangled-koi.ts.net`

## Work Servers (accesstojobs.com / GAO tenant)

| Host | User | Notes |
|------|------|-------|
| `canada.accesstojobs.com` | root | Work server (AWS hosted) |
| `orio.accesstojobs.com` | ubuntu | Work server (AWS hosted) — separate from home orio |

## Home Lab (home.zuhairmahmoud.com) — hosted on ESXi

| Host | Local IP | User | Notes |
|------|----------|------|-------|
| `zuhairs-mini.home.zuhairmahmoud.com` | 192.168.1.217 | zuhairmahmoud | Mac Mini |
| `homeassistant.home.zuhairmahmoud.com` | — | root | Home Assistant instance |
| `mcc.home.zuhairmahmoud.com` | — | ubuntu | Microsoft Connected Cache — serves content for ZM (Azure dev tenant) |
| `debian.home.zuhairmahmoud.com` | — | root | Debian Linux VM (ESXi) |
| `orio.home.zuhairmahmoud.com` | — | ubuntu | Local VM (ESXi) — separate machine from orio.accesstojobs.com |
| `raspberrypi.home.zuhairmahmoud.com` | — | pi | Primary Raspberry Pi |
| `raspberrypi1.home.zuhairmahmoud.com` | — | pi | Raspberry Pi #1 |
| `raspberrypi2.home.zuhairmahmoud.com` | — | pi | Raspberry Pi #2 |

## Tailscale Hosts (spangled-koi.ts.net) — remote access to home lab

| Host | User |
|------|------|
| `orio.spangled-koi.ts.net` | root |
| `debian.spangled-koi.ts.net` | root |
| `raspberrypi.spangled-koi.ts.net` | root |
| `raspberrypi1.spangled-koi.ts.net` | root |
| `raspberrypi2.spangled-koi.ts.net` | root |

## Windows Home Lab — Second ESXi Server

Three Windows Server 2022 VMs running a local Active Directory domain named **home**:
- Syncs to ZM (Azure dev tenant) via **Azure AD Connect** (directory sync)
- Connected to Intune via **Intune Active Directory Connector**

| Host | OS | Notes |
|------|----|-------|
| `winsrv2201` | Windows Server 2022 | Domain Controller for `home` domain |
| `winsrv2202` | Windows Server 2022 | Runs Azure AD Connect + Intune AD Connector |
| `winsrv2203` | Windows Server 2022 | General purpose / currently running SQL Server |

## Infrastructure Notes
- Home lab spans **two ESXi servers**: one for Linux VMs/Pis, one for Windows Server 2022 DCs
- **Tailscale** (`spangled-koi.ts.net`) provides remote access to home lab machines
- **MCC** (Microsoft Connected Cache) on `mcc` serves update/content cache for ZM dev tenant
- Two distinct `orio` machines: one AWS/work, one ESXi/home — no relation
- Local AD domain **home** syncs identities to ZM Azure tenant via Azure AD Connect
