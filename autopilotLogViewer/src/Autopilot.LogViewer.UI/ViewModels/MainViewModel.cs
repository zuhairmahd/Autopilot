using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows.Input;
using Autopilot.LogViewer.Core.Models;
using Autopilot.LogViewer.Core.Parsers;
using Autopilot.LogViewer.UI.Helpers;

namespace Autopilot.LogViewer.UI.ViewModels
{
    /// <summary>
    /// Main ViewModel for the log viewer application.
    /// </summary>
    public class MainViewModel : ViewModelBase
    {
        private string _filePath = string.Empty;
        private string _searchText = string.Empty;
        private bool _isLoading;
        private string _statusText = "Ready";
        private ObservableCollection<LogEntry> _allEntries = new();
        private ObservableCollection<LogEntry> _filteredEntries = new();
        private readonly ObservableCollection<FilterOptionViewModel> _levelFilterOptions;
        private ObservableCollection<FilterOptionViewModel> _moduleFilterOptions = new();
        private bool _suppressFilterNotifications;

        // Column visibility
        private bool _showTimestamp = true;
        private bool _showLevel = true;
        private bool _showModule = true;
        private bool _showThreadId = true;
        private bool _showContext = true;
        private bool _showMessage = true;
        private bool _includeHeadersInRowAutomationName;

        // Column order settings
        private Dictionary<string, int> _columnDisplayIndices = new();

        // Recent files
        private const int MaxRecentFiles = 10;
        private ObservableCollection<string> _recentFiles = new();

        /// <summary>
        /// Initializes a new instance of the MainViewModel class.
        /// </summary>
        public MainViewModel()
        {
            // Initialize commands
            OpenFileCommand = new RelayCommand(_ => OpenFile());
            RefreshCommand = new RelayCommand(_ => RefreshLog(), _ => !string.IsNullOrEmpty(FilePath));
            ClearFiltersCommand = new RelayCommand(_ => ClearFilters());
            SaveColumnLayoutCommand = new RelayCommand(_ => SaveColumnLayout());
            ResetColumnLayoutCommand = new RelayCommand(_ => ResetColumnLayout());

            // Load saved column settings
            LoadColumnSettings();

            // Load recent files
            LoadRecentFiles();

            _levelFilterOptions = CreateDefaultLevelFilters();
            ModuleFilterOptions = new ObservableCollection<FilterOptionViewModel>();
    }

        #region Properties

        /// <summary>
        /// Gets or sets the path to the log file.
        /// </summary>
        public string FilePath
        {
            get => _filePath;
            set
            {
                if (SetProperty(ref _filePath, value))
                {
                    LoadLogFile();
                }
            }
        }

        /// <summary>
        /// Gets or sets the search text.
        /// </summary>
        public string SearchText
        {
            get => _searchText;
            set
            {
                if (SetProperty(ref _searchText, value))
                {
                    ApplyFilters();
                }
            }
        }

        /// <summary>
        /// Gets or sets a value indicating whether the log is being loaded.
        /// </summary>
        public bool IsLoading
        {
            get => _isLoading;
            set => SetProperty(ref _isLoading, value);
        }

        /// <summary>
        /// Gets or sets the status text.
        /// </summary>
        public string StatusText
        {
            get => _statusText;
            set => SetProperty(ref _statusText, value);
        }

        /// <summary>
        /// Gets the filtered log entries.
        /// </summary>
        public ObservableCollection<LogEntry> FilteredEntries
        {
            get => _filteredEntries;
            private set => SetProperty(ref _filteredEntries, value);
        }

        /// <summary>
        /// Gets the available log level filter options.
        /// </summary>
        public ObservableCollection<FilterOptionViewModel> LevelFilterOptions => _levelFilterOptions;

        /// <summary>
        /// Gets the available module filter options.
        /// </summary>
        public ObservableCollection<FilterOptionViewModel> ModuleFilterOptions
        {
            get => _moduleFilterOptions;
            private set => SetProperty(ref _moduleFilterOptions, value);
        }

