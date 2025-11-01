using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace Autopilot.LogViewer.UI.Helpers
{
    /// <summary>
    /// Represents the display order and visibility settings for a single column.
    /// </summary>
    public class ColumnSetting
    {
        public string Header { get; set; } = string.Empty;
        public int DisplayIndex { get; set; }
        public bool IsVisible { get; set; } = true;
        public double Width { get; set; }
    }

    /// <summary>
    /// Represents the persisted state for column layout preferences.
    /// </summary>
    public class ColumnLayoutState
    {
        public List<ColumnSetting> Columns { get; set; } = new List<ColumnSetting>();
        public bool IncludeHeadersInRowAutomationName { get; set; }
    }

    /// <summary>
    /// Manages persistence of column settings (order, visibility, width) and layout preferences.
    /// </summary>
    public class ColumnSettings
    {
        private static readonly string SettingsDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "AutopilotLogViewer");

        private static readonly string SettingsFilePath = Path.Combine(
            SettingsDirectory,
            "ColumnSettings.json");

        private static readonly string RecentFilesPath = Path.Combine(
            SettingsDirectory,
            "RecentFiles.json");

        /// <summary>
        /// Saves column settings to persistent storage.
        /// </summary>
        public static void Save(IEnumerable<ColumnSetting> settings, bool includeHeadersInRowAutomationName)
        {
            var state = new ColumnLayoutState
            {
                Columns = settings.ToList(),
                IncludeHeadersInRowAutomationName = includeHeadersInRowAutomationName
            };

            Save(state);
        }

        /// <summary>
        /// Saves column layout state to persistent storage.
        /// </summary>
        public static void Save(ColumnLayoutState state)
        {
            try
            {
                if (!Directory.Exists(SettingsDirectory))
                {
                    Directory.CreateDirectory(SettingsDirectory);
                }

                var json = JsonSerializer.Serialize(state, new JsonSerializerOptions
                {
                    WriteIndented = true
                });

                File.WriteAllText(SettingsFilePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save column settings: {ex.Message}");
                // Don't throw - settings are nice-to-have, not critical
            }
        }

        /// <summary>
        /// Loads column layout state from persistent storage.
        /// </summary>
        public static ColumnLayoutState? Load()
        {
            try
            {
                if (!File.Exists(SettingsFilePath))
                {
                    return null;
                }

                var json = File.ReadAllText(SettingsFilePath);
                if (string.IsNullOrWhiteSpace(json))
                {
                    return null;
                }

                using var document = JsonDocument.Parse(json);
                if (document.RootElement.ValueKind == JsonValueKind.Array)
                {
                    // Backward compatibility with older layout files that contained only columns.
                    var columns = JsonSerializer.Deserialize<List<ColumnSetting>>(json) ?? new List<ColumnSetting>();
                    return new ColumnLayoutState
                    {
                        Columns = columns,
                        IncludeHeadersInRowAutomationName = false
                    };
                }

                var state = JsonSerializer.Deserialize<ColumnLayoutState>(json);
                if (state != null && state.Columns == null)
                {
                    state.Columns = new List<ColumnSetting>();
                }

                return state;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load column settings: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Gets the default column settings.
        /// </summary>
        public static List<ColumnSetting> GetDefaults()
        {
            return new List<ColumnSetting>
            {
                new ColumnSetting { Header = "Timestamp", DisplayIndex = 0, IsVisible = true, Width = 180 },
                new ColumnSetting { Header = "Level", DisplayIndex = 1, IsVisible = true, Width = 100 },
                new ColumnSetting { Header = "Module", DisplayIndex = 2, IsVisible = true, Width = 200 },
                new ColumnSetting { Header = "Thread", DisplayIndex = 3, IsVisible = true, Width = 70 },
                new ColumnSetting { Header = "Context", DisplayIndex = 4, IsVisible = true, Width = 150 },
                new ColumnSetting { Header = "Message", DisplayIndex = 5, IsVisible = true, Width = 0 } // Star-sized
            };
        }

        /// <summary>
        /// Saves the list of recent files.
        /// </summary>
        public static void SaveRecentFiles(List<string> recentFiles)
        {
            try
            {
                if (!Directory.Exists(SettingsDirectory))
                {
                    Directory.CreateDirectory(SettingsDirectory);
                }

                var json = JsonSerializer.Serialize(recentFiles, new JsonSerializerOptions
                {
                    WriteIndented = true
                });

                File.WriteAllText(RecentFilesPath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save recent files: {ex.Message}");
            }
        }

        /// <summary>
        /// Loads the list of recent files.
        /// </summary>
        public static List<string> LoadRecentFiles()
        {
            try
            {
                if (!File.Exists(RecentFilesPath))
                {
                    return new List<string>();
                }

                var json = File.ReadAllText(RecentFilesPath);
                return JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load recent files: {ex.Message}");
                return new List<string>();
            }
        }
    }
}
