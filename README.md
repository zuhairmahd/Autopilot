# Autopilot Log Viewer

An accessible, standalone WPF desktop application for viewing and analyzing Autopilot log files with full screen reader support (JAWS, NVDA).

## Overview

The **Autopilot Log Viewer** is a high-performance desktop application designed for post-mortem analysis of Autopilot log files. It features advanced filtering capabilities, multi-format support, and comprehensive accessibility features, making it suitable for IT administrators, help desk staff, and developers.

## Key Features

### Core Functionality
- **Multi-Format Support**: Automatically detects and parses both standard Autopilot log format and CMTrace XML format
- **Real-Time Filtering**: Filter by log level (Error, Warning, Information, Verbose, Debug) and module name
- **Full-Text Search**: Search across message, module, and context fields with live filtering
- **Column Visibility**: Show/hide columns (Timestamp, Level, Module, Thread ID, Context, Message) as needed
- **High Performance**: Virtualizing DataGrid handles large log files (100,000+ entries) efficiently

### Accessibility Features
- **Screen Reader Support**: Full compatibility with JAWS and NVDA screen readers
- **Keyboard Navigation**: Complete keyboard support (Tab, Arrow keys, shortcuts)
- **WCAG 2.1 Level AA Compliance**: Meets Microsoft accessibility guidelines
- **AutomationProperties**: All controls have descriptive names and help text

## System Requirements

- **OS**: Windows 10 1809+ or Windows 11
- **.NET Runtime**: .NET 9.0 Runtime (desktop apps)
- **Screen Readers**: JAWS 2020+, NVDA 2020.1+, or Windows Narrator
- **Disk Space**: ~5 MB for application + log file size
- **Memory**: ~50 MB base + ~1 KB per 1,000 log entries

## Getting Started

### Building from Source

#### Prerequisites
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) or higher
- Windows 10 1809+ or Windows 11

#### Build Commands
```batch
# Clone the repository
git clone https://github.com/yourusername/AutopilotLogViewer.git
cd AutopilotLogViewer

# Build the application (Release configuration)
build.bat
```

#### Build Output
After a successful build, you'll find the application at:
```
bin/Release/net9.0-windows/AutopilotLogViewer.exe
```

### Running the Application

#### Standalone Launch
```powershell
# Launch without a file (use File > Open to load a log)
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe

# Launch with a specific log file
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe "C:\Path\To\Autopilot.log"
```

#### From Autopilot Main Application
If you're using the main Autopilot repository:
1. Run the Autopilot application (`main.ps1` or `Autopilot.exe`)
2. Navigate to **Main Menu**
3. Select **"View Logs"** from the menu
4. The Log Viewer will open automatically with the current Autopilot log file

## Usage

### Opening a Log File
1. Click **File > Open Log File...** (or press `Ctrl+O`)
2. Navigate to your log file
3. Select the file and click **Open**

### Filtering Logs
- **Level Filter**: Use the dropdown to show only specific log levels (Error, Warning, etc.)
- **Module Filter**: Filter by specific function or module name
- **Search Box**: Search across Message, Module, and Context fields (case-insensitive)
- **Clear Filters**: Reset all filters to show all entries

### Column Visibility
Use the **View** menu to toggle column visibility:
- Timestamp
- Level
- Module
- Thread ID
- Context
- Message

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open Log File |
| `F5` | Refresh Current Log |
| `Alt+F` | Open File Menu |
| `Alt+V` | Open View Menu |
| `Tab` | Move to next control |
| `Shift+Tab` | Move to previous control |
| `Ctrl+C` | Copy selected rows |
| `Home` | Jump to first row |
| `End` | Jump to last row |
| `Page Up` | Scroll up one page |
| `Page Down` | Scroll down one page |

## Supported Log Formats

### Standard Autopilot Format
```
2025-01-15 14:23:45.123 [Information] [Get-DeviceInfo] [Thread:5] [Context:SYSTEM] Device query started
```

