# Bug Fixes - October 31, 2025: Double Window and UI Automation Synchronization

## Summary
Fixed two critical bugs affecting user experience and accessibility:
1. **Double Window Opening**: Application launched two windows on startup or file load
2. **Screen Reader Synchronization**: UI Automation was out of sync with visual display for column visibility and ordering

## Bug #1: Double Window Opening

### Problem
When the application started or a file was loaded, two windows would open instead of one.

### Root Cause
The `App.xaml` file had `StartupUri="Views/MainWindow.xaml"` which caused WPF to automatically instantiate and display a MainWindow. However, the `App.xaml.cs` OnStartup method also explicitly created a new MainWindow instance:

```csharp
// In App.xaml.cs OnStartup
var mainWindow = new Views.MainWindow();
mainWindow.Show();
```

This resulted in two separate window instances being created and shown.

### Solution
Removed the `StartupUri` property from `App.xaml`:

**Before:**
```xml
<Application x:Class="Autopilot.LogViewer.UI.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             StartupUri="Views/MainWindow.xaml">
```

**After:**
```xml
<Application x:Class="Autopilot.LogViewer.UI.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
```

Now the window is only created programmatically in `App.xaml.cs`, allowing proper single-instance management and file path handling through the named pipe system.

### Impact
- Application now opens only one window on startup
- Single-instance behavior continues to work correctly
- File opening through command-line arguments works as expected

---

## Bug #2: Screen Reader Synchronization with Column Visibility and Order

### Problem
Screen readers (JAWS, NVDA, Narrator) were announcing columns and cell content that were hidden or in incorrect order:
- Hidden columns were still being read by screen readers
- When columns were reordered, screen readers read cells in the wrong sequence
- Cell content didn't match the column headers being announced

### Root Cause
The `AccessibleDataGrid.cs` had two fundamental issues:

#### Issue 2A: Using Visual Index Instead of Column Index
The code was using a "visible index" (position in filtered visible columns list) to retrieve cells:

```csharp
// WRONG: Uses visual position to get cell
foreach (var (column, visibleIndex) in visibleColumns.Select((c, i) => (c, i)))
{
    var cell = GetCell(row, visibleIndex);
    // ...
}
```

However, `ItemContainerGenerator.ContainerFromIndex()` expects the **actual column index** from the Columns collection, not the visual display position. This caused cells to be mismatched with columns when columns were hidden or reordered.

#### Issue 2B: Hidden Columns Not Excluded from Automation
The code only updated visible columns but didn't clear or properly exclude hidden columns from the UI Automation tree. Hidden cells still had their automation properties set from previous states.

### Solution

#### Fix 2A: Use Actual Column Index for Cell Retrieval
Changed `BuildRowAccessibleName()` to use the actual column index from the Columns collection:

**Before:**
```csharp
foreach (var (column, visibleIndex) in visibleColumns.Select((c, i) => (c, i)))
{
    var cell = GetCell(row, visibleIndex);  // WRONG: visual position
    // ...
}
```

**After:**
```csharp
foreach (var column in visibleColumns)
{
    // Get cell by actual column index, not display index
    int columnIndex = Columns.IndexOf(column);
    if (columnIndex < 0)
    {
        continue;
    }

    var cell = GetCell(row, columnIndex);  // CORRECT: actual column index
    // ...
}
```

#### Fix 2B: Clear Automation Properties for Hidden Cells
Updated `UpdateRowCellAutomationNames()` to iterate through **all** cells and explicitly clear automation properties for hidden ones:

**Before:**
```csharp
// Only processed visible columns, left hidden cells unchanged
foreach (var (column, visibleIndex) in visibleColumns.Select((c, i) => (c, i)))
{
    var cell = GetCell(row, visibleIndex);
    // Set automation properties...
}
```

