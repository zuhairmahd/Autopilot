# AutopilotLogViewer - AI Coding Agent Instructions

## Project Overview

This is a **standalone WPF desktop application** for viewing Autopilot log files with full accessibility support (JAWS, NVDA, Narrator). The app parses two log formats (Standard PowerShell and CMTrace XML) and provides advanced filtering with a clean MVVM architecture.

**Key Fact**: This repository is designed to be integrated as a **git subtree** into the main Autopilot project but must remain fully buildable and testable standalone.

## Architecture

### Three-Layer Structure
```
Autopilot.LogViewer.UI (WPF, net9.0-windows)
  └── Autopilot.LogViewer.Core (Parsers, Models, net9.0)
      └── Autopilot.LogCore (Logging infrastructure, net9.0)
```

**Critical**: Only these three projects exist in `AutopilotLogViewer.sln`. Other folders in `src/` are unused legacy code and should be ignored.

### MVVM Pattern
- **ViewModel**: `MainViewModel` owns all filtering logic, uses `ObservableCollection<LogEntry>` for live updates
- **Model**: `LogEntry` (immutable properties: Timestamp, Level, Module, ThreadId, Context, Message)
- **View**: `MainWindow.xaml` with WPF data binding, virtualized DataGrid for performance
- **Commands**: `RelayCommand` implementation for ICommand pattern

### Multi-Format Parser System
- **Auto-Detection**: `LogParserFactory.DetectParser()` reads first 20 lines to identify format
- **Extensibility**: Implement `ILogParser` interface with `CanParse()` and `ParseFile()` methods
- **Standard Format**: Regex-based parsing: `YYYY-MM-DD HH:mm:ss.fff [Level] [Module] [Thread:X] [Context] Message`
- **CMTrace Format**: XML-style tags: `<![LOG[message]LOG]!><time="..." date="..." component="..." type="1">`

## Build & Development

### Build Commands
```bash
# Always use the standalone build script
Build.bat

# Output: bin/Release/net9.0-windows/AutopilotLogViewer.exe
```

### Testing
```bash
# Launch without file (use File > Open)
bin/Release/net9.0-windows/AutopilotLogViewer.exe

# Launch with specific log file
bin/Release/net9.0-windows/AutopilotLogViewer.exe "C:\Path\To\Autopilot.log"
```

## Code Conventions

### Naming & Style
- **Classes/Methods**: PascalCase (`MainViewModel`, `LoadLogFile`)
- **Private fields**: `_camelCase` (`_searchText`, `_filteredEntries`)
- **Properties**: PascalCase (`SearchText`, `FilteredEntries`)
- **Indentation**: 4 spaces (not tabs)
- **Braces**: K&R style (opening brace on same line for types, next line for methods)

### XML Documentation
All public classes, methods, and properties **must** have `<summary>` tags. Example from codebase:
```csharp
/// <summary>
/// Detects the appropriate parser for a log file.
/// </summary>
/// <param name="filePath">The path to the log file.</param>
/// <returns>An appropriate parser, or null if no parser can handle the format.</returns>
public static ILogParser? DetectParser(string filePath)
```

### Accessibility Requirements
**Every UI control** must have:
- `AutomationProperties.Name` - Descriptive label
- `AutomationProperties.HelpText` - Usage instructions (optional for simple controls)
- `Focusable="true"` for interactive elements

Example from `MainWindow.xaml`:
```xml
<MenuItem Header="_Open Log File..."
          Command="{Binding OpenFileCommand}"
          AutomationProperties.Name="Open Log File"
          AutomationProperties.HelpText="Opens a log file for viewing"/>
```

## Critical Patterns

### 1. ObservableCollection Filtering (NOT LINQ-to-binding)
The app applies filters by **creating new ObservableCollection instances**, not by using CollectionViewSource:

```csharp
private void ApplyFilters()
{
    var filtered = _allEntries.AsEnumerable();
    
    // Apply filters as LINQ
    if (SelectedLevel != "All")
        filtered = filtered.Where(e => e.Level.Equals(SelectedLevel, ...));
    
    // Create NEW collection (triggers UI update)
    FilteredEntries = new ObservableCollection<LogEntry>(filtered);
}
```

