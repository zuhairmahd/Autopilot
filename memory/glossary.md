# Glossary — Decoder Ring

## Tenants & Azure AD Configs

| Term | Meaning |
|------|---------|
| ZM | Zuhair's personal **dev/test tenant** — Azure AD app config (config-zm-*) |
| GAO | Zuhair's **day job tenant** — Azure AD app config (config-GAO-*) |

## Acronyms & Abbreviations

| Term | Meaning |
|------|---------|
| PS5 / 5.1 | PowerShell 5.1 — Windows built-in; required for app compatibility |
| PS7 / pwsh | PowerShell 7+ — required for running Pester tests |
| MDM | Mobile Device Management (what Intune is) |
| ESP | Enrollment Status Page (Windows Autopilot concept) |
| OOB / OOBE | Out-of-box experience — device setup flow Autopilot intercepts |
| WHFB | Windows Hello for Business |
| PIV | Personal Identity Verification (smart card auth) |

## Tools & Products Referenced in Scripts

| Term | Meaning |
|------|---------|
| JAWS / JFW | Job Access With Speech — screen reader for blind/visually impaired users; Zuhair maintains yearly EnableJAWSAutoStart scripts and deploys via Intune |
| NVDA | NonVisual Desktop Access — free open-source screen reader; also deployed via Intune |
| Narrator | Windows built-in screen reader |
| Zscaler | Network security/proxy platform; scripts toggle strict enforcement mode |
| AVD | Azure Virtual Desktop — cloud-hosted Windows desktops |
| WHP | Windows Hello Provisioning (Enable-WHP.ps1) |
| pwsscripts | Zuhair's personal PowerShell script collection (~/code/pwsscripts) |
| intunewin | Intune Win32 app package format used to deploy apps via Intune |
| ESXi | VMware ESXi hypervisor — Zuhair's home lab runs on this |
| MCC | Microsoft Connected Cache — home lab server (`mcc.home.zuhairmahmoud.com`) that caches Windows/Intune content for the ZM dev tenant |
| home | Local AD domain name for Zuhair's Windows home lab — syncs to ZM Azure tenant |
| Azure AD Connect | Directory sync tool that syncs the `home` AD domain to ZM (Azure dev tenant) |
| Intune AD Connector | Connects the `home` domain to Intune for device management in ZM tenant |
| Tailscale | VPN mesh network — `spangled-koi.ts.net` provides remote access to home lab |
| openclaw | Open-source AI messaging platform (github.com/openclaw/openclaw) — Zuhair exploring for reference only, not contributing |

## Products / Services

| Name | What |
|------|------|
| Autopilot | This project — the Autopilot Management Tool PowerShell app |
| Windows Autopilot | Microsoft's zero-touch device provisioning system |
| Intune | Microsoft Endpoint Manager / Intune — MDM platform |
| Graph API | Microsoft Graph API — REST API for M365 / Azure AD |
| Entra ID | Azure Active Directory (rebranded as Entra ID) |
| Pester | PowerShell testing framework v5 |

## App Modes

| Mode | Who |
|------|-----|
| full | System admins — all features |
| admin | IT managers — admin + advanced + helpdesk |
| advanced | Technical staff — advanced + helpdesk |
| helpdesk | Help desk — device assignment + troubleshooting |
| registration | Device specialists — Autopilot enrollment |
| advancedRegistration | Senior device specialists — extended registration |
| custom | Special deployments — user-defined |

## Key Functions

| Shorthand | Full name |
|-----------|-----------|
| `AssessDeviceState` | Multi-stage device readiness orchestrator |
| `CallGraphAPI` | Core Graph API HTTP client |
| `ShowMenu` | Central menu rendering engine |
| `Resolve-DirectoryObject` | Unified user/group resolver (preferred over deprecated `Resolve-UserWithMatching`) |
| `Invoke-CacheManagement` | Unified cache operations |
| `Write-Log` | Structured logging function used by all functions |
