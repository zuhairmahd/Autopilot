using System;
using System.Reflection;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Automation.Peers;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace Autopilot.LogViewer.UI.Behaviors
{
    /// <summary>
    /// Attached behavior to control DataGrid column visibility and width dynamically.
    /// Also ensures hidden columns are excluded from UIAutomation tree for screen readers.
    /// </summary>
    public static class DataGridColumnVisibilityBehavior
    {
        #region IsVisible Attached Property

        public static readonly DependencyProperty IsVisibleProperty =
            DependencyProperty.RegisterAttached(
                "IsVisible",
                typeof(bool),
                typeof(DataGridColumnVisibilityBehavior),
                new PropertyMetadata(true, OnIsVisibleChanged));

        public static bool GetIsVisible(DependencyObject obj)
        {
            return (bool)obj.GetValue(IsVisibleProperty);
        }

        public static void SetIsVisible(DependencyObject obj, bool value)
        {
            obj.SetValue(IsVisibleProperty, value);
        }

        private static void OnIsVisibleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is not DataGridColumn column)
            {
                return;
            }

            bool isVisible = (bool)e.NewValue;

            // Acquire DataGrid owner via reflection (internal property)
            var dataGridProperty = typeof(DataGridColumn).GetProperty("DataGridOwner", BindingFlags.Instance | BindingFlags.NonPublic);
            var dataGrid = dataGridProperty?.GetValue(column) as DataGrid;

            if (isVisible)
            {
                // Re-insert the column if it was removed previously
                if (GetWasRemoved(column) && dataGrid != null)
                {
                    int desiredIndex = GetOriginalDisplayIndex(column) ?? dataGrid.Columns.Count;
                    desiredIndex = Math.Max(0, Math.Min(desiredIndex, dataGrid.Columns.Count));

                    // Insert back into the Columns collection
                    dataGrid.Columns.Insert(desiredIndex, column);

                    // Ensure DisplayIndex aligns with desired position
                    column.DisplayIndex = Math.Max(0, Math.Min(desiredIndex, dataGrid.Columns.Count - 1));

                    SetWasRemoved(column, false);
                }

                // Restore original width/visibility
                var originalWidth = GetOriginalWidth(column);
                if (originalWidth != null)
                {
                    column.Width = originalWidth.Value;
                }
                else
                {
                    // Fallback to DesiredWidth if provided
                    var desired = GetDesiredWidth(column);
                    column.Width = desired;
                }
                column.Visibility = Visibility.Visible;

                // Notify any realized cells to clear Offscreen marking
                UpdateColumnCellsAccessibility(column, true);
            }
            else
            {
                // Save current width before hiding
                if (column.Width.Value > 0 || column.Width.IsStar || column.Width.IsAuto)
                {
                    SetOriginalWidth(column, column.Width);
                }

                // Persist original display index for re-insertion
                if (dataGrid != null)
                {
                    SetOriginalDisplayIndex(column, column.DisplayIndex);
                }

                // Proactively mark realized cells as offscreen and notify AT
                UpdateColumnCellsAccessibility(column, false);

                // Remove the column from the DataGrid to fully eliminate peers
                if (dataGrid != null && dataGrid.Columns.Contains(column))
                {
                    dataGrid.Columns.Remove(column);
                    SetWasRemoved(column, true);
                }
                else
                {
                    // Fallback: collapse/width=0 if we cannot access owner (should be rare)
                    column.Width = new DataGridLength(0);
                    column.Visibility = Visibility.Collapsed;
                }
            }
        }

        /// <summary>
        /// Updates accessibility properties of all cells in the column.
        /// This ensures screen readers skip cells in hidden columns.
        /// </summary>
        private static void UpdateColumnCellsAccessibility(DataGridColumn column, bool isVisible)
        {
            // Use reflection to access internal DataGridOwner property
            var dataGridProperty = typeof(DataGridColumn).GetProperty("DataGridOwner",
                BindingFlags.Instance | BindingFlags.NonPublic);
            if (dataGridProperty == null) return;

            var dataGrid = dataGridProperty.GetValue(column) as DataGrid;
            if (dataGrid == null) return;

            int columnIndex = dataGrid.Columns.IndexOf(column);

            // Iterate through all visual rows (respecting virtualization)
            for (int i = 0; i < dataGrid.Items.Count; i++)
            {
                var row = dataGrid.ItemContainerGenerator.ContainerFromIndex(i) as DataGridRow;
                if (row != null)
                {
                    // Find the cell for this column
                    var cell = GetCell(dataGrid, row, columnIndex);
                    if (cell != null)
                    {
                        // Set automation properties to exclude hidden cells from screen readers
                        if (isVisible)
                        {
                            // Remove offscreen behavior override - let WPF handle it normally
                            cell.ClearValue(AutomationProperties.IsOffscreenBehaviorProperty);
                        }
                        else
                        {
                            // Mark as offscreen so screen readers skip it
                            AutomationProperties.SetIsOffscreenBehavior(cell, IsOffscreenBehavior.Offscreen);
                        }

                        // Notify automation clients of the change
                        var peer = UIElementAutomationPeer.FromElement(cell);
                        if (peer != null)
                        {
                            peer.RaisePropertyChangedEvent(
                                AutomationElementIdentifiers.IsOffscreenProperty,
                                !isVisible,  // old value
                                isVisible);  // new value
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Gets a specific cell from a DataGrid row by column index
        /// </summary>
        private static DataGridCell? GetCell(DataGrid dataGrid, DataGridRow row, int columnIndex)
        {
            if (row == null) return null;

            var presenter = GetVisualChild<DataGridCellsPresenter>(row);
            if (presenter == null) return null;

            // Try to get the cell directly
            var cell = presenter.ItemContainerGenerator.ContainerFromIndex(columnIndex) as DataGridCell;
            if (cell != null) return cell;

            // If virtualized, force generation
            dataGrid.ScrollIntoView(row.Item, dataGrid.Columns[columnIndex]);
            dataGrid.UpdateLayout();

            return presenter.ItemContainerGenerator.ContainerFromIndex(columnIndex) as DataGridCell;
        }

        /// <summary>
        /// Helper to find visual children of a specific type
        /// </summary>
        private static T? GetVisualChild<T>(DependencyObject? parent) where T : Visual
        {
            if (parent == null) return null;

            T? child = null;
            int numVisuals = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < numVisuals; i++)
            {
                var v = VisualTreeHelper.GetChild(parent, i) as Visual;
                child = v as T;
                if (child == null)
                {
                    child = GetVisualChild<T>(v);
                }
                if (child != null)
                {
                    break;
                }
            }
            return child;
        }

        #endregion

        #region OriginalWidth Attached Property (for storing original width)

        private static readonly DependencyProperty OriginalWidthProperty =
            DependencyProperty.RegisterAttached(
                "OriginalWidth",
                typeof(DataGridLength?),
                typeof(DataGridColumnVisibilityBehavior),
                new PropertyMetadata(null));

        private static DataGridLength? GetOriginalWidth(DependencyObject obj)
        {
            return (DataGridLength?)obj.GetValue(OriginalWidthProperty);
        }

        private static void SetOriginalWidth(DependencyObject obj, DataGridLength value)
        {
            obj.SetValue(OriginalWidthProperty, value);
        }

        #endregion

        #region DesiredWidth Attached Property (for specifying width when visible)

        public static readonly DependencyProperty DesiredWidthProperty =
            DependencyProperty.RegisterAttached(
                "DesiredWidth",
                typeof(DataGridLength),
                typeof(DataGridColumnVisibilityBehavior),
                new PropertyMetadata(DataGridLength.Auto));

        public static DataGridLength GetDesiredWidth(DependencyObject obj)
        {
            return (DataGridLength)obj.GetValue(DesiredWidthProperty);
        }

        public static void SetDesiredWidth(DependencyObject obj, DataGridLength value)
        {
            obj.SetValue(DesiredWidthProperty, value);
            // Store as original width if not already set
            if (GetOriginalWidth(obj) == null)
            {
                SetOriginalWidth(obj, value);
            }
        }

        #endregion

        #region Column reinsert metadata (OriginalDisplayIndex, WasRemoved)

        private static readonly DependencyProperty OriginalDisplayIndexProperty =
            DependencyProperty.RegisterAttached(
                "OriginalDisplayIndex",
                typeof(int?),
                typeof(DataGridColumnVisibilityBehavior),
                new PropertyMetadata(null));

        private static int? GetOriginalDisplayIndex(DependencyObject obj)
        {
            return (int?)obj.GetValue(OriginalDisplayIndexProperty);
        }

        private static void SetOriginalDisplayIndex(DependencyObject obj, int? value)
        {
            obj.SetValue(OriginalDisplayIndexProperty, value);
        }

        private static readonly DependencyProperty WasRemovedProperty =
            DependencyProperty.RegisterAttached(
                "WasRemoved",
                typeof(bool),
                typeof(DataGridColumnVisibilityBehavior),
                new PropertyMetadata(false));

        private static bool GetWasRemoved(DependencyObject obj)
        {
            return (bool)obj.GetValue(WasRemovedProperty);
        }

        private static void SetWasRemoved(DependencyObject obj, bool value)
        {
            obj.SetValue(WasRemovedProperty, value);
        }

        #endregion
    }
}
