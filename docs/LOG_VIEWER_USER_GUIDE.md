# Autopilot Log Viewer - User Guide

## Overview

The **Autopilot Log Viewer** is an accessible, Windows Presentation Foundation (WPF) desktop application designed for post-mortem analysis of Autopilot log files. It provides a powerful yet intuitive interface for filtering, searching, and examining log entries with full screen reader support (JAWS, NVDA).

## Key Features

### Core Functionality
- **Multi-Format Support**: Automatically detects and parses both standard Autopilot log format and CMTrace XML format
- **Real-Time Filtering**: Filter by log level (Error, Warning, Information, Verbose, Debug) and module name
- **Full-Text Search**: Search across message, module, and context fields with live filtering
- **Column Visibility**: Show/hide columns (Timestamp, Level, Module, Thread ID, Context, Message) as needed
- **High Performance**: Virtualizing DataGrid handles large log files efficiently

### Accessibility Features
The Log Viewer is designed with accessibility as a first-class concern:
- **Screen Reader Support**: Full compatibility with JAWS and NVDA screen readers
- **AutomationProperties**: All controls have descriptive names and help text
- **Keyboard Navigation**: Complete keyboard support (Tab, Arrow keys, shortcuts)
- **Focus Management**: Logical focus order throughout the application
- **Menu Shortcuts**: Standard Windows menu mnemonics (Alt+F for File, etc.)

## Getting Started

### Launching the Log Viewer

#### From Autopilot Main Menu
1. Run the Autopilot application (`main.ps1` or `Autopilot.exe`)
2. Navigate to **Main Menu**
3. Select **"View Logs"** from the menu
4. The Log Viewer will open automatically with the current Autopilot log file

#### Standalone Launch
You can also launch the viewer directly:
```powershell
# Launch with a specific log file
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe "C:\Path\To\Autopilot.log"

# Launch without a file (use File > Open to load a log)
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe
```

### Opening a Log File
1. Click **File > Open Log File...** (or press `Ctrl+O`)
2. Navigate to your log file (default: `Logs\Autopilot.log`)
3. Select the file and click **Open**
4. The log entries will be loaded and displayed in the grid

## Using the Log Viewer

### Filter Panel

The filter panel at the top of the window provides three filtering mechanisms:

#### 1. Level Filter
**Location**: Top-left dropdown  
**Options**: All, Error, Warning, Information, Verbose, Debug  
**Purpose**: Show only entries matching the selected log level

**Example Use Cases**:
- Select **"Error"** to quickly identify all errors in the log
- Select **"Warning"** to review potential issues that didn't cause failures
- Select **"Information"** for high-level operational events

#### 2. Module Filter
**Location**: Top-center dropdown  
**Options**: All, [List of unique modules from the log]  
**Purpose**: Show only entries from a specific function or module

**Example Use Cases**:
- Select **"Get-DeviceInfo"** to trace all device information retrieval operations
- Select **"Invoke-GraphRequest"** to examine Graph API calls
- Select **"Write-Log"** to see logging infrastructure operations

#### 3. Search Box
**Location**: Top-right text box  
**Search Scope**: Message, Module, and Context fields  
**Behavior**: Live filtering as you type (case-insensitive)

**Example Use Cases**:
- Search for **"failed"** to find all failure messages
- Search for **"user@domain.com"** to trace operations for a specific user
- Search for **"serialnumber"** to find device-specific entries

#### Clear Filters Button
Click **"Clear Filters"** to reset all filters and show all log entries.

### Column Visibility

Control which columns are displayed using the **View** menu:

**View Menu Options**:
- ✓ Show Timestamp (default: visible)
- ✓ Show Level (default: visible)
- ✓ Show Module (default: visible)
- ✓ Show Thread ID (default: visible)
- ✓ Show Context (default: visible)
- ✓ Show Message (default: visible)

**Example Scenarios**:
- Hide **Thread ID** and **Context** for a simpler view when analyzing single-threaded operations
- Show only **Timestamp**, **Level**, and **Message** for a compact error summary
- Hide **Module** when analyzing operations you know are all from the same function

### DataGrid Navigation

#### Keyboard Navigation
- **Arrow Keys**: Move between cells
- **Tab/Shift+Tab**: Move between controls (filters, search, grid)
- **Home/End**: Jump to first/last row
- **Page Up/Page Down**: Scroll by page
- **Ctrl+C**: Copy selected rows to clipboard

#### Mouse Navigation
- **Click**: Select a row
- **Shift+Click**: Select multiple consecutive rows
- **Ctrl+Click**: Add/remove individual rows from selection
- **Scroll Wheel**: Scroll through entries

#### Screen Reader Navigation
When using JAWS or NVDA:
- Press **Tab** to navigate to the DataGrid
- Use **Arrow Keys** to move between cells
- Press **Ctrl+Home** to read column headers
- Each cell announces its column name and value

### File Menu

**File > Open Log File... (Ctrl+O)**  
Opens a file dialog to select a log file for viewing.

**File > Refresh (F5)**  
Reloads the current log file from disk (useful for viewing updated logs).

**File > Exit**  
Closes the Log Viewer application.

## Log Format Reference

### Standard Autopilot Format
```
2025-01-15 14:23:45.123 [Information] [Get-DeviceInfo] [Thread:5] [Context:SYSTEM] Device query started
```

