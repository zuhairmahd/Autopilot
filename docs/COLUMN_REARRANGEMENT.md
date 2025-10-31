# Column Rearrangement Feature

## Overview

The Autopilot Log Viewer now supports rearranging columns with full keyboard accessibility. Users can customize the column order to suit their workflow, and the application will remember their preferences across sessions.

## Features

### 1. Column Reordering
- **Right-click** on any column header to open a context menu
- **Move Left**: Moves the column one position to the left
- **Move Right**: Moves the column one position to the right
- **Reset Column Order**: Restores all columns to their default positions

### 2. Keyboard Accessibility
All column rearrangement features are fully accessible via keyboard:

- **Tab** to navigate between column headers
- **Shift+F10** or **Context Menu key** to open the column context menu
- **Ctrl+Shift+Left Arrow**: Move current column left
- **Ctrl+Shift+Right Arrow**: Move current column right
- **Arrow keys** to navigate menu items
- **Enter** to activate a menu item
- **Escape** to close the menu

### 3. Screen Reader Support
- Screen readers announce column movements: "Timestamp column moved left from position 2 to position 1"
- Row data is read in the new column order automatically
- Only visible columns are included in screen reader announcements
- Column headers include help text explaining keyboard shortcuts

### 4. Persistent Settings
- Column order is automatically saved when changed
- Settings persist across application sessions
- Stored in user's AppData folder: `%APPDATA%\AutopilotLogViewer\ColumnSettings.json`
- Settings include column order, visibility, and width

### 5. Menu Integration
New menu items in the **View** menu:
- **Save Column Layout**: Manually save the current column configuration
- **Reset Column Layout**: Restore default column order and visibility (now working correctly)

## Usage Examples

### Example 1: Reordering with Mouse
1. Open a log file
2. Right-click on the "Level" column header
3. Select "Move Right" from the context menu
4. The Level column moves to the right of Module

### Example 2: Reordering with Keyboard
1. Open a log file
2. Press **Tab** repeatedly until a column header has focus
3. Press **Shift+F10** to open the context menu
4. Use **Arrow keys** to select "Move Left" or "Move Right"
5. Press **Enter** to confirm

### Example 3: Using Keyboard Shortcuts
1. Open a log file
2. Press **Tab** until the desired column header has focus
3. Press **Ctrl+Shift+Left** to move the column left
4. Or press **Ctrl+Shift+Right** to move the column right

### Example 4: Resetting Layout
1. From the **View** menu, select **Reset Column Layout**
2. All columns return to their default order and visibility

## Technical Details

### Architecture
The column rearrangement feature consists of:

1. **ColumnReorderBehavior**: Attached behavior that adds context menus to column headers
2. **ColumnSettings**: Helper class for persisting column configuration
3. **AccessibleDataGrid**: Enhanced to update screen reader announcements when columns are reordered
4. **MainViewModel**: Tracks column order and provides commands

### Settings File Format
```json
[
  {
    "Header": "Timestamp",
    "DisplayIndex": 0,
    "IsVisible": true,
    "Width": 180
  },
  {
    "Header": "Level",
    "DisplayIndex": 1,
    "IsVisible": true,
    "Width": 100
  }
  // ... other columns
]
```

### Accessibility Implementation
- **AutomationProperties.Name**: Each menu item has a descriptive name for screen readers
- **AutomationProperties.HelpText**: Column headers explain available keyboard shortcuts
- **Dynamic updates**: Row accessible names update automatically when columns are reordered
- **Offscreen behavior**: Hidden columns are properly excluded from the accessibility tree

## Default Column Order

| Position | Column | Width |
|----------|--------|-------|
| 0 | Timestamp | 180px |
| 1 | Level | 100px |
| 2 | Module | 200px |
| 3 | Thread | 70px |
| 4 | Context | 150px |
| 5 | Message | Auto (fills remaining space) |

## Benefits

1. **Workflow Optimization**: Users can arrange columns based on their priorities
2. **Accessibility**: Full keyboard access ensures all users can customize their view
3. **Persistence**: Settings are saved automatically, no manual configuration needed
4. **Screen Reader Friendly**: Column changes are announced and data is read in the correct order
5. **Intuitive**: Right-click menus are familiar to most users
6. **Discoverable**: Keyboard shortcuts are displayed in the menu and help text

## Future Enhancements

Potential future improvements could include:
- Drag-and-drop column reordering with mouse
- Column width presets (compact, normal, wide)
- Import/export column layouts
- Multiple saved layouts with quick switching
- Per-file column layout preferences