### CMTrace XML Format
```xml
<![LOG[Device query started]LOG]!><time="14:23:45.123" date="01-15-2025" component="Get-DeviceInfo" context="SYSTEM" type="1" thread="5" file="">
```

The Log Viewer automatically detects which format is used and parses accordingly.

## Project Structure

```
AutopilotLogViewer/
├── src/
│   ├── Autopilot.LogCore/              # Logging infrastructure (shared dependency)
│   │   ├── Logger.cs
│   │   └── Autopilot.LogCore.csproj
│   ├── Autopilot.LogViewer.Core/       # Core parsing and filtering logic
│   │   ├── Models/
│   │   │   └── LogEntry.cs
│   │   ├── Parsers/
│   │   │   ├── ILogParser.cs
│   │   │   ├── StandardLogParser.cs
│   │   │   ├── CMTraceLogParser.cs
│   │   │   └── LogParserFactory.cs
│   │   └── Autopilot.LogViewer.Core.csproj
│   └── Autopilot.LogViewer.UI/         # WPF application (MVVM)
│       ├── ViewModels/
│       │   ├── ViewModelBase.cs
│       │   ├── RelayCommand.cs
│       │   └── MainViewModel.cs
│       ├── Views/
│       │   ├── MainWindow.xaml
│       │   └── MainWindow.xaml.cs
│       ├── Converters/
│       │   └── BooleanToVisibilityConverter.cs
│       ├── App.xaml
│       ├── App.xaml.cs
│       └── Autopilot.LogViewer.UI.csproj
├── docs/
│   ├── LOG_VIEWER_USER_GUIDE.md        # Comprehensive user guide
│   ├── LOG_VIEWER_IMPLEMENTATION_SUMMARY.md
│   └── SUBTREE_INTEGRATION.md          # Integration with main Autopilot repo
├── Build-LogViewer.ps1                 # Build script
├── AutopilotLogViewer.sln              # Visual Studio solution
├── README.md                           # This file
├── LICENSE
└── .gitignore
```

## Architecture

### MVVM Pattern
- **Model**: `LogEntry` class with properties for all log fields
- **View**: `MainWindow.xaml` with data binding
- **ViewModel**: `MainViewModel` with INotifyPropertyChanged, commands, filtering logic

### Multi-Format Support
- **Auto-Detection**: `LogParserFactory.DetectParser()` examines first 20 lines
- **Standard Format**: Regex-based parsing of PowerShell log format
- **CMTrace Format**: XML-style log parsing with type-to-level mapping
- **Extensibility**: `ILogParser` interface allows adding new formats

### Performance Optimization
- **Virtualization**: `VirtualizingPanel.IsVirtualizing="True"` on DataGrid
- **Recycling**: `VirtualizingPanel.VirtualizationMode="Recycling"` to reuse UI elements
- **Observable Collections**: `ObservableCollection<LogEntry>` for efficient filtering
- **Live Filtering**: Filters apply on-demand without reloading entire log file

## Development

### Building for Development
```batch
# Release build (default)
build.bat
```

### Project Dependencies
```
Autopilot.LogViewer.UI
  └── Autopilot.LogViewer.Core
      └── Autopilot.LogCore
```

### Target Frameworks
- **Autopilot.LogCore**: net9.0
- **Autopilot.LogViewer.Core**: net9.0
- **Autopilot.LogViewer.UI**: net9.0-windows (WPF)

Note: We removed legacy netstandard2.0 targets to avoid NuGet restore issues in offline environments. All active projects now target .NET 9 for a simpler, faster build.

### Unused code cleaned up
Only three projects are required and included in the solution:

```
Autopilot.LogViewer.UI → Autopilot.LogViewer.Core → Autopilot.LogCore
```

The following folders under `src/` are not used by the application and can be deleted safely if you want a minimal tree:

