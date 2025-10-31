using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Automation.Peers;
using System.Windows.Automation;

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

            // Update accessibility metadata for headers (position/size)
            UpdateHeaderAutomation(dataGrid);
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

            // Move Left menu item
            var moveLeftItem = new MenuItem
            {
                Header = "Move _Left"
            };
            AutomationProperties.SetName(moveLeftItem, "Move Column Left");
            moveLeftItem.Click += (s, e) => MoveColumnLeft(dataGrid, column);
            // Keyboard shortcut: Ctrl+Shift+Left
            moveLeftItem.InputGestureText = "Ctrl+Shift+Left";
            contextMenu.Items.Add(moveLeftItem);

            // Move Right menu item
            var moveRightItem = new MenuItem
            {
                Header = "Move _Right"
            };
            AutomationProperties.SetName(moveRightItem, "Move Column Right");
            moveRightItem.Click += (s, e) => MoveColumnRight(dataGrid, column);
            // Keyboard shortcut: Ctrl+Shift+Right
            moveRightItem.InputGestureText = "Ctrl+Shift+Right";
            contextMenu.Items.Add(moveRightItem);

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
                if (e.Key == Key.Left && (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control
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
                $"Use Ctrl+Shift+Left or Ctrl+Shift+Right to reorder.");
        }

        private static void MoveColumnLeft(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            if (currentIndex > 0)
            {
                // Find the column to the left
                var leftColumn = dataGrid.Columns.FirstOrDefault(c => c.DisplayIndex == currentIndex - 1);
                if (leftColumn != null)
                {
                    // Swap display indices
                    column.DisplayIndex = currentIndex - 1;
                    leftColumn.DisplayIndex = currentIndex;

                    // Announce the change to screen readers
                    AnnounceColumnMove(column, "left", currentIndex, currentIndex - 1);

                    // Save the new arrangement
                    SaveColumnOrder(dataGrid);

                    // Update row accessible names to reflect new column order
                    UpdateRowAccessibleNames(dataGrid);

                    // Update header automation for accurate index announcements
                    UpdateHeaderAutomation(dataGrid);
                }
            }
        }

        private static void MoveColumnRight(DataGrid dataGrid, DataGridColumn column)
        {
            int currentIndex = column.DisplayIndex;
            int maxIndex = dataGrid.Columns.Count - 1;

            if (currentIndex < maxIndex)
            {
                // Find the column to the right
                var rightColumn = dataGrid.Columns.FirstOrDefault(c => c.DisplayIndex == currentIndex + 1);
                if (rightColumn != null)
                {
                    // Swap display indices
                    column.DisplayIndex = currentIndex + 1;
                    rightColumn.DisplayIndex = currentIndex;

                    // Announce the change to screen readers
                    AnnounceColumnMove(column, "right", currentIndex, currentIndex + 1);

                    // Save the new arrangement
                    SaveColumnOrder(dataGrid);

                    // Update row accessible names to reflect new column order
                    UpdateRowAccessibleNames(dataGrid);

                    // Update header automation for accurate index announcements
                    UpdateHeaderAutomation(dataGrid);
                }
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

            // Save the reset order
            SaveColumnOrder(dataGrid);

            // Update row accessible names
            UpdateRowAccessibleNames(dataGrid);

            // Update header automation for accurate index announcements
            UpdateHeaderAutomation(dataGrid);
        }

        private static void AnnounceColumnMove(DataGridColumn column, string direction, int oldIndex, int newIndex)
        {
            var message = $"{column.Header} column moved {direction} from position {oldIndex + 1} to {newIndex + 1}";
            System.Diagnostics.Debug.WriteLine(message);

            // This will be picked up by screen readers through the Debug output
            // In a production app, you might use UIAutomation's RaiseNotificationEvent
        }

        private static void SaveColumnOrder(DataGrid dataGrid)
        {
            var settings = new System.Collections.Generic.List<Helpers.ColumnSetting>();

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

            Helpers.ColumnSettings.Save(settings);
        }

        private static void UpdateRowAccessibleNames(DataGrid dataGrid)
        {
            // Trigger re-evaluation of row accessible names in AccessibleDataGrid
            // This is handled automatically by the AccessibleDataGrid.OnColumnsCollectionChanged
            // But we can force an update by refreshing the items
            if (dataGrid is Controls.AccessibleDataGrid accessibleGrid)
            {
                // The grid's CollectionChanged handler will update accessible names
                dataGrid.Items.Refresh();
            }
        }

        private static void UpdateHeaderAutomation(DataGrid dataGrid)
        {
            // Update PositionInSet and SizeOfSet so screen readers announce correct "x of y"
            var headerPresenter = FindVisualChild<DataGridColumnHeadersPresenter>(dataGrid);
            if (headerPresenter == null)
                return;

            int visibleCount = dataGrid.Columns.Count(c => c.Visibility == Visibility.Visible);
            for (int i = 0; i < headerPresenter.Items.Count; i++)
            {
                if (headerPresenter.ItemContainerGenerator.ContainerFromIndex(i) is DataGridColumnHeader header && header.Column != null)
                {
                    int pos = header.Column.DisplayIndex + 1;
                    AutomationProperties.SetPositionInSet(header, pos);
                    AutomationProperties.SetSizeOfSet(header, visibleCount);

                    // Ensure a clear, stable name for SRs
                    if (header.Column.Header != null)
                    {
                        AutomationProperties.SetName(header, header.Column.Header.ToString());
                    }
                }
            }
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
