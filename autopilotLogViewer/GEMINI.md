# GEMINI Code Assistant Guide

This document provides a comprehensive guide for the Gemini code assistant to understand and interact with the **Autopilot Log Viewer** project.

## Project Overview

The **Autopilot Log Viewer** is a standalone WPF desktop application built with .NET 9.0 for viewing and analyzing Autopilot log files. It is designed with a strong emphasis on accessibility, providing full support for screen readers like JAWS, NVDA, and Narrator.

The application follows the **Model-View-ViewModel (MVVM)** architecture, ensuring a clean separation of concerns between the UI (View), the application logic (ViewModel), and the data (Model).

### Key Technologies

*   **.NET 9.0**
*   **WPF (Windows Presentation Foundation)**
*   **C#**

### Core Features

*   **Multi-Format Log Parsing:** Automatically detects and parses both standard Autopilot log formats and CMTrace XML format.
*   **Advanced Filtering:** Allows users to filter logs by level (Error, Warning, etc.), module name, and full-text search.
*   **Customizable UI:** Supports showing/hiding columns and reordering them, with settings persisted across sessions.
*   **High Performance:** Utilizes UI virtualization to efficiently handle large log files.
*   **Accessibility:** Built to be fully accessible, complying with WCAG 2.1 Level AA standards.

## Building and Running the Project

The project includes a simple batch script to automate the build process.

### Build Command

To build the project, run the following command from the root directory:

```batch
build.bat
```

This script performs the following actions:

1.  **Checks for .NET 9.0 SDK:** Ensures the required SDK is installed.
2.  **Cleans Artifacts:** Removes previous build outputs from `bin` and `obj` directories.
3.  **Restores NuGet Packages:** Runs `dotnet restore`.
4.  **Builds the Application:** Publishes the UI project in `Release` configuration to the `bin/Release/net9.0-windows` directory.

### Running the Application

After a successful build, the application can be launched from the output directory:

```powershell
# Launch without a file (use File > Open to load a log)
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe

# Launch with a specific log file
.\bin\Release\net9.0-windows\AutopilotLogViewer.exe "C:\Path\To\Autopilot.log"
```

## Development Conventions

### Project Structure

The solution is organized into three main projects under the `src/` directory:

*   `Autopilot.LogCore`: Provides core logging functionalities.
*   `Autopilot.LogViewer.Core`: Contains the core logic for parsing log files, including the `LogParserFactory` and `LogEntry` model.
*   `Autopilot.LogViewer.UI`: The main WPF application project, which includes:
    *   **ViewModels:** `MainViewModel.cs` is the primary ViewModel, containing the application's logic and state.
    *   **Views:** `MainWindow.xaml` defines the main UI of the application.
    *   **Converters:** Value converters for data binding.
    *   **Behaviors:** Attached behaviors for UI elements, such as column reordering.

### Coding Style

*   **C#:** Follows standard C# coding conventions (PascalCase for classes and methods, camelCase for local variables).
*   **XAML:** Uses a clean and readable style, with clear separation of UI elements.
*   **MVVM:** Adheres to the MVVM pattern, with data binding used to connect the View and ViewModel.

### Testing

While there are no dedicated unit test projects in the current structure, testing should be performed manually by:

1.  Building the application.
2.  Running the application with various log files (both standard and CMTrace format).
3.  Verifying that all filtering and UI features work as expected.
4.  Ensuring the application remains responsive with large log files.