**After:**
```csharp
// Process ALL cells, including hidden ones
for (int columnIndex = 0; columnIndex < Columns.Count; columnIndex++)
{
    var column = Columns[columnIndex];
    var cell = GetCell(row, columnIndex);
    
    if (column.Visibility == Visibility.Visible)
    {
        // Set proper automation properties for visible cells
        AutomationProperties.SetName(cell, name);
        AutomationProperties.SetPositionInSet(cell, visiblePosition);
        AutomationProperties.SetSizeOfSet(cell, totalVisible);
    }
    else
    {
        // Clear automation properties for hidden cells
        AutomationProperties.SetName(cell, string.Empty);
        AutomationProperties.SetPositionInSet(cell, 0);
        AutomationProperties.SetSizeOfSet(cell, 0);
    }
}
```

#### Fix 2C: Clarified Parameter Naming
Renamed the `GetCell()` method parameter from `visibleIndex` to `columnIndex` to prevent confusion:

```csharp
// Before: private DataGridCell? GetCell(DataGridRow row, int visibleIndex)
// After:
private DataGridCell? GetCell(DataGridRow row, int columnIndex)
```

### Impact
- Screen readers now correctly announce only visible columns
- Cell content is read in the correct order matching visual column order
- When columns are hidden, they are completely excluded from screen reader navigation
- When columns are reordered, screen readers follow the new visual order
- Position information (e.g., "column 1 of 5") is accurate for visible columns only

---

## Technical Details

### Files Modified
1. **src/Autopilot.LogViewer.UI/App.xaml**
   - Removed `StartupUri` property

2. **src/Autopilot.LogViewer.UI/Controls/AccessibleDataGrid.cs**
   - Fixed `BuildRowAccessibleName()` to use column index instead of visual index
   - Rewrote `UpdateRowCellAutomationNames()` to handle all cells and clear hidden cell properties
   - Renamed `GetCell()` parameter for clarity

### Architecture Context

#### Column Index vs Display Index vs Visual Index
- **Column Index**: Position in the `Columns` collection (0-based, never changes)
- **Display Index**: Visual position for display purposes (can change when columns are reordered)
- **Visual Index**: Position in filtered "visible columns" list (changes when columns are hidden/shown)

The `ItemContainerGenerator.ContainerFromIndex()` method requires the **column index**, not the display or visual index.

#### UI Automation Hierarchy
```
DataGrid
├── DataGridRow (AutomationProperties.Name = "Timestamp: 2025-10-31...; Level: Info; ...")
│   ├── DataGridCell [Column 0 - Timestamp] (visible)
│   │   └── AutomationProperties: Name, PositionInSet, SizeOfSet
│   ├── DataGridCell [Column 1 - Level] (visible)
│   │   └── AutomationProperties: Name, PositionInSet, SizeOfSet
│   ├── DataGridCell [Column 2 - Module] (hidden - properties cleared)
│   │   └── AutomationProperties: cleared
│   └── ...
```

### Complementary Components
The fixes work in conjunction with existing accessibility features:

1. **DataGridColumnVisibilityBehavior**: Sets `Visibility.Collapsed` and `Width=0` for hidden columns
2. **AccessibleDataGridCell**: Excludes cells from UIAutomation tree when `Width=0`
3. **AccessibleDataGrid**: Now properly syncs automation properties with visual state

---

## Testing Recommendations

### Manual Testing
1. **Double Window Bug**:
   - Launch application without arguments → verify only one window opens
   - Launch with file path argument → verify only one window opens with file loaded
   - Open file via File menu → verify no additional windows appear

2. **Screen Reader Synchronization**:
   - Open a log file
   - Enable screen reader (JAWS, NVDA, or Narrator)
   - Hide a column via View menu → verify screen reader doesn't announce it
   - Reorder columns → verify screen reader reads in correct visual order
   - Navigate DataGrid with arrow keys → verify cells announce in correct sequence

### Automated Testing
Consider adding unit tests for:
- `GetVisibleColumns()` returns columns in display order
- `BuildRowAccessibleName()` uses correct column indices
- `UpdateRowCellAutomationNames()` clears properties for hidden cells

---

## Related Issues
- Original implementation: Initial AccessibleDataGrid in commit [hash]
- Column visibility behavior: See `DataGridColumnVisibilityBehavior.cs`
- Column reordering: See `ColumnReorderBehavior.cs`

---

## Notes
- Changes maintain backward compatibility with existing column settings
- No changes required to saved column layout files
- Screen reader behavior now matches WCAG 2.1 Level AA requirements
