# Accessible Grid View Accessibility Improvements

This document summarizes the issues discovered during the .NET 9 migration of **Autopilot Log Viewer**, and details the fixes and enhancements that were implemented to restore and expand screen reader support for the log grid.

## Background

The original version of `AccessibleDataGrid` relied on subclassing `DataGridRowAutomationPeer` to re-order the UIA children so screen readers announced cells in the visible column order. When the project was updated to target `.NET 9`, the BCL sealed `DataGridRowAutomationPeer`, which caused build failures and broke the accessibility customizations.

While addressing the regression we also took the opportunity to improve the row announcements, give users control over the narration style, and ensure column-reorder commands expose accurate options.

## Summary of Fixes

### 1. Restore Build Compatibility with .NET 9

- **Problem:** `DataGridRowAutomationPeer` became sealed; inheriting from it raised `CS0509`.
- **Resolution:** Removed the custom peer on .NET 9+. The grid now relies on the stock peer and injects ordering metadata through `AutomationProperties.PositionInSet`/`SizeOfSet`.
- **Impact:** The accessibility logic no longer depends on subclassing sealed types and is future-proof against similar platform changes.
- **Files:**
  - `src/Autopilot.LogViewer.UI/Controls/AccessibleDataGrid.cs`

### 2. Row-Level Automation Metadata

- **Problem:** Screen readers announced columns in their original layout when navigating by row.
- **Resolution:** During `ApplyAutomationPropertiesToRow`, the grid builds a positional map of visible columns. Each cell receives updated `PositionInSet/SizeOfSet`, and the row’s `AutomationProperties.Name` is synthesized from the currently visible display order.
- **Enhancements:** Extracts header/cell text from templated content (e.g., text blocks, checkboxes, custom elements) so narration is meaningful.
- **Files:**
  - `AccessibleDataGrid.ApplyAutomationPropertiesToRow`
  - `AccessibleDataGrid.UpdateRowAutomationName`

### 3. Reading-Mode Preference

- **Problem:** Users asked for row navigation without repeating column headers when using Up/Down arrows.
- **Resolution:** Added `IncludeHeadersInRowAutomationName` dependency property on `AccessibleDataGrid`. The row-name builder uses this flag to include either `“Header: Value”` pairs or values only.
- **UI Integration:**
  - View menu toggle: **View → Include Column Headers in Row Readout**
  - Setting persists via `ColumnSettings.json` alongside column order/visibility.
  - Reset Column Layout returns the preference to the default (off).
- **Files:**
  - `AccessibleDataGrid` (new dependency property)
  - `MainViewModel.IncludeHeadersInRowAutomationName`
  - `Views/MainWindow.xaml` binding to grid/toggle
  - `Helpers/ColumnSettings` (new `ColumnLayoutState`)
  - `Views/MainWindow.xaml.cs` (save handler)

### 4. Column Context Menu Guard Rails

- **Problem:** Column-reordering context menu always offered “Move Left/Right/Beginning/End”, even at the boundaries.
- **Resolution:** On `ContextMenu.Opened`, visible columns are inspected and commands are disabled when the action is not possible.
- **Persistence Update:** `ColumnReorderBehavior.SaveColumnOrder` now writes both column settings and the reading-mode preference whenever the user reorders columns.
- **Files:**
  - `Behaviors/ColumnReorderBehavior.cs`

### 5. Settings Persistence

- **Enhancements:**
  - Added `ColumnLayoutState` wrapper containing `Columns` + `IncludeHeadersInRowAutomationName`.
  - `ColumnSettings.Load` handles legacy JSON (plain array of columns).
  - `ColumnSettings.Save` always writes the new structure.

## User Experience Changes

1. **Row Readout Modes**
   - Default: up/down navigation reads *values only* in display order.
   - Optional: toggle to include column headers for each value.

2. **Column Layout Persistence**
   - Saving layout captures the readout preference.
   - Reset reverts both column layout and readout mode to defaults.

3. **Context Menu Usability**
   - Disabled move commands when already at grid edges prevents no-op actions.

## Testing Notes

Microsoft’s WPF build chain requires Windows; builds cannot execute inside WSL. Run the following from a Windows command prompt or PowerShell:

```powershell
dotnet build AutopilotLogViewer.sln -c Release
```

After building, verify with a screen reader (NVDA, Narrator, JAWS):

1. Reorder columns in the grid.
2. Navigate left/right (cell) and up/down (row) and confirm the spoken order matches the visible layout.
3. Toggle **Include Column Headers in Row Readout** and confirm announcements change accordingly.
4. Save layout, restart the app, and verify that the preference and column order persist. Use **Reset Column Layout** to ensure defaults are restored.

## Key Design Considerations

- **Accessibility Consistency:** All automation updates occur on realized rows/cells, ensuring virtualized rows receive the correct metadata as they materialize.
- **State Persistence:** Preference is part of the existing column settings file so we avoid proliferating config files and maintain backward compatibility.
- **Non-intrusive UI:** Preference placed under the View menu; no modal dialogs or dialogs needed.
- **Fail-safe Defaults:** Resetting layout guarantees a known-good base state in case users misconfigure columns or toggles.

## Future Opportunities

- Investigate `AutomationPeer.RaiseNotificationEvent` for richer announcements instead of relying on `Debug.WriteLine`.
- Add in-app feedback when the row readout mode changes (toast/status bar message).
- Provide per-column overrides (e.g., always include headers for specific columns).

---

These changes collectively restore the log grid’s accessibility for screen reader users and provide additional flexibility to tailor narration to individual preferences.
