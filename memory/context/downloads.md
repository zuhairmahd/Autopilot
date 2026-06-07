# Downloads Folder — Transient Work Context

Location: `~/Downloads` (C:\Users\zuhai\Downloads)
Purpose: Daily working area for in-progress items before they move to their final home.

## Active Work Items

### VSCode/ — VS Code Intune Deployment Package
A complete VS Code managed deployment package, likely staged for Intune:
- `Install-Silent.ps1`, `install.ps1` — silent installation scripts
- `CreateExtensionsPolicy.ps1` — generate extension allow/block policy
- `vscode-lockdown.ps1`, `vscode.reg` — security lockdown settings
- `policy-detection.ps1`, `policy-remediation.ps1` — Intune remediation pair
- `extensions.json`, `settings.json`, `keybindings.json` — managed config
- `VSCode-win32-x64-1.116.0.exe` — installer binary
- `Deploy-VSCodePolicies.ps1` — top-level deployment orchestrator

### jfw/ + jfw4intune/ — JAWS For Windows Deployment
JAWS screen reader installer package being prepared for Intune deployment:
- `jfw/` — raw installer files (JAWS setup, Visual C++ runtimes, WebView2, Sentinel driver)
- `jfw4intune/JAWS setup package.intunewin` — packaged for Intune Win32 app
- `jfw4intune/EnableJAWSAutoStart2026-org.ps1` — detection/install script

### nvda/ + nvda4intune/ — NVDA Deployment
NVDA (NonVisual Desktop Access) screen reader, also being packaged for Intune:
- `nvda/nvda_2025.3.3.exe` — installer
- `nvda4intune/nvda_2025.3.3.intunewin` — packaged for Intune

### helpdesk/ — Helpdesk Autopilot Deployment
A deployed instance of the Autopilot tool configured in helpdesk mode:
- `main.exe`, `settings.psd1`, `arabictutor.com.psd1` — app + config

### openclaw/ — Large AI Messaging Platform (Exploring only, not contributing)
A major open-source TypeScript project: `github.com/openclaw/openclaw`
- AI chat platform that bridges multiple LLM providers + messaging channels
- **LLM extensions**: Anthropic, OpenAI, Google, Azure, Ollama, DeepSeek, Groq, Mistral, and many more
- **Messaging channels**: Telegram, Discord, Slack, Signal, iMessage, WhatsApp, Teams, IRC, Matrix, Zalo, etc.
- **Apps**: iOS, Android, macOS, Chrome extension
- **Skills system** (similar concept to Cowork skills): 1Password, Notion, GitHub, Obsidian, Slack, etc.
- Stack: TypeScript, Node.js, Docker/Podman, Kubernetes

## Key Terms from Downloads

| Term | Meaning |
|------|---------|
| JFW | JAWS For Windows (screen reader) — same as JAWS |
| NVDA | NonVisual Desktop Access — free open-source screen reader |
| intunewin | Intune Win32 app package format (.intunewin) |
| openclaw | Open-source AI messaging platform Zuhair is exploring |
| Swabble | Sub-component/package within openclaw |
