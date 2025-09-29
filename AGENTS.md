# Repository Guidelines

## Project Structure & Module Organization
`main.ps1` bootstraps the app by dot-sourcing every module in `functions/`. Each subfolder (device, menu, graph, reporting, etc.) groups scripts by responsibility; keep modules self-contained and suited for PowerShell 5.1. Configuration defaults live in the root `.psd1` files (`settings.psd1`, `menu.psd1`, `strings.psd1`), while runtime secrets are generated under `.secrets/` and log output lands in `Logs/`. Tests, demos, and validation harnesses sit in `TestScripts/`, and deeper references live in `docs/`. Binary drops like `main.exe` are build outputs only.

## Build, Test, and Development Commands
Launch the interactive tool with `.\main.ps1 -Verbose -LogLevel "Debug"` to mirror developer telemetry. Use `.\test.ps1` for lightweight module import checks, then run `.\TestScripts\Test-Runner.ps1 -TestCategory core`; extend to `syntax`, `integration`, or `comprehensive` depending on scope. Create signed builds with `.\CreateRelease.ps1 -Stage Build` (pair with `-WhatIf` for rehearsal). Tail `Logs\Autopilot.log` to watch Graph and menu activity while iterating.

## Coding Style & Naming Conventions
Stick to four-space indentation, ~120-character lines, and approved PowerShell verb-noun PascalCase (`Get-DeviceProfileStatus`). Variables use camelCase, constants use ALL_CAPS, and every public function needs comment-based help plus `$functionName = $MyInvocation.MyCommand.Name` for logging context. Favor `try/catch`, `Write-Verbose`, and the shared `Write-Log` helper; avoid 5.1-incompatible constructs such as ordered hashtables or string interpolation. No automated formatter runs here—the style guidance and reviewers are the guardrails.

## Testing Guidelines
The unified runner is mandatory. Start with `.\TestScripts\Test-Runner.ps1 -TestCategory syntax` to confirm modules load, add `core` for functional confidence, and escalate to `integration` or `comprehensive` when touching cross-cutting workflows. New features should add focused scripts under `TestScripts/test-*.ps1` and update the registry in `Test-Runner.ps1` when new categories are needed. Preserve verbose logging so failures ship actionable diagnostics.

## Commit & Pull Request Guidelines
Craft single-line commit subjects in sentence case (`Fix vendor validation logging`), keeping them under 72 characters, and reference issues in the body (`Fixes #123`) when relevant. Before opening a PR, ensure the runner passes for the categories you impacted, update any affected docs in `docs/`, and attach screenshots or log snippets for menu or UI changes. PR descriptions should outline scope, validation commands, and configuration prerequisites so reviewers can reproduce quickly.

## Security & Configuration Tips
Never commit `.secrets/` contents or tenant-specific `.psd1` derivatives. When adding configuration keys, update `settings.psd1`, refresh the docs, and review Graph scopes for least privilege. Reuse the helpers in `functions/encryptionFunctions` rather than introducing new cryptography so secrets stay aligned with the existing AES workflow.