**Fields**:
- **Timestamp**: `YYYY-MM-DD HH:mm:ss.fff`
- **Level**: Error, Warning, Information, Verbose, Debug
- **Module**: Function or script name
- **Thread**: Thread ID that generated the entry
- **Context**: User or system context
- **Message**: Log message content

### CMTrace XML Format
```xml
<![LOG[Device query started]LOG]!><time="14:23:45.123" date="01-15-2025" component="Get-DeviceInfo" context="SYSTEM" type="1" thread="5" file="">
```

**Type Mapping**:
- `type="1"` → Information
- `type="2"` → Warning
- `type="3"` → Error

The Log Viewer automatically detects which format is used and parses accordingly.

## Troubleshooting

### Log Viewer Won't Launch

**Problem**: Clicking "View Logs" shows an error  
**Solution**: Ensure the LogViewer is built:
```powershell
cd C:\Path\To\Autopilot
.\Build-NativeDlls.ps1 -Configuration Release
```

**Expected Output**: `bin\Release\net9.0-windows\AutopilotLogViewer.exe`

### Log File Not Loading

**Problem**: Log file opens but shows 0 entries  
**Possible Causes**:
1. Log file is empty
2. Log format is unrecognized
3. File is locked by another process

**Solution**:
- Verify the file contains log entries: `Get-Content "Logs\Autopilot.log" | Select-Object -First 5`
- Ensure the file matches one of the supported formats (see Log Format Reference)
- Close any editors or processes that may have the log file open

### Performance Issues

**Problem**: Log Viewer is slow with large files  
**Solution**: The DataGrid uses virtualization for large files (tested with 100,000+ entries). If performance is still poor:
1. Use **Level Filter** to reduce visible entries (e.g., show only Errors)
2. Use **Module Filter** to focus on a specific component
3. Consider splitting very large log files (>10 MB) into smaller chunks

### Screen Reader Not Announcing Elements

**Problem**: JAWS or NVDA not reading controls properly  
**Solutions**:
1. Ensure screen reader is running before launching the Log Viewer
2. Press **Tab** to move focus into the application window
3. Use **Insert+F7** (JAWS) or **NVDA+F7** to verify the application is in focus
4. Restart the screen reader if issues persist

## Accessibility Compliance

The Autopilot Log Viewer follows Microsoft accessibility guidelines:

### WCAG 2.1 Level AA Compliance
- ✓ Keyboard navigation for all functionality
- ✓ Descriptive labels and help text
- ✓ Logical focus order and tab stops
- ✓ High-contrast mode support
- ✓ Resizable text (system DPI scaling)

### Screen Reader Testing
- ✓ Tested with **JAWS 2024** (Freedom Scientific)
- ✓ Tested with **NVDA 2024.1** (NV Access)
- ✓ Tested with **Windows Narrator**

### Known Limitations
- Real-time log tailing not yet implemented (refresh required to see new entries)
- No built-in export functionality (use Windows clipboard via Ctrl+C)
- No dark mode (uses system theme)

## Advanced Use Cases

### Post-Mortem Analysis Workflow

**Scenario**: Autopilot deployment failed, need to identify root cause

1. Launch Log Viewer from Autopilot Main Menu
2. Set **Level Filter** to **"Error"** to identify failure points
3. Note the timestamp and module of the first error
4. Click **Clear Filters** to show all entries
5. Locate the error timestamp in the full log
6. Review preceding **Warning** and **Information** entries for context
7. Use **Module Filter** to trace the problematic module's entire execution
8. Copy relevant log entries (Ctrl+C) and paste into incident report

### Comparing Multiple Logs

**Scenario**: Compare successful vs. failed deployments

1. Open first log file: **File > Open** → `Autopilot_Success.log`
2. Note the module execution order and timing
3. Open second log file: **File > Open** → `Autopilot_Failed.log`
4. Compare Level filters (are there more Errors/Warnings?)
5. Compare Module filters (are different modules executing?)
6. Use Search to find divergence points (e.g., search "failed" in both logs)

### Debugging Specific Components

**Scenario**: Graph API calls are timing out

1. Use **Module Filter** → **"Invoke-GraphRequest"** to isolate Graph operations
2. Examine **Message** column for HTTP status codes (look for 429, 503, 504)
3. Use **Search** → **"retry"** to find retry attempts
4. Review **Timestamp** column to calculate request durations
5. Identify patterns (e.g., timeouts after 30 seconds, specific endpoints failing)

## Keyboard Shortcuts Reference

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

## System Requirements

- **OS**: Windows 10 1809+ or Windows 11
- **.NET Runtime**: .NET 9.0 Runtime (desktop apps)
- **Screen Readers**: JAWS 2020+, NVDA 2020.1+, or Windows Narrator
- **Disk Space**: ~5 MB for application + log file size
- **Memory**: ~50 MB base + ~1 KB per 1,000 log entries

## Support and Feedback

For issues, questions, or feature requests related to the Autopilot Log Viewer:

1. Check the [Known Issues](../KNOWN_ISSUES.md) document
2. Review the [Technical Documentation](../TECHNICAL_DOCUMENTATION.md)
3. Submit an issue on the project repository
4. Contact the Autopilot team

## Version History

### Version 1.0.0 (October 2025)
- Initial release
- Standard and CMTrace log format support
- Level, module, and text search filtering
- Column visibility controls
- Full JAWS and NVDA accessibility
- Integration with Autopilot main menu

---

**Last Updated**: October 30, 2025  
**Document Version**: 1.0.0
