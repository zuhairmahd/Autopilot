using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Threading;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// DataGrid with improved behavior for column visibility and ordering.
    /// Ensures columns maintain their display order when visibility changes.
    /// </summary>
    public class AccessibleDataGrid : DataGrid
    {
        private static readonly DependencyProperty HandlersAttachedProperty =
            DependencyProperty.RegisterAttached(
                "HandlersAttached",
                typeof(bool),
                typeof(AccessibleDataGrid),
                new PropertyMetadata(false));

        public AccessibleDataGrid()
        {
            LoadingRow += OnLoadingRow;
            Columns.CollectionChanged += OnColumnsCollectionChanged;
            Loaded += OnGridLoaded;
            KeyDown += OnKeyDown;
        }

        private void OnKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            // F5 hotkey for manual UI Automation refresh
            if (e.Key == System.Windows.Input.Key.F5)
            {
                RefreshUIAutomation();
                e.Handled = true;
            }
        }

        /// <summary>
        /// Force a complete UI Automation tree refresh for the DataGrid.
        /// Called by F5 hotkey or programmatically after major structural changes.
        /// </summary>
        public void RefreshUIAutomation()
        {
            UpdateLayout();
            InvalidateHeaderPeers();
            UpdateHeaderAutomationProperties();
            UpdateAllRowAccessibleNames();
            UpdateAllCellAutomationNames();

            // Deferred pass to catch any late-realized elements
            Dispatcher.BeginInvoke(new Action(() =>
            {
                InvalidateHeaderPeers();
                UpdateHeaderAutomationProperties();
                UpdateAllRowAccessibleNames();
                UpdateAllCellAutomationNames();
            }), DispatcherPriority.Background);
        }

        /// <summary>
        /// Ensure rows use AccessibleDataGridRow so our custom automation peer is active.
        /// </summary>
        /// <returns>A custom DataGridRow container.</returns>
        protected override System.Windows.DependencyObject GetContainerForItemOverride()
        {
            return new AccessibleDataGridRow();
        }

        private void OnGridLoaded(object sender, RoutedEventArgs e)
        {
            AttachColumnPropertyHandlers();
            UpdateAllRowAccessibleNames();
            UpdateAllCellAutomationNames();
            UpdateHeaderAutomationProperties();
        }

        private void OnColumnsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            AttachColumnPropertyHandlers(e.NewItems);
            UpdateAllRowAccessibleNames();
            UpdateAllCellAutomationNames();
            UpdateHeaderAutomationProperties();
        }

        private void OnLoadingRow(object? sender, DataGridRowEventArgs e)
        {
            UpdateRowAccessibleName(e.Row);
            UpdateRowCellAutomationNames(e.Row);
        }

        private void OnColumnDisplayIndexChanged(object? sender, EventArgs e)
        {
            UpdateLayout();
            InvalidateHeaderPeers();
            UpdateAllRowAccessibleNames();
            UpdateAllCellAutomationNames();
            UpdateHeaderAutomationProperties();

            // Force a headers presenter rebuild by toggling HeadersVisibility
            ForceHeaderRebuild();

            // Defer a second pass until after layout so newly realized cells get automation metadata
            Dispatcher.BeginInvoke(new Action(() =>
            {
                ForceHeaderRebuild();
                InvalidateHeaderPeers();
                UpdateAllRowAccessibleNames();
                UpdateAllCellAutomationNames();
                UpdateHeaderAutomationProperties();
            }), DispatcherPriority.Background);
        }

        private void OnColumnVisibilityChanged(object? sender, EventArgs e)
        {
            UpdateLayout();
            InvalidateHeaderPeers();
            UpdateAllRowAccessibleNames();
            UpdateAllCellAutomationNames();
            UpdateHeaderAutomationProperties();

            // Force a headers presenter rebuild by toggling HeadersVisibility
            ForceHeaderRebuild();

            // Defer a second pass until after layout so newly realized cells get automation metadata
            Dispatcher.BeginInvoke(new Action(() =>
            {
                ForceHeaderRebuild();
                InvalidateHeaderPeers();
                UpdateAllRowAccessibleNames();
                UpdateAllCellAutomationNames();
                UpdateHeaderAutomationProperties();
            }), DispatcherPriority.Background);
        }

        /// <summary>
        /// Forces WPF to recreate the header containers and their automation peers by
        /// toggling HeadersVisibility. This addresses stubborn cases where the first
        /// header remains non-focusable after a column is unhidden.
        /// </summary>
        private void ForceHeaderRebuild()
        {
            try
            {
                // Remember current setting
                var current = HeadersVisibility;

                // Temporarily hide, update layout, then restore
                HeadersVisibility = DataGridHeadersVisibility.None;
                UpdateLayout();

                HeadersVisibility = (current & DataGridHeadersVisibility.Column) != 0
                    ? DataGridHeadersVisibility.Column
                    : current; // restore as-is if rows were part of visibility

                UpdateLayout();

                // Notify UIA of structure change
                InvalidateHeaderPeers();
            }
            catch
            {
                // Non-fatal fallback
            }
        }

        private void AttachColumnPropertyHandlers(System.Collections.IList? columns = null)
        {
            var targetColumns = columns ?? Columns;
            foreach (DataGridColumn column in targetColumns)
            {
                if (GetHandlersAttached(column))
                {
                    continue;
                }

                var displayDescriptor = DependencyPropertyDescriptor.FromProperty(
                    DataGridColumn.DisplayIndexProperty,
                    typeof(DataGridColumn));
                displayDescriptor?.AddValueChanged(column, OnColumnDisplayIndexChanged);

                var visibilityDescriptor = DependencyPropertyDescriptor.FromProperty(
                    DataGridColumn.VisibilityProperty,
                    typeof(DataGridColumn));
                visibilityDescriptor?.AddValueChanged(column, OnColumnVisibilityChanged);

                SetHandlersAttached(column, true);
            }
        }

        private static bool GetHandlersAttached(DependencyObject obj)
        {
            return (bool)obj.GetValue(HandlersAttachedProperty);
        }

        private static void SetHandlersAttached(DependencyObject obj, bool value)
        {
            obj.SetValue(HandlersAttachedProperty, value);
        }

        private void UpdateAllRowAccessibleNames()
        {
            for (int i = 0; i < Items.Count; i++)
            {
                if (ItemContainerGenerator.ContainerFromIndex(i) is DataGridRow row)
                {
                    UpdateRowAccessibleName(row);
                }
            }
        }

        private void UpdateRowAccessibleName(DataGridRow row)
        {
            try
            {
                string name = BuildRowAccessibleName(row);
                if (!string.IsNullOrEmpty(name))
                {
                    AutomationProperties.SetName(row, name);
                }
            }
            catch
            {
                // Accessibility adornments must not impact stability
            }
        }

        private string BuildRowAccessibleName(DataGridRow row)
        {
            var visibleColumns = GetVisibleColumns();
            var parts = new List<string>(visibleColumns.Count);

            foreach (var column in visibleColumns)
            {
                // Get cell by actual column index, not display index
                int columnIndex = Columns.IndexOf(column);
                if (columnIndex < 0)
                {
                    continue;
                }

                var cell = GetCell(row, columnIndex);
                string value = ExtractCellText(cell) ?? string.Empty;

                if (!string.IsNullOrWhiteSpace(value))
                {
                    // Requirement: Do not report column titles in body rows; read only values
                    parts.Add(value);
                }
            }

            return string.Join("; ", parts);
        }

        private void UpdateRowCellAutomationNames(DataGridRow row)
        {
            try
            {
                var visibleColumns = GetVisibleColumns();
                int totalVisible = visibleColumns.Count;

                // Map each visible column to its 1-based position according to DisplayIndex
                var positionByColumn = new Dictionary<DataGridColumn, int>(totalVisible);
                for (int i = 0; i < visibleColumns.Count; i++)
                {
                    positionByColumn[visibleColumns[i]] = i + 1;
                }

                // Update all cells, including hidden ones
                for (int columnIndex = 0; columnIndex < Columns.Count; columnIndex++)
                {
                    var column = Columns[columnIndex];
                    var cell = GetCell(row, columnIndex);
                    if (cell == null)
                    {
                        continue;
                    }

                    bool isVisible = column.Visibility == Visibility.Visible;

                    if (isVisible)
                    {
                        string value = ExtractCellText(cell) ?? string.Empty;
                        int position = positionByColumn.TryGetValue(column, out var pos) ? pos : 0;

                        // Requirement: For body cells, announce only the value (no header)
                        AutomationProperties.SetName(cell, value);
                        AutomationProperties.SetPositionInSet(cell, position);
                        AutomationProperties.SetSizeOfSet(cell, totalVisible);
                    }
                    else
                    {
                        // Clear automation properties for hidden cells
                        AutomationProperties.SetName(cell, string.Empty);
                        AutomationProperties.SetPositionInSet(cell, 0);
                        AutomationProperties.SetSizeOfSet(cell, 0);
                    }
                }
            }
            catch
            {
                // Accessibility adornments must not impact stability
            }
        }

        private void UpdateAllCellAutomationNames()
        {
            for (int i = 0; i < Items.Count; i++)
            {
                if (ItemContainerGenerator.ContainerFromIndex(i) is DataGridRow row)
                {
                    UpdateRowCellAutomationNames(row);
                }
            }
        }

        private DataGridCell? GetCell(DataGridRow row, int columnIndex)
        {
            var presenter = FindVisualChild<DataGridCellsPresenter>(row);
            return presenter?.ItemContainerGenerator.ContainerFromIndex(columnIndex) as DataGridCell;
        }

        private static string? ExtractCellText(DataGridCell? cell)
        {
            if (cell == null)
            {
                return null;
            }

            var textBlock = FindVisualChild<TextBlock>(cell);
            return textBlock?.Text;
        }

        private static TChild? FindVisualChild<TChild>(DependencyObject? parent) where TChild : DependencyObject
        {
            if (parent == null)
            {
                return null;
            }

            int count = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < count; i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is TChild wanted)
                {
                    return wanted;
                }

                var result = FindVisualChild<TChild>(child);
                if (result != null)
                {
                    return result;
                }
            }

            return null;
        }

        private static IEnumerable<TChild> FindVisualChildren<TChild>(DependencyObject? parent) where TChild : DependencyObject
        {
            if (parent == null)
            {
                yield break;
            }

            int count = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < count; i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is TChild wanted)
                {
                    yield return wanted;
                }

                foreach (var grand in FindVisualChildren<TChild>(child))
                {
                    yield return grand;
                }
            }
        }

        /// <summary>
        /// Notifies UI Automation that the header structure has changed.
        /// This is critical for screen readers to rebuild their column index after show/hide.
        /// Per Microsoft docs: Use StructureChanged event for structural changes (not InvalidatePeer).
        /// </summary>
        private void InvalidateHeaderPeers()
        {
            try
            {
                var headersPresenter = FindVisualChild<DataGridColumnHeadersPresenter>(this);
                if (headersPresenter == null)
                {
                    return;
                }

                // Get the presenter's automation peer (parent of all header peers)
                var presenterPeer = System.Windows.Automation.Peers.UIElementAutomationPeer.FromElement(headersPresenter);
                if (presenterPeer == null)
                {
                    presenterPeer = System.Windows.Automation.Peers.UIElementAutomationPeer.CreatePeerForElement(headersPresenter);
                }

                if (presenterPeer != null)
                {
                    // Raise StructureChanged event to notify screen readers
                    // This tells UIA clients to re-query GetChildrenCore() and rebuild navigation
                    if (System.Windows.Automation.Peers.AutomationPeer.ListenerExists(System.Windows.Automation.Peers.AutomationEvents.StructureChanged))
                    {
                        presenterPeer.RaiseAutomationEvent(System.Windows.Automation.Peers.AutomationEvents.StructureChanged);
                    }

                    // Also invalidate the presenter peer to recalculate its properties
                    presenterPeer.InvalidatePeer();

                    // Force re-query of children to flush cached peers
                    _ = presenterPeer.GetChildren();
                }
            }
            catch
            {
                // Do not allow accessibility updates to break UX
            }
        }

        private void UpdateHeaderAutomationProperties()
        {
            try
            {
                var headersPresenter = FindVisualChild<DataGridColumnHeadersPresenter>(this);
                if (headersPresenter == null)
                {
                    return;
                }

                var visibleColumns = GetVisibleColumns();
                int totalVisible = visibleColumns.Count;
                if (totalVisible == 0)
                {
                    return;
                }

                // Map visible columns to 1-based positions in visual order
                var positionByColumn = new Dictionary<DataGridColumn, int>(totalVisible);
                for (int i = 0; i < visibleColumns.Count; i++)
                {
                    positionByColumn[visibleColumns[i]] = i + 1;
                }

                // Collect all header containers
                var headerContainers = FindVisualChildren<DataGridColumnHeader>(headersPresenter).ToList();

                // Update each header's UIA position according to its column's position
                foreach (var header in headerContainers)
                {
                    var column = header.Column;
                    if (column == null)
                    {
                        continue;
                    }

                    if (positionByColumn.TryGetValue(column, out int position))
                    {
                        AutomationProperties.SetPositionInSet(header, position);
                        AutomationProperties.SetSizeOfSet(header, totalVisible);
                    }
                    else
                    {
                        // Header for hidden columns should have no index
                        AutomationProperties.SetPositionInSet(header, 0);
                        AutomationProperties.SetSizeOfSet(header, 0);
                    }
                }
            }
            catch
            {
                // Do not allow accessibility updates to break UX
            }
        }

        private List<DataGridColumn> GetVisibleColumns()
        {
            var visibleColumns = new List<DataGridColumn>();
            foreach (var column in Columns)
            {
                if (column.Visibility == Visibility.Visible)
                {
                    visibleColumns.Add(column);
                }
            }

            visibleColumns.Sort((a, b) => a.DisplayIndex.CompareTo(b.DisplayIndex));
            return visibleColumns;
        }
    }
}