        /// <summary>
        /// Gets or sets a value indicating whether all log levels are included.
        /// </summary>
        public bool AreAllLevelsSelected
        {
            get => _levelFilterOptions.Count == 0 || _levelFilterOptions.All(option => option.IsSelected);
            set => SetAllLevelFilters(value);
        }

        /// <summary>
        /// Gets or sets a value indicating whether all modules are included.
        /// </summary>
        public bool AreAllModulesSelected
        {
            get => _moduleFilterOptions.Count == 0 || _moduleFilterOptions.All(option => option.IsSelected);
            set => SetAllModuleFilters(value);
        }

        /// <summary>
        /// Gets a human-readable summary of the current level filters.
        /// </summary>
        public string LevelFilterSummary => BuildFilterSummary(_levelFilterOptions, "levels");

        /// <summary>
        /// Gets a human-readable summary of the current module filters.
        /// </summary>
        public string ModuleFilterSummary => BuildFilterSummary(_moduleFilterOptions, "modules");

        #endregion

        #region Column Visibility Properties

        public bool ShowTimestamp
        {
            get => _showTimestamp;
            set => SetProperty(ref _showTimestamp, value);
        }

        public bool ShowLevel
        {
            get => _showLevel;
            set => SetProperty(ref _showLevel, value);
        }

        public bool ShowModule
        {
            get => _showModule;
            set => SetProperty(ref _showModule, value);
        }

        public bool ShowThreadId
        {
            get => _showThreadId;
            set => SetProperty(ref _showThreadId, value);
        }

        public bool ShowContext
        {
            get => _showContext;
            set => SetProperty(ref _showContext, value);
        }

        public bool ShowMessage
        {
            get => _showMessage;
            set => SetProperty(ref _showMessage, value);
        }

        public bool IncludeHeadersInRowAutomationName
        {
            get => _includeHeadersInRowAutomationName;
            set => SetProperty(ref _includeHeadersInRowAutomationName, value);
        }

        #endregion

        #region Commands

        public ICommand OpenFileCommand { get; }
        public ICommand RefreshCommand { get; }
        public ICommand ClearFiltersCommand { get; }
        public ICommand SaveColumnLayoutCommand { get; }
        public ICommand ResetColumnLayoutCommand { get; }
        public ICommand OpenRecentFileCommand => new RelayCommand(param => OpenRecentFile(param as string));

        #endregion

        #region Recent Files

        /// <summary>
        /// Gets the list of recently opened files.
        /// </summary>
        public ObservableCollection<string> RecentFiles
        {
            get => _recentFiles;
            private set => SetProperty(ref _recentFiles, value);
        }

        #endregion

        #region Public Properties for Column Order

        /// <summary>
        /// Gets the display index for a column by header name.
        /// </summary>
        public int GetColumnDisplayIndex(string header)
        {
            return _columnDisplayIndices.TryGetValue(header, out var index) ? index : -1;
        }

        #endregion

        #region Methods

        private void OpenFile()
        {
            var dialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "Log Files (*.log)|*.log|All Files (*.*)|*.*",
                Title = "Open Autopilot Log File"
            };

            if (dialog.ShowDialog() == true)
            {
                FilePath = dialog.FileName;
                AddToRecentFiles(dialog.FileName);
            }
        }

        private void OpenRecentFile(string? filePath)
        {
            if (!string.IsNullOrEmpty(filePath) && File.Exists(filePath))
            {
                FilePath = filePath;
                AddToRecentFiles(filePath);
            }
            else if (!string.IsNullOrEmpty(filePath))
            {
                StatusText = $"File not found: {filePath}";
                // Remove from recent files
                RecentFiles.Remove(filePath);
                SaveRecentFilesInternal();
            }
        }

        private void AddToRecentFiles(string filePath)
        {
            // Remove if already exists
            if (RecentFiles.Contains(filePath))
            {
                RecentFiles.Remove(filePath);
            }

            // Add to top
            RecentFiles.Insert(0, filePath);

            // Limit to MaxRecentFiles
            while (RecentFiles.Count > MaxRecentFiles)
            {
                RecentFiles.RemoveAt(RecentFiles.Count - 1);
            }

            SaveRecentFilesInternal();
        }

