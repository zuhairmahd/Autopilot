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
                // Restore stored metadata
                var originalWidth = GetOriginalWidth(column);
                column.Width = originalWidth ?? GetDesiredWidth(column);
                column.Visibility = Visibility.Visible;

                var originalDisplayIndex = GetOriginalDisplayIndex(column);
                if (originalDisplayIndex.HasValue && dataGrid != null)
                {
                    column.DisplayIndex = Math.Max(0, Math.Min(originalDisplayIndex.Value, dataGrid.Columns.Count - 1));
                }
            }
            else
            {
                // Save current width before hiding
                if (column.Width.Value > 0 || column.Width.IsStar || column.Width.IsAuto)
                {
                    SetOriginalWidth(column, column.Width);
                }

                if (dataGrid != null)
                {
                    SetOriginalDisplayIndex(column, column.DisplayIndex);
                }

                // Use Visibility.Collapsed as the primary hiding mechanism (Microsoft pattern)
                // DO NOT set Width=0 as it interferes with UI Automation peer caching
                column.Visibility = Visibility.Collapsed;
            }
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

        #region Column display metadata (OriginalDisplayIndex)

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

        #endregion
    }
}
