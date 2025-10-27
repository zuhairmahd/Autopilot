# Implementation Plan: Replace Manual Menu Wiring with Data-Driven Loader

Goal
---
Replace the manual `NewMenu`/`AddMenuItem` blocks in `main.ps1` with a data-driven loader that reads `menu.psd1` (already loaded via `Initialize-ApplicationConfiguration`) and builds menus and actions programmatically. The loader should be robust, testable, and backwards compatible with existing menu fields.

Summary
---
- Use `menu.psd1` as the single source of truth for menus and menu items.
- Introduce an action registry that maps `action` keys (strings) to ScriptBlocks/functions.
- Two-pass menu builder:
  1. Create all menu objects (so submenu references exist)
  2. Attach items to menus, resolving submenus and actions
- Support `actionParameters` for per-item configuration and `dynamic` menu generators executed lazily when a menu is displayed.

Requirements / Constraints
---
- No change in external behavior: menus must appear and work the same to users.
- Do not change existing function names (e.g., `AddMenuItem`, `NewMenu`) unless necessary; prefer to reuse them.
- Keep `menu.psd1` backward-compatible: normalize `type`/`blockType` and optional fields.
- Provide clear logging for missing actions/submenus.

Design
---
1) Data model expectations (menu.psd1 enhancements)

Each menu entry (existing) is a hashtable; menu item entries should include optional fields:
- `name` (string) - visible text (already present)
- `description` (string) - optional
- `type` or `blockType` (string) - 'menu'|'action'|'static'|'dynamic'
- `menuName` (string) - optional, name of submenu to attach (when item is a submenu link)
- `action` (string) - optional action key to be resolved against runtime action registry
- `actionParameters` (hashtable) - optional, parameters to pass when invoking action
- `includeInDisplayModes` (array) - as before
- `dynamicGenerator` (string) - optional, name of function to call when a dynamic menu needs to be populated

Example item (recommended extension):

@{
  name = 'Export Autopilot Devices'
  description = 'Export Autopilot devices'
  type = 'action'
  action = 'Export-DeviceList'
  actionParameters = @{ deviceType = 'autopilot' }
  includeInDisplayModes = @('full','admin')
}

2) Runtime components

- `Build-MenusFromConfig` function (new)
  - Input: `$menuConfig` (the loaded PSD1 menu section), `$ActionRegistry` (hashtable)
  - Output: `$menus` hashtable mapping menuName -> MenuObject
  - Steps:
    1. Pass 1: foreach menuName in `$menuConfig.Keys` -> `$menus[$menuName] = NewMenu -MenuName $menuName`
    2. Pass 2: foreach menuName -> foreach item in `$menuConfig[$menuName].items`:
       - Normalize fields (`type` vs `blockType`)
       - If `menuName` present on item: resolve `$subMenu = $menus[$item.menuName]`; call `AddMenuItem -Menu $menus[$menuName] -Name $item.name -SubMenu $subMenu` (preserving includeInDisplayModes)
       - Else if `type` == 'action' and `action` present: resolve `$sb = Resolve-ActionScriptBlock -ActionKey $item.action -ActionParameters $item.actionParameters` then `AddMenuItem -Menu $menus[$menuName] -Name $item.name -Action $sb`
       - Else if `type` == 'dynamic' and `dynamicGenerator` present: attach a lazy generator (e.g., an Action that calls the generator when the menu is displayed)
       - Else: Add an inert item or log a warning

- `Resolve-ActionScriptBlock` (new)
  - Input: `ActionKey` (string), `ActionParameters` (hashtable)
  - Behavior: Look up `$ActionRegistry[$ActionKey]`:
    - If found and already a ScriptBlock: return a wrapper ScriptBlock that accepts a context and invokes it with merged parameters.
    - If not found: return a ScriptBlock that indicates "action not implemented" (keeps app robust)

- `Register-MenuAction` (utility)
  - A simple API to populate `$ActionRegistry` during startup after dot-sourcing functions:
    - `Register-MenuAction -Key 'Export-DeviceList' -ScriptBlock { param($ctx) Export-DeviceList -AccessToken $ctx.AccessToken -outputPath $ctx.Out -deviceType $ctx.deviceType }`

3) Action context pattern

- Use a single context parameter when invoking action scriptblocks: a hashtable with keys that actions may expect, e.g. `@{ AccessToken = $accessToken; Out = $outputFile; Settings = $settings }`.
- When generating the final ScriptBlock for an item, wrap the registry entry with a small ScriptBlock that merges `actionParameters` into the passed context.

4) Dynamic menus

- If an entry has `type='dynamic'` and `dynamicGenerator='Get-UserMenuItems'`:
  - Attach an action that, when invoked (menu shown), calls that function to produce items (as array of item hashtables) and then uses the same AddMenuItem logic to add them dynamically.
  - Optionally clear them when exiting the menu to avoid duplication.

Pseudocode (PowerShell-style)
---
# Build menus (call from main after `Initialize-ApplicationConfiguration` and after dot-sourcing functions)