- `Autopilot.CacheCore/`
- `Autopilot.CollectionCore/`
- `Autopilot.ConfigCore/`
- `Autopilot.CsvCore/`
- `Autopilot.DeviceCore/`
- `Autopilot.GraphCore/`
- `Autopilot.StringCore/`

They were never referenced by the solution and are retained only for archival purposes.

## Integration with Main Autopilot Repository

This repository is designed to be used as a **git subtree** in the main Autopilot repository. See [docs/SUBTREE_INTEGRATION.md](docs/SUBTREE_INTEGRATION.md) for detailed integration instructions.

### Quick Integration Commands
```bash
# In the main Autopilot repository
cd /c/Users/zuhai/code/Autopilot

# Add the LogViewer subtree
git subtree add --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Pull updates from LogViewer repository
git subtree pull --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main --squash

# Push changes to LogViewer repository
git subtree push --prefix=AutopilotLogViewer \
    https://github.com/yourusername/AutopilotLogViewer.git main
```

## Troubleshooting

### Build Issues

**Problem**: `dotnet` command not found  
**Solution**: Install [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)

**Problem**: Build fails with version error  
**Solution**: Ensure .NET 9.0 or higher is installed. Check version with `dotnet --version`

**Problem**: Missing dependencies  
**Solution**: Run `dotnet restore AutopilotLogViewer.sln` before building

### Runtime Issues

**Problem**: Log file not loading  
**Solution**: Verify the file contains log entries and matches one of the supported formats

**Problem**: Performance issues with large files  
**Solution**: Use Level or Module filters to reduce visible entries

**Problem**: Screen reader not announcing elements  
**Solution**: Ensure screen reader is running before launching the application

## Known Issues

### Header navigation after unhiding a column
In some environments (intermittent with certain screen readers), after you unhide the first column (typically "Timestamp"), navigating the header row with arrow keys may behave unexpectedly:

- Focus can move across other column headers
- When moving to the just-unhidden first header, focus may jump to the first data cell in the second row
- Pressing Up returns to the header row but lands on the second header rather than the first

Status:
- Body row navigation and announcement are correct
- UI Automation properties (PositionInSet/SizeOfSet) are set correctly for headers and cells
- We force a structural UIA refresh after column visibility changes, but some screen readers may cache header peers longer than expected

Workarounds:
- Press F5 to trigger a full accessibility refresh in the grid
- Alternatively, briefly toggle a different column’s visibility off and on via the View menu to rebuild header peers

Notes:
- This does not affect reading the cell contents in body rows; only the header focus landing is impacted
- We’re tracking this for a future fix; if you can reliably reproduce with a particular screen reader/version, please open an issue with details

## Documentation

- [User Guide](docs/LOG_VIEWER_USER_GUIDE.md) - Comprehensive end-user documentation
- [Implementation Summary](docs/LOG_VIEWER_IMPLEMENTATION_SUMMARY.md) - Technical implementation details
- [Subtree Integration Guide](docs/SUBTREE_INTEGRATION.md) - Integration with main Autopilot repository

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Follow coding standards**: 4-space indentation, PascalCase for C# classes/methods, camelCase for variables
3. **Test your changes**: Build and run the application with various log files
4. **Update documentation**: If adding features, update the relevant documentation
5. **Submit a pull request** with a clear description of changes

## License

Copyright © 2025 Autopilot Team

This project is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests:

1. Check the [User Guide](docs/LOG_VIEWER_USER_GUIDE.md) for common solutions
2. Review existing [GitHub Issues](https://github.com/yourusername/AutopilotLogViewer/issues)
3. Submit a new issue with detailed reproduction steps

## Version History

### Version 1.0.0 (October 2025)
- Initial release
- Standard and CMTrace log format support
- Level, module, and text search filtering
- Column visibility controls
- Full JAWS and NVDA accessibility
- Standalone build script
- Git subtree integration support

---

**Last Updated**: October 30, 2025  
**Document Version**: 1.0.0
