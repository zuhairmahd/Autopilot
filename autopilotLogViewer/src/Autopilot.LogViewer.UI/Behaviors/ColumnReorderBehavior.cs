using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Automation.Peers;
using System.Windows.Automation;
using Autopilot.LogViewer.UI.Controls;

namespace Autopilot.LogViewer.UI.Behaviors
{
    /// <summary>
    /// Attached behavior that adds a context menu to DataGrid column headers
    /// for rearranging columns with keyboard accessibility.
    /// </summary>
    public static class ColumnReorderBehavior
    {
        public static readonly DependencyProperty IsEnabledProperty =
            DependencyProperty.RegisterAttached(
                "IsEnabled",
                typeof(bool),
                typeof(ColumnReorderBehavior),
                new PropertyMetadata(false, OnIsEnabledChanged));

        public static bool GetIsEnabled(DependencyObject obj)
        {
            return (bool)obj.GetValue(IsEnabledProperty);
        }

        public static void SetIsEnabled(DependencyObject obj, bool value)
        {
            obj.SetValue(IsEnabledProperty, value);
        }

        private static void OnIsEnabledChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is not DataGrid dataGrid)
                return;

            if ((bool)e.NewValue)
            {
                dataGrid.Loaded += OnDataGridLoaded;
            }
            else
            {
                dataGrid.Loaded -= OnDataGridLoaded;
            }
        }

        private static void OnDataGridLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is not DataGrid dataGrid)
                return;

            // Attach context menus to all column headers
            AttachContextMenusToHeaders(dataGrid);
        }

        private static void AttachContextMenusToHeaders(DataGrid dataGrid)
        {
            // Wait for the visual tree to be fully loaded
            dataGrid.Dispatcher.BeginInvoke(new Action(() =>
            {
                foreach (var column in dataGrid.Columns)
                {
                    var header = FindColumnHeader(dataGrid, column);
                    if (header != null)
                    {
                        AttachContextMenu(header, dataGrid, column);
                    }
                }
            }), System.Windows.Threading.DispatcherPriority.Loaded);
        }

        private static DataGridColumnHeader? FindColumnHeader(DataGrid dataGrid, DataGridColumn column)
        {
            // Walk the visual tree to find the header
            var headerPresenter = FindVisualChild<DataGridColumnHeadersPresenter>(dataGrid);
            if (headerPresenter == null)
                return null;

            for (int i = 0; i < headerPresenter.Items.Count; i++)
            {
                var header = headerPresenter.ItemContainerGenerator.ContainerFromIndex(i) as DataGridColumnHeader;
                if (header?.Column == column)
                    return header;
            }

            return null;
        }

        private static void AttachContextMenu(DataGridColumnHeader header, DataGrid dataGrid, DataGridColumn column)
        {
            var contextMenu = new ContextMenu();

            // Move to Beginning menu item
            var moveToBeginningItem = new MenuItem
            {
                Header = "Move to _Beginning"
            };
            AutomationProperties.SetName(moveToBeginningItem, "Move Column to Beginning");
            AutomationProperties.SetHelpText(moveToBeginningItem, "Moves this column to the first position on the left");
            moveToBeginningItem.Click += (s, e) => MoveColumnToBeginning(dataGrid, column);
            moveToBeginningItem.InputGestureText = "Ctrl+Shift+Home";
            contextMenu.Items.Add(moveToBeginningItem);

            // Move Left menu item
            var moveLeftItem = new MenuItem
            {
                Header = "Move _Left"
            };
            AutomationProperties.SetName(moveLeftItem, "Move Column Left");
            AutomationProperties.SetHelpText(moveLeftItem, "Moves this column one position to the left");
            moveLeftItem.Click += (s, e) => MoveColumnLeft(dataGrid, column);
            moveLeftItem.InputGestureText = "Ctrl+Shift+Left";
            contextMenu.Items.Add(moveLeftItem);

            // Move Right menu item
            var moveRightItem = new MenuItem
            {
                Header = "Move _Right"
            };
            AutomationProperties.SetName(moveRightItem, "Move Column Right");
            AutomationProperties.SetHelpText(moveRightItem, "Moves this column one position to the right");
            moveRightItem.Click += (s, e) => MoveColumnRight(dataGrid, column);
            moveRightItem.InputGestureText = "Ctrl+Shift+Right";
            contextMenu.Items.Add(moveRightItem);

            // Move to End menu item
            var moveToEndItem = new MenuItem
            {
                Header = "Move to _End"
            };
            AutomationProperties.SetName(moveToEndItem, "Move Column to End");
            AutomationProperties.SetHelpText(moveToEndItem, "Moves this column to the last position on the right");
            moveToEndItem.Click += (s, e) => MoveColumnToEnd(dataGrid, column);
            moveToEndItem.InputGestureText = "Ctrl+Shift+End";
            contextMenu.Items.Add(moveToEndItem);

            contextMenu.Opened += (_, _) =>
            {
                var visibleColumns = dataGrid.Columns
                    .Where(c => c.Visibility == Visibility.Visible)
                    .OrderBy(c => c.DisplayIndex)
                    .ToList();
                var position = visibleColumns.IndexOf(column);
                var canMoveLeft = position > 0;
                var canMoveRight = position >= 0 && position < visibleColumns.Count - 1;

                moveToBeginningItem.IsEnabled = canMoveLeft;
                moveLeftItem.IsEnabled = canMoveLeft;
                moveRightItem.IsEnabled = canMoveRight;
                moveToEndItem.IsEnabled = canMoveRight;
            };

            contextMenu.Items.Add(new Separator());

            // Reset to Default Order menu item
            var resetItem = new MenuItem
            {
                Header = "_Reset Column Order"
            };
            AutomationProperties.SetName(resetItem, "Reset Column Order to Default");
            resetItem.Click += (s, e) => ResetColumnOrder(dataGrid);
            contextMenu.Items.Add(resetItem);

            // Set accessibility properties on the context menu
            AutomationProperties.SetName(contextMenu, $"Column Arrangement Menu for {column.Header}");

            header.ContextMenu = contextMenu;

            // Also support keyboard shortcuts when header has focus
            header.KeyDown += (s, e) =>
            {
                if (e.Key == Key.Home && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control
                    && (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                {
                    MoveColumnToBeginning(dataGrid, column);
                    e.Handled = true;
                }
                else if (e.Key == Key.Left && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control
                    && (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                {
                    MoveColumnLeft(dataGrid, column);
                    e.Handled = true;
                }
                else if (e.Key == Key.Right && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control
                    && (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                {
                    MoveColumnRight(dataGrid, column);
                    e.Handled = true;
                }
                else if (e.Key == Key.End && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control
                    && (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                {
                    MoveColumnToEnd(dataGrid, column);
                    e.Handled = true;
                }
                else if (e.Key == Key.Apps || (e.Key == Key.F10 && (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift))
                {
                    // Open context menu with keyboard
                    header.ContextMenu.IsOpen = true;
                    e.Handled = true;
                }
            };

            // Make header focusable for keyboard access
            header.Focusable = true;
            KeyboardNavigation.SetTabNavigation(header, KeyboardNavigationMode.Local);

            // Set accessibility properties
            AutomationProperties.SetHelpText(header,
                $"Column header for {column.Header}. Right-click or press Shift+F10 for column arrangement options. " +
                $"Use Ctrl+Shift+Home to move to beginning, Ctrl+Shift+End to move to end, " +
                $"Ctrl+Shift+Left or Ctrl+Shift+Right to move one position.");
        }

        private static void MoveColumnLeft(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            if (currentIndex > 0)
            {
                int newIndex = currentIndex - 1;

                // Simply set the new DisplayIndex - WPF will automatically adjust other columns
                column.DisplayIndex = newIndex;

                // Announce the change to screen readers
                AnnounceColumnMove(column, "left", currentIndex, newIndex);

                // Update automation properties for screen readers
                UpdateAutomationProperties(dataGrid);

                // Save the new arrangement
                SaveColumnOrder(dataGrid);
            }
        }

        private static void MoveColumnRight(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            int maxIndex = dataGrid.Columns.Count - 1;

            if (currentIndex < maxIndex)
            {
                int newIndex = currentIndex + 1;

                // Simply set the new DisplayIndex - WPF will automatically adjust other columns
                column.DisplayIndex = newIndex;

                // Announce the change to screen readers
                AnnounceColumnMove(column, "right", currentIndex, newIndex);

                // Update automation properties for screen readers
                UpdateAutomationProperties(dataGrid);

                // Save the new arrangement
                SaveColumnOrder(dataGrid);
            }
        }

        private static void MoveColumnToBeginning(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            if (currentIndex > 0)
            {
                // Move to first position (index 0)
                column.DisplayIndex = 0;

                // Announce the change to screen readers
                var message = $"{column.Header} column moved to beginning (position 1)";
                System.Diagnostics.Debug.WriteLine(message);

                // Update automation properties for screen readers
                UpdateAutomationProperties(dataGrid);

                // Save the new arrangement
                SaveColumnOrder(dataGrid);
            }
        }

        private static void MoveColumnToEnd(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            int maxIndex = dataGrid.Columns.Count - 1;

            if (currentIndex < maxIndex)
            {
                // Move to last position
                column.DisplayIndex = maxIndex;

                // Announce the change to screen readers
                var message = $"{column.Header} column moved to end (position {maxIndex + 1})";
                System.Diagnostics.Debug.WriteLine(message);

                // Update automation properties for screen readers
                UpdateAutomationProperties(dataGrid);

                // Save the new arrangement
                SaveColumnOrder(dataGrid);
            }
        }

        private static void ResetColumnOrder(DataGrid dataGrid)
        {
            // Reset to default order (index = position in Columns collection)
            var defaults = Helpers.ColumnSettings.GetDefaults();

            foreach (var setting in defaults)
            {
                var column = dataGrid.Columns.FirstOrDefault(c =>
                    c.Header?.ToString() == setting.Header);
                if (column != null)
                {
                    column.DisplayIndex = setting.DisplayIndex;
                }
            }

            // Announce the reset
            var message = "Column order reset to default";
            System.Diagnostics.Debug.WriteLine(message);

            // Update automation properties for screen readers
            UpdateAutomationProperties(dataGrid);

            // Save the reset order
            SaveColumnOrder(dataGrid);
        }

        private static void AnnounceColumnMove(DataGridColumn column, string direction, int oldIndex, int newIndex)
        {
            var message = $"{column.Header} column moved {direction} from position {oldIndex + 1} to {newIndex + 1}";
            System.Diagnostics.Debug.WriteLine(message);

            // This will be picked up by screen readers through the Debug output
            // In a production app, you might use UIAutomation's RaiseNotificationEvent
        }

        private static void UpdateAutomationProperties(DataGrid dataGrid)
        {
            var visibleColumns = dataGrid.Columns.Where(c => c.Visibility == Visibility.Visible)
                                                .OrderBy(c => c.DisplayIndex)
                                                .ToList();
            int visibleColumnCount = visibleColumns.Count;

            for (int i = 0; i < visibleColumnCount; i++)
            {
                var column = visibleColumns[i];
                var header = FindColumnHeader(dataGrid, column);
                if (header != null)
                {
                    AutomationProperties.SetPositionInSet(header, i + 1);
                    AutomationProperties.SetSizeOfSet(header, visibleColumnCount);
                }
            }
        }

        private static void SaveColumnOrder(DataGrid dataGrid)
        {
            var settings = new System.Collections.Generic.List<Helpers.ColumnSetting>();
            var includeHeadersPreference = dataGrid is AccessibleDataGrid accessibleGrid
                ? accessibleGrid.IncludeHeadersInRowAutomationName
                : false;

            foreach (var column in dataGrid.Columns)
            {
                var header = column.Header?.ToString() ?? string.Empty;
                var width = column.Width.IsAuto ? 0 :
                           column.Width.IsStar ? 0 :
                           column.Width.Value;

                settings.Add(new Helpers.ColumnSetting
                {
                    Header = header,
                    DisplayIndex = column.DisplayIndex,
                    IsVisible = column.Visibility == Visibility.Visible,
                    Width = width
                });
            }

            Helpers.ColumnSettings.Save(settings, includeHeadersPreference);
        }

        private static T? FindVisualChild<T>(DependencyObject? parent) where T : DependencyObject
        {
            if (parent == null) return null;

            int childCount = System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < childCount; i++)
            {
                var child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i);
                if (child is T result)
                    return result;

                var descendant = FindVisualChild<T>(child);
                if (descendant != null)
                    return descendant;
            }

            return null;
        }
    }
}
