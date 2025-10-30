using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows.Input;
using Autopilot.LogViewer.Core.Models;
using Autopilot.LogViewer.Core.Parsers;

namespace Autopilot.LogViewer.UI.ViewModels
{
    /// <summary>
    /// Main ViewModel for the log viewer application.
    /// </summary>
    public class MainViewModel : ViewModelBase
    {
        private string _filePath = string.Empty;
        private string _searchText = string.Empty;
        private string _selectedLevel = "All";
        private string _selectedModule = "All";
        private bool _isLoading;
        private string _statusText = "Ready";
        private ObservableCollection<LogEntry> _allEntries = new();
        private ObservableCollection<LogEntry> _filteredEntries = new();
        private ObservableCollection<string> _availableModules = new();

        // Column visibility
        private bool _showTimestamp = true;
        private bool _showLevel = true;
        private bool _showModule = true;
        private bool _showThreadId = true;
        private bool _showContext = true;
        private bool _showMessage = true;

        /// <summary>
        /// Initializes a new instance of the MainViewModel class.
        /// </summary>
        public MainViewModel()
        {
            // Initialize commands
            OpenFileCommand = new RelayCommand(_ => OpenFile());
            RefreshCommand = new RelayCommand(_ => RefreshLog(), _ => !string.IsNullOrEmpty(FilePath));
            ClearFiltersCommand = new RelayCommand(_ => ClearFilters());

            // Initialize available levels
            AvailableLevels = new ObservableCollection<string>
            {
                "All", "Error", "Warning", "Information", "Verbose", "Debug"
            };
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
        /// Gets or sets the selected log level filter.
        /// </summary>
        public string SelectedLevel
        {
            get => _selectedLevel;
            set
            {
                if (SetProperty(ref _selectedLevel, value))
                {
                    ApplyFilters();
                }
            }
        }

        /// <summary>
        /// Gets or sets the selected module filter.
        /// </summary>
        public string SelectedModule
        {
            get => _selectedModule;
            set
            {
                if (SetProperty(ref _selectedModule, value))
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
        /// Gets the available log levels.
        /// </summary>
        public ObservableCollection<string> AvailableLevels { get; }

        /// <summary>
        /// Gets the available modules.
        /// </summary>
        public ObservableCollection<string> AvailableModules
        {
            get => _availableModules;
            private set => SetProperty(ref _availableModules, value);
        }

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

        #endregion

        #region Commands

        public ICommand OpenFileCommand { get; }
        public ICommand RefreshCommand { get; }
        public ICommand ClearFiltersCommand { get; }

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
            }
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

                // Extract unique modules
                var modules = entries.Select(e => e.Module).Distinct().OrderBy(m => m).ToList();
                modules.Insert(0, "All");
                AvailableModules = new ObservableCollection<string>(modules);

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

            var filtered = _allEntries.AsEnumerable();

            // Apply level filter
            if (SelectedLevel != "All")
            {
                filtered = filtered.Where(e => e.Level.Equals(SelectedLevel, StringComparison.OrdinalIgnoreCase));
            }

            // Apply module filter
            if (SelectedModule != "All")
            {
                filtered = filtered.Where(e => e.Module.Equals(SelectedModule, StringComparison.OrdinalIgnoreCase));
            }

            // Apply search filter
            if (!string.IsNullOrWhiteSpace(SearchText))
            {
                var searchLower = SearchText.ToLowerInvariant();
                filtered = filtered.Where(e =>
                    e.Message.ToLowerInvariant().Contains(searchLower) ||
                    e.Module.ToLowerInvariant().Contains(searchLower) ||
                    e.Context.ToLowerInvariant().Contains(searchLower));
            }

            FilteredEntries = new ObservableCollection<LogEntry>(filtered);
            StatusText = $"Showing {FilteredEntries.Count} of {_allEntries.Count} entries";
        }

        private void ClearFilters()
        {
            SearchText = string.Empty;
            SelectedLevel = "All";
            SelectedModule = "All";
        }

        #endregion
    }
}