function Build-MenusFromConfig {
    param(
        [hashtable]$MenuConfig,
        [hashtable]$ActionRegistry
    )

    $menus = @{}

    # PASS 1: create menu objects
    foreach ($mn in $MenuConfig.Keys) {
        $menus[$mn] = NewMenu -MenuName $mn
    }

    # PASS 2: attach items
    foreach ($mn in $MenuConfig.Keys) {
        $menuDef = $MenuConfig[$mn]
        foreach ($item in $menuDef.items) {
            # normalize
            $type = if ($item.type) { $item.type } elseif ($item.blockType) { $item.blockType } else { 'action' }

            if ($item.menuName) {
                $sub = $null
                if ($menus.ContainsKey($item.menuName)) { $sub = $menus[$item.menuName] } else { Write-Log -Message "Submenu $($item.menuName) missing" }
                AddMenuItem -Menu $menus[$mn] -Name $item.name -SubMenu $sub -IncludeInDisplayModes $item.includeInDisplayModes
            }
            elseif ($type -eq 'action' -and $item.action) {
                $sb = Resolve-ActionScriptBlock -ActionKey $item.action -ActionParameters $item.actionParameters -ActionRegistry $ActionRegistry
                AddMenuItem -Menu $menus[$mn] -Name $item.name -Action $sb -IncludeInDisplayModes $item.includeInDisplayModes
            }
            elseif ($type -eq 'dynamic' -and $item.dynamicGenerator) {
                # attach lazy loader: when menu shown, call generator to populate
                $lazySb = { param($ctx) & (Get-Command $item.dynamicGenerator).ScriptBlock -ArgumentList $ctx }
                AddMenuItem -Menu $menus[$mn] -Name $item.name -Action $lazySb
            }
            else {
                # fallback: add inert item
                AddMenuItem -Menu $menus[$mn] -Name $item.name
            }
        }
    }

    return $menus
}

# Resolve action scriptblock
function Resolve-ActionScriptBlock {
    param(
        [string]$ActionKey,
        [hashtable]$ActionParameters,
        [hashtable]$ActionRegistry
    )

    if (-not $ActionRegistry.ContainsKey($ActionKey)) {
        Write-Log -LogFile $LogFile -Module 'Resolve-Action' -Message "Unknown action: $ActionKey" -LogLevel Warning
        return { param($ctx) Write-Host "Action $ActionKey not implemented." }
    }

    $baseSb = $ActionRegistry[$ActionKey]

    # return a wrapper that merges actionParameters into ctx and calls baseSb
    return {
        param($ctx)
        $merged = @{}
        if ($ctx) { $merged += $ctx }
        if ($ActionParameters) { $merged += $ActionParameters }
        & $baseSb $merged
    }
}

Action registry population (example):
Register-MenuAction -Key 'Export-DeviceList' -ScriptBlock { param($ctx) Export-DeviceList -AccessToken $ctx.AccessToken -outputPath $ctx.Out -deviceType $ctx.deviceType }
Register-MenuAction -Key 'ExportDeviceAssignmentReport' -ScriptBlock { param($ctx) Export-DeviceAssignmentReport -AccessToken $ctx.AccessToken -outputPath $ctx.Out -reportType $ctx.reportType }

Testing and Rollout
---
1. Add unit tests for `Build-MenusFromConfig` and `Resolve-ActionScriptBlock` using the existing Pester framework. Test cases:
   - Create menus with nested submenus and verify `NewMenu`/`AddMenuItem` calls were made.
   - Items with `action` resolve to expected ScriptBlocks (use Mock on target functions).
   - Dynamic generator gets called only when menu is shown (mock generator and assert called lazily).
   - Missing actions/submenus produce warnings but do not crash.

2. Integration test: run the app in `testMode` and verify main menu appears as before; check a few actions run successfully.

3. Rollout: merge to `code-coverage` branch, smoke test, then merge to `master`.

Backward compatibility and migration notes
---
- If `menu.psd1` items currently lack `action` fields, add them incrementally. The loader supports adding placeholder items until action keys are registered.
- Keep `menu.psd1` friendly to maintainers by documenting new fields at top of `menu.psd1` or in docs.

Estimated effort and risk
---
- Effort: small to medium (1-2 days) depending on number of custom/dynamic menus.
- Risk: low if tests are added and manual testing is performed. Greatest risk is missing action keys—mitigate by adding warnings and default no-op actions.

Appendix: Example `menu.psd1` snippet
---
```
exportMenu = @{
  Title = 'Export Menu'
  Description = 'Choose what you would like to export'
  items = @(
    @{ menuName='deviceReportsMenu'; description='Export various device assignment reports'; name='Export Device Assignment Reports'; blockType='menu' },
    @{ name='Export Autopilot Devices'; description='Export Autopilot devices to CSV'; type='action'; action='Export-DeviceList'; actionParameters = @{ deviceType='autopilot' } },
    @{ name='Export Imported Autopilot Devices'; type='action'; action='Export-DeviceList'; actionParameters = @{ deviceType='imported' } }
  )
}
```

---

If you'd like, I can now implement this loader in a small, isolated patch (create `functions/menuBuilder/Build-MenusFromConfig.ps1`, add `Register-MenuAction` helper, add minimal tests) and run the unit tests. Indicate if you want me to proceed and whether to include the PR branch, or prefer a detailed patch-only preview first.