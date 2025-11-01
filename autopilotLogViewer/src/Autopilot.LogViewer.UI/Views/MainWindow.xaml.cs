using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Diagnostics;
using System.IO;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using Autopilot.LogViewer.UI.ViewModels;
using Autopilot.LogViewer.UI.Commands;
using Autopilot.LogViewer.UI.Behaviors;

namespace Autopilot.LogViewer.UI.Views
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private DataGridColumn? _focusedColumn;

        public MainWindow()
        {
            InitializeComponent();

            // Subscribe to the ColumnLayoutReset event
            if (DataContext is MainViewModel viewModel)
            {
                viewModel.ColumnLayoutReset += OnColumnLayoutReset;
                viewModel.ColumnLayoutSaveRequested += OnColumnLayoutSaveRequested;
            }

            RegisterColumnReorderCommandBindings();
            LogDataGrid.AddHandler(UIElement.GotKeyboardFocusEvent, new KeyboardFocusChangedEventHandler(OnLogDataGridGotKeyboardFocus), true);

            Loaded += MainWindow_Loaded;
        }

        /// <summary>
        /// Handles F6 key press to cycle focus between main UI components.
        /// </summary>
        private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.F6)
            {
                e.Handled = true;
                CycleFocus();
            }
        }

        /// <summary>
        /// Cycles focus between filter panel and data grid.
        /// </summary>
        private void CycleFocus()
        {
            // Check which component currently has focus
            var focusedElement = Keyboard.FocusedElement as DependencyObject;

            if (focusedElement == null)
            {
                // No element has focus, start with filter panel
                LevelFilterComboBox.Focus();
                return;
            }

            // Check if focus is within the filter panel
            if (IsElementInParent(focusedElement, FilterPanel))
            {
                // Move focus to data grid
                LogDataGrid.Focus();
            }
            else if (IsElementInParent(focusedElement, LogDataGrid))
            {
                // Move focus back to filter panel
                LevelFilterComboBox.Focus();
            }
            else
            {
                // Focus is elsewhere (menu, etc.), move to filter panel
                LevelFilterComboBox.Focus();
            }
        }

        /// <summary>
        /// Checks if an element is a child of a specified parent element.
        /// </summary>
        private static bool IsElementInParent(DependencyObject element, DependencyObject parent)
        {
            var current = element;
            while (current != null)
            {
                if (current == parent)
                {
                    return true;
                }
                current = System.Windows.Media.VisualTreeHelper.GetParent(current);
            }
            return false;
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            // Ensure the DataContext event is wired up
            if (DataContext is MainViewModel viewModel)
            {
                viewModel.ColumnLayoutReset -= OnColumnLayoutReset; // Remove if already added
                viewModel.ColumnLayoutReset += OnColumnLayoutReset;
                viewModel.ColumnLayoutSaveRequested -= OnColumnLayoutSaveRequested;
                viewModel.ColumnLayoutSaveRequested += OnColumnLayoutSaveRequested;
            }

            ApplySavedColumnLayout();
        }

        private void RegisterColumnReorderCommandBindings()
        {
            CommandBindings.Add(new CommandBinding(
                ColumnReorderCommands.MoveColumnToBeginning,
                ExecuteMoveColumnToBeginning,
                CanExecuteMoveColumnToBeginning));
            CommandBindings.Add(new CommandBinding(
                ColumnReorderCommands.MoveColumnLeft,
                ExecuteMoveColumnLeft,
                CanExecuteMoveColumnLeft));
            CommandBindings.Add(new CommandBinding(
                ColumnReorderCommands.MoveColumnRight,
                ExecuteMoveColumnRight,
                CanExecuteMoveColumnRight));
            CommandBindings.Add(new CommandBinding(
                ColumnReorderCommands.MoveColumnToEnd,
                ExecuteMoveColumnToEnd,
                CanExecuteMoveColumnToEnd));
            CommandBindings.Add(new CommandBinding(
                ColumnReorderCommands.ResetColumnOrder,
                ExecuteResetColumnOrder,
                CanExecuteResetColumnOrder));
        }

        private void OnLogDataGridGotKeyboardFocus(object sender, KeyboardFocusChangedEventArgs e)
        {
            if (e.NewFocus is DataGridColumnHeader header && header.Column != null)
            {
                _focusedColumn = header.Column;
                CommandManager.InvalidateRequerySuggested();
            }
        }

        private DataGridColumn? GetTargetColumn(object? parameter)
        {
            return parameter switch
            {
                DataGridColumn column => column,
                DataGridColumnHeader header => header.Column,
                _ => _focusedColumn
            };
        }

        private void ExecuteMoveColumnToBeginning(object sender, ExecutedRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            if (column != null && ColumnReorderBehavior.MoveColumnToBeginning(LogDataGrid, column))
            {
                e.Handled = true;
            }
        }

        private void CanExecuteMoveColumnToBeginning(object sender, CanExecuteRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            e.CanExecute = column != null && ColumnReorderBehavior.CanMoveColumnToBeginning(LogDataGrid, column);
            e.Handled = true;
        }

        private void ExecuteMoveColumnLeft(object sender, ExecutedRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            if (column != null && ColumnReorderBehavior.MoveColumnLeft(LogDataGrid, column))
            {
                e.Handled = true;
            }
        }

        private void CanExecuteMoveColumnLeft(object sender, CanExecuteRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            e.CanExecute = column != null && ColumnReorderBehavior.CanMoveColumnLeft(LogDataGrid, column);
            e.Handled = true;
        }

        private void ExecuteMoveColumnRight(object sender, ExecutedRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            if (column != null && ColumnReorderBehavior.MoveColumnRight(LogDataGrid, column))
            {
                e.Handled = true;
            }
        }

        private void CanExecuteMoveColumnRight(object sender, CanExecuteRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            e.CanExecute = column != null && ColumnReorderBehavior.CanMoveColumnRight(LogDataGrid, column);
            e.Handled = true;
        }

        private void ExecuteMoveColumnToEnd(object sender, ExecutedRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            if (column != null && ColumnReorderBehavior.MoveColumnToEnd(LogDataGrid, column))
            {
                e.Handled = true;
            }
        }

        private void CanExecuteMoveColumnToEnd(object sender, CanExecuteRoutedEventArgs e)
        {
            var column = GetTargetColumn(e.Parameter);
            e.CanExecute = column != null && ColumnReorderBehavior.CanMoveColumnToEnd(LogDataGrid, column);
            e.Handled = true;
        }

        private void ExecuteResetColumnOrder(object sender, ExecutedRoutedEventArgs e)
        {
            if (ColumnReorderBehavior.ResetColumnOrder(LogDataGrid))
            {
                e.Handled = true;
            }
        }

        private void CanExecuteResetColumnOrder(object sender, CanExecuteRoutedEventArgs e)
        {
            e.CanExecute = ColumnReorderBehavior.CanResetColumnOrder(LogDataGrid);
            e.Handled = true;
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

        private void OnColumnLayoutSaveRequested(object? sender, System.EventArgs e)
        {
            var settings = new List<Helpers.ColumnSetting>();

            foreach (var column in LogDataGrid.Columns)
            {
                var header = column.Header?.ToString() ?? string.Empty;
                var width = column.Width.IsAuto || column.Width.IsStar ? 0 : column.Width.Value;

                settings.Add(new Helpers.ColumnSetting
                {
                    Header = header,
                    DisplayIndex = column.DisplayIndex,
                    IsVisible = column.Visibility == Visibility.Visible,
                    Width = width
                });
            }

            var includeHeaders = LogDataGrid.IncludeHeadersInRowAutomationName;
            Helpers.ColumnSettings.Save(settings, includeHeaders);
        }

        private void ApplySavedColumnLayout()
        {
            var state = Helpers.ColumnSettings.Load();
            if (state?.Columns == null || state.Columns.Count == 0 || LogDataGrid.Columns.Count == 0)
            {
                return;
            }

            var columnLookup = LogDataGrid.Columns
                .Where(column => column.Header is string header && !string.IsNullOrWhiteSpace(header))
                .ToDictionary(
                    column => column.Header!.ToString()!,
                    column => column,
                    StringComparer.Ordinal);

            var orderedSettings = state.Columns
                .Where(setting => !string.IsNullOrWhiteSpace(setting.Header))
                .OrderBy(setting => setting.DisplayIndex)
                .ToList();

            if (orderedSettings.Count == 0)
            {
                return;
            }

            var appliedHeaders = new HashSet<string>(StringComparer.Ordinal);
            var nextDisplayIndex = 0;

            foreach (var setting in orderedSettings)
            {
                if (!columnLookup.TryGetValue(setting.Header, out var column))
                {
                    continue;
                }

                appliedHeaders.Add(setting.Header);

                if (setting.Width > 0)
                {
                    column.Width = new DataGridLength(setting.Width);
                }

                if (column.DisplayIndex != nextDisplayIndex)
                {
                    column.DisplayIndex = nextDisplayIndex;
                }

                nextDisplayIndex++;
            }

            foreach (var column in LogDataGrid.Columns
                         .Where(column => column.Header is string header && !appliedHeaders.Contains(header)))
            {
                if (column.DisplayIndex != nextDisplayIndex)
                {
                    column.DisplayIndex = nextDisplayIndex;
                }

                nextDisplayIndex++;
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
