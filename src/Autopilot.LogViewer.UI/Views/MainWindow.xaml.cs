using System.Linq;
using System.Windows;
using System.Diagnostics;
using System.IO;
using Autopilot.LogViewer.UI.ViewModels;

namespace Autopilot.LogViewer.UI.Views
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();

            // Subscribe to the ColumnLayoutReset event
            if (DataContext is MainViewModel viewModel)
            {
                viewModel.ColumnLayoutReset += OnColumnLayoutReset;
            }

            Loaded += MainWindow_Loaded;
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            // Ensure the DataContext event is wired up
            if (DataContext is MainViewModel viewModel)
            {
                viewModel.ColumnLayoutReset -= OnColumnLayoutReset; // Remove if already added
                viewModel.ColumnLayoutReset += OnColumnLayoutReset;
            }
        }

        private void OnColumnLayoutReset(object? sender, System.EventArgs e)
        {
            // Reset the DataGrid columns to their default order
            ResetDataGridColumns();
        }

        private void ResetDataGridColumns()
        {
            // Get default settings
            var defaults = Helpers.ColumnSettings.GetDefaults();

            // Apply to DataGrid columns
            foreach (var setting in defaults)
            {
                var column = LogDataGrid.Columns.FirstOrDefault(c =>
                    c.Header?.ToString() == setting.Header);
                if (column != null)
                {
                    column.DisplayIndex = setting.DisplayIndex;
                }
            }
        }

        /// <summary>
        /// Handles the Exit menu item click.
        /// </summary>
        private void Exit_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }

        /// <summary>
        /// Shows a simple About dialog with application information.
        /// </summary>
        private void About_Click(object sender, RoutedEventArgs e)
        {
            var version = System.Reflection.Assembly.GetExecutingAssembly()?.GetName()?.Version?.ToString() ?? "";
            var message = $"Autopilot Log Viewer\nVersion: {version}\n\nAccessible WPF log viewer for Autopilot logs.\n\nKnown issues are documented in the README.";
            MessageBox.Show(this, message, "About Autopilot Log Viewer", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        /// <summary>
        /// Attempts to open the README.md file in the default associated application.
        /// Falls back to LOG_VIEWER_USER_GUIDE.md if README is not found.
        /// </summary>
        private void OpenReadme_Click(object sender, RoutedEventArgs e)
        {
            string? path = FindFileUpwards(System.AppContext.BaseDirectory, "README.md");
            if (path == null)
            {
                path = FindFileUpwards(System.AppContext.BaseDirectory, Path.Combine("docs", "LOG_VIEWER_USER_GUIDE.md"));
            }

            if (path != null && File.Exists(path))
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = path,
                        UseShellExecute = true
                    });
                }
                catch
                {
                    MessageBox.Show(this, $"Could not open: {path}", "Open README", MessageBoxButton.OK, MessageBoxImage.Warning);
                }
            }
            else
            {
                MessageBox.Show(this,
                    "README not found next to the application. Please refer to the repository README for known issues.",
                    "Open README",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
        }

        private static string? FindFileUpwards(string startDirectory, string relativePath)
        {
            try
            {
                var dir = new DirectoryInfo(startDirectory);
                while (dir != null)
                {
                    string candidate = Path.Combine(dir.FullName, relativePath);
                    if (File.Exists(candidate))
                    {
                        return candidate;
                    }
                    dir = dir.Parent;
                }
            }
            catch
            {
                // ignore
            }
            return null;
        }
    }
}