        private void LoadRecentFiles()
        {
            var files = ColumnSettings.LoadRecentFiles();
            RecentFiles = new ObservableCollection<string>(files.Take(MaxRecentFiles));
        }

        private void SaveRecentFilesInternal()
        {
            ColumnSettings.SaveRecentFiles(RecentFiles.ToList());
        }

        private void LoadLogFile()
        {
            if (string.IsNullOrEmpty(FilePath) || !File.Exists(FilePath))
            {
                StatusText = "File not found";
                return;
            }

            IsLoading = true;
            StatusText = "Loading log file...";

            try
            {
                // Detect parser
                var parser = LogParserFactory.DetectParser(FilePath);
                if (parser == null)
                {
                    StatusText = "Unable to detect log format";
                    IsLoading = false;
                    return;
                }

                // Parse file
                var entries = parser.ParseFile(FilePath).ToList();
                _allEntries = new ObservableCollection<LogEntry>(entries);

                EnsureLevelOptions(entries);
                InitializeModuleFilters(entries);

                // Apply filters
                ApplyFilters();

                StatusText = $"Loaded {entries.Count} log entries";
            }
            catch (Exception ex)
            {
                StatusText = $"Error loading file: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        private void RefreshLog()
        {
            LoadLogFile();
        }

        private void ApplyFilters()
        {
            if (_allEntries == null || _allEntries.Count == 0)
            {
                FilteredEntries = new ObservableCollection<LogEntry>();
                return;
            }

            IEnumerable<LogEntry> filtered = _allEntries;

            // Apply level filter
            if (_levelFilterOptions.Count > 0)
            {
                var selectedLevels = _levelFilterOptions
                    .Where(option => option.IsSelected)
                    .Select(option => option.Name)
                    .ToList();

                if (selectedLevels.Count == 0)
                {
                    filtered = Enumerable.Empty<LogEntry>();
                }
                else if (selectedLevels.Count < _levelFilterOptions.Count)
                {
                    var levelSet = new HashSet<string>(selectedLevels, StringComparer.OrdinalIgnoreCase);
                    filtered = filtered.Where(entry => levelSet.Contains(entry.Level));
                }
            }

            // Apply module filter
            if (_moduleFilterOptions.Count > 0)
            {
                var selectedModules = _moduleFilterOptions
                    .Where(option => option.IsSelected)
                    .Select(option => option.Name)
                    .ToList();

                if (selectedModules.Count == 0)
                {
                    filtered = Enumerable.Empty<LogEntry>();
                }
                else if (selectedModules.Count < _moduleFilterOptions.Count)
                {
                    var moduleSet = new HashSet<string>(selectedModules, StringComparer.OrdinalIgnoreCase);
                    filtered = filtered.Where(entry => moduleSet.Contains(entry.Module));
                }
            }

            // Apply search filter
            if (!string.IsNullOrWhiteSpace(SearchText))
            {
                var searchLower = SearchText.ToLowerInvariant();
                filtered = filtered.Where(entry =>
                    entry.Message.ToLowerInvariant().Contains(searchLower) ||
                    entry.Module.ToLowerInvariant().Contains(searchLower) ||
                    entry.Context.ToLowerInvariant().Contains(searchLower));
            }

            var results = filtered.ToList();
            FilteredEntries = new ObservableCollection<LogEntry>(results);
            StatusText = $"Showing {FilteredEntries.Count} of {_allEntries.Count} entries";
        }

        private void ClearFilters()
        {
            SearchText = string.Empty;
            AreAllLevelsSelected = true;
            AreAllModulesSelected = true;
        }

        private ObservableCollection<FilterOptionViewModel> CreateDefaultLevelFilters()
        {
            var defaultLevels = new[]
            {
                "Error",
                "Warning",
                "Information",
                "Verbose",
                "Debug"
            };

            var options = new ObservableCollection<FilterOptionViewModel>();
            foreach (var level in defaultLevels)
            {
                options.Add(CreateLevelFilterOption(level));
            }

            return options;
        }

        private FilterOptionViewModel CreateLevelFilterOption(string level, bool isSelected = true)
        {
            return new FilterOptionViewModel(
                level,
                isSelected: isSelected,
                selectionChanged: _ => OnLevelFilterSelectionChanged(),
                automationName: $"{level} level filter",
                helpText: $"Include log entries with level {level}");
        }

        private void EnsureLevelOptions(IEnumerable<LogEntry> entries)
        {
            var existing = new HashSet<string>(_levelFilterOptions.Select(option => option.Name), StringComparer.OrdinalIgnoreCase);
            var added = false;
            var hadExisting = _levelFilterOptions.Count > 0;
            var previouslySelectedLevels = new HashSet<string>(
                _levelFilterOptions.Where(option => option.IsSelected).Select(option => option.Name),
                StringComparer.OrdinalIgnoreCase);
            var allPreviouslySelected = hadExisting && previouslySelectedLevels.Count == _levelFilterOptions.Count;
            var nonePreviouslySelected = hadExisting && previouslySelectedLevels.Count == 0;

            foreach (var level in entries
                         .Select(entry => entry.Level)
                         .Where(level => !string.IsNullOrWhiteSpace(level))
                         .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (existing.Add(level))
                {
                    var shouldSelect =
                        !hadExisting ||
                        allPreviouslySelected ||
                        previouslySelectedLevels.Contains(level);

                    if (nonePreviouslySelected)
                    {
                        shouldSelect = false;
                    }

                    _levelFilterOptions.Add(CreateLevelFilterOption(level, shouldSelect));
                    added = true;
                }
            }

            if (added)
            {
                OnPropertyChanged(nameof(AreAllLevelsSelected));
                OnPropertyChanged(nameof(LevelFilterSummary));
            }
        }

        private void InitializeModuleFilters(IEnumerable<LogEntry> entries)
        {
            var hadExistingFilters = _moduleFilterOptions.Count > 0;
            var previouslySelectedModules = new HashSet<string>(
                _moduleFilterOptions.Where(option => option.IsSelected).Select(option => option.Name),
                StringComparer.OrdinalIgnoreCase);
            var allPreviouslySelected = hadExistingFilters && previouslySelectedModules.Count == _moduleFilterOptions.Count;
            var nonePreviouslySelected = hadExistingFilters && previouslySelectedModules.Count == 0;

            var modules = entries
                .Select(entry => entry.Module)
                .Where(module => !string.IsNullOrWhiteSpace(module))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(module => module, StringComparer.OrdinalIgnoreCase)
                .Select(module =>
                {
                    var shouldSelect =
                        !hadExistingFilters ||
                        allPreviouslySelected ||
                        previouslySelectedModules.Contains(module);

                    if (nonePreviouslySelected)
                    {
                        shouldSelect = false;
                    }

                    return new FilterOptionViewModel(
                        module,
                        isSelected: shouldSelect,
                        selectionChanged: _ => OnModuleFilterSelectionChanged(),
                        automationName: $"{module} module filter",
                        helpText: $"Include log entries from module {module}");
                })
                .ToList();

            ModuleFilterOptions = new ObservableCollection<FilterOptionViewModel>(modules);
            OnPropertyChanged(nameof(AreAllModulesSelected));
            OnPropertyChanged(nameof(ModuleFilterSummary));
        }

        private void OnLevelFilterSelectionChanged()
        {
            if (_suppressFilterNotifications)
            {
                return;
            }

            OnPropertyChanged(nameof(AreAllLevelsSelected));
            OnPropertyChanged(nameof(LevelFilterSummary));
            ApplyFilters();
        }

        private void OnModuleFilterSelectionChanged()
        {
            if (_suppressFilterNotifications)
            {
                return;
            }

            OnPropertyChanged(nameof(AreAllModulesSelected));
            OnPropertyChanged(nameof(ModuleFilterSummary));
            ApplyFilters();
        }

        private void SetAllLevelFilters(bool value)
        {
            if (_levelFilterOptions.Count == 0)
            {
                return;
            }

            SuppressFilterNotifications(() =>
            {
                foreach (var option in _levelFilterOptions)
                {
                    option.IsSelected = value;
                }
            });

            OnPropertyChanged(nameof(AreAllLevelsSelected));
            OnPropertyChanged(nameof(LevelFilterSummary));
            ApplyFilters();
        }

        private void SetAllModuleFilters(bool value)
        {
            if (_moduleFilterOptions.Count == 0)
            {
                return;
            }

            SuppressFilterNotifications(() =>
            {
                foreach (var option in _moduleFilterOptions)
                {
                    option.IsSelected = value;
                }
            });

            OnPropertyChanged(nameof(AreAllModulesSelected));
            OnPropertyChanged(nameof(ModuleFilterSummary));
            ApplyFilters();
        }

        private void SuppressFilterNotifications(Action action)
        {
            var original = _suppressFilterNotifications;
            _suppressFilterNotifications = true;
            try
            {
                action();
            }
            finally
            {
                _suppressFilterNotifications = original;
            }
        }

        private static string BuildFilterSummary(IEnumerable<FilterOptionViewModel> options, string label)
        {
            var optionList = options?.ToList() ?? new List<FilterOptionViewModel>();
            if (optionList.Count == 0)
            {
                return $"No {label} available";
            }

            var selected = optionList.Where(option => option.IsSelected).Select(option => option.Name).ToList();
            if (selected.Count == 0)
            {
                return $"No {label} selected";
            }

            if (selected.Count == optionList.Count)
            {
                return $"All {label}";
            }

            return string.Join(", ", selected);
        }

        private void LoadColumnSettings()
        {
            var state = ColumnSettings.Load();

            if (state != null)
            {
                IncludeHeadersInRowAutomationName = state.IncludeHeadersInRowAutomationName;
            }
            else
            {
                IncludeHeadersInRowAutomationName = false;
            }

            if (state != null && state.Columns.Count > 0)
            {
                // Apply loaded settings
                foreach (var setting in state.Columns)
                {
                    _columnDisplayIndices[setting.Header] = setting.DisplayIndex;

                    // Apply visibility settings
                    switch (setting.Header)
                    {
                        case "Timestamp":
                            ShowTimestamp = setting.IsVisible;
                            break;
                        case "Level":
                            ShowLevel = setting.IsVisible;
                            break;
                        case "Module":
                            ShowModule = setting.IsVisible;
                            break;
                        case "Thread":
                            ShowThreadId = setting.IsVisible;
                            break;
                        case "Context":
                            ShowContext = setting.IsVisible;
                            break;
                        case "Message":
                            ShowMessage = setting.IsVisible;
                            break;
                    }
                }
            }
            else
            {
                // Use defaults
                ResetColumnLayout();
            }
        }

        private void SaveColumnLayout()
        {
            // This will be called by the view when column order changes
            // Settings are saved automatically by ColumnReorderBehavior
            StatusText = "Column layout saved";
            ColumnLayoutSaveRequested?.Invoke(this, EventArgs.Empty);
        }

        private void ResetColumnLayout()
        {
            var defaults = ColumnSettings.GetDefaults();
            _columnDisplayIndices.Clear();

            foreach (var setting in defaults)
            {
                _columnDisplayIndices[setting.Header] = setting.DisplayIndex;
            }

            // Reset visibility to defaults
            ShowTimestamp = true;
            ShowLevel = true;
            ShowModule = true;
            ShowThreadId = true;
            ShowContext = true;
            ShowMessage = true;
            IncludeHeadersInRowAutomationName = false;

            // Save the reset layout
            ColumnSettings.Save(defaults, includeHeadersInRowAutomationName: IncludeHeadersInRowAutomationName);

            // Trigger the reset event for the view
            ColumnLayoutReset?.Invoke(this, EventArgs.Empty);

            StatusText = "Column layout reset to defaults";
        }

        /// <summary>
        /// Event raised when column layout is reset to notify the view.
        /// </summary>
        public event EventHandler? ColumnLayoutReset;

        /// <summary>
        /// Event raised when column layout should be saved (menu command).
        /// </summary>
        public event EventHandler? ColumnLayoutSaveRequested;

        #endregion
    }
}