### 2. Column Reordering via Attached Behavior
Column rearrangement uses `ColumnReorderBehavior` attached property with context menus:
- Right-click header or Shift+F10 for menu
- Ctrl+Shift+Left/Right for keyboard reordering
- Saves to `ColumnSettings` (stored in user's AppData)

### 3. Settings Persistence
Use `Helpers.ColumnSettings` class for all user preferences:
```csharp
// Load settings
var settings = ColumnSettings.Load();

// Save settings
ColumnSettings.Save(settingsList);

// Recent files
var files = ColumnSettings.LoadRecentFiles();
ColumnSettings.SaveRecentFiles(fileList);
```

Settings stored in: `%AppData%\AutopilotLogViewer\settings.json`

### 4. Performance - Virtualization
Large log files (100K+ entries) use:
```xml
<DataGrid VirtualizingPanel.IsVirtualizing="True"
          VirtualizingPanel.VirtualizationMode="Recycling"
          EnableRowVirtualization="True">
```

## Common Tasks

### Adding a New Log Format
1. Create class implementing `ILogParser` in `src/Autopilot.LogViewer.Core/Parsers/`
2. Implement `CanParse(IEnumerable<string> sampleLines)` - return true if format matches
3. Implement `ParseFile(string filePath)` - yield return `LogEntry` objects
4. Add to `LogParserFactory.AvailableParsers` array

### Adding a New Filter
1. Add private field to `MainViewModel`: `private string _myFilter = "All";`
2. Add public property with `SetProperty()` and `ApplyFilters()` call
3. Update `ApplyFilters()` method with new LINQ Where clause
4. Add UI control in `MainWindow.xaml` with data binding

### Adding a Column
1. Add property to `LogEntry` model
2. Update parser(s) to populate new property
3. Add `DataGridTextColumn` to `MainWindow.xaml`:
```xml
<DataGridTextColumn Header="NewColumn"
                    Binding="{Binding NewProperty}"
                    AutomationProperties.Name="New Column Header"/>
```
4. Add visibility property to `MainViewModel` (e.g., `ShowNewColumn`)
5. Add to `ColumnSettings` defaults with display index

## Integration with Main Autopilot Repo

This repo lives as a **git subtree** at `AutopilotLogViewer/` in the main Autopilot repository.

### Pull Updates from Standalone Repo
```bash
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash
```

### Push Changes from Main Repo
```bash
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

**Important**: All changes must work in both contexts (standalone and subtree).

## What NOT to Do

- ❌ Don't add netstandard2.0 targets (removed to avoid NuGet restore issues)
- ❌ Don't reference unused projects (CacheCore, DeviceCore, etc. are legacy)
- ❌ Don't use CollectionViewSource for filtering (breaks virtualization performance)
- ❌ Don't hardcode file paths (use OpenFileDialog or command-line args)
- ❌ Don't add UI elements without `AutomationProperties` (fails accessibility)
- ❌ Don't call `dotnet build` directly (always use `Build-LogViewer.ps1`)

## Documentation

- `README.md` - User guide, features, system requirements
- `docs/LOG_VIEWER_USER_GUIDE.md` - Comprehensive end-user documentation
- `docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md` - Technical implementation details
- `docs/SUBTREE_INTEGRATION.md` - Git subtree integration guide
- `docs/COLUMN_REARRANGEMENT.md` - Accessibility features for column reordering

## Key Files Reference

- **Entry Point**: `src/Autopilot.LogViewer.UI/App.xaml.cs`
- **Main View**: `src/Autopilot.LogViewer.UI/Views/MainWindow.xaml[.cs]`
- **Core Logic**: `src/Autopilot.LogViewer.UI/ViewModels/MainViewModel.cs`
- **Parser Factory**: `src/Autopilot.LogViewer.Core/Parsers/LogParserFactory.cs`
- **Data Model**: `src/Autopilot.LogViewer.Core/Models/LogEntry.cs`
- **Build Script**: `Build-LogViewer.ps1`
- **Solution**: `AutopilotLogViewer.sln` (only 3 projects)
