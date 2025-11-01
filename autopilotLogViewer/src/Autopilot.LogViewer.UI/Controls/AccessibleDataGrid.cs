using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Automation.Peers;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// DataGrid with improved behavior for column visibility and ordering.
    /// Uses native WPF accessibility with minimal augmentation.
    /// </summary>
    public class AccessibleDataGrid : DataGrid
    {
        private static readonly DependencyProperty HandlersAttachedProperty =
            DependencyProperty.RegisterAttached(
                "HandlersAttached",
                typeof(bool),
                typeof(AccessibleDataGrid),
                new PropertyMetadata(false));
        private static readonly PropertyInfo? ColumnHeaderPropertyInfo =
            typeof(DataGridColumn).GetProperty(
                "ColumnHeader",
                BindingFlags.NonPublic | BindingFlags.Instance);
        public static readonly DependencyProperty IncludeHeadersInRowAutomationNameProperty =
            DependencyProperty.Register(
                nameof(IncludeHeadersInRowAutomationName),
                typeof(bool),
                typeof(AccessibleDataGrid),
                new PropertyMetadata(false, OnIncludeHeadersInRowAutomationNameChanged));

        public AccessibleDataGrid()
        {
            Columns.CollectionChanged += OnColumnsCollectionChanged;
            Loaded += OnGridLoaded;
            LoadingRow += OnLoadingRow;
        }

        public bool IncludeHeadersInRowAutomationName
        {
            get => (bool)GetValue(IncludeHeadersInRowAutomationNameProperty);
            set => SetValue(IncludeHeadersInRowAutomationNameProperty, value);
        }

        private static void OnIncludeHeadersInRowAutomationNameChanged(
            DependencyObject d,
            DependencyPropertyChangedEventArgs e)
        {
            if (d is AccessibleDataGrid grid)
            {
                grid.UpdateAutomationProperties();
            }
        }

        protected override AutomationPeer OnCreateAutomationPeer()
        {
            return new DataGridAutomationPeer(this);
        }

        protected override DependencyObject GetContainerForItemOverride()
        {
            return new AccessibleDataGridRow();
        }

        protected override bool IsItemItsOwnContainerOverride(object item)
        {
            return item is AccessibleDataGridRow || base.IsItemItsOwnContainerOverride(item);
        }

        private void OnGridLoaded(object sender, RoutedEventArgs e)
        {
            AttachColumnPropertyHandlers();
            UpdateAutomationProperties();
        }

        private void OnColumnsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            AttachColumnPropertyHandlers(e.NewItems);
            UpdateAutomationProperties();
        }

        private void OnColumnDisplayIndexChanged(object? sender, EventArgs e)
        {
            UpdateAutomationProperties();

            // Notify UI Automation clients that the structure has changed.
            if (AutomationPeer.ListenerExists(AutomationEvents.StructureChanged))
            {
                if (UIElementAutomationPeer.CreatePeerForElement(this) is AutomationPeer peer)
                {
                    peer.RaiseAutomationEvent(AutomationEvents.StructureChanged);
                }
            }
        }

        private void OnColumnVisibilityChanged(object? sender, EventArgs e)
        {
            UpdateAutomationProperties();

            // Notify UI Automation clients that the structure has changed.
            if (AutomationPeer.ListenerExists(AutomationEvents.StructureChanged))
            {
                if (UIElementAutomationPeer.CreatePeerForElement(this) is AutomationPeer peer)
                {
                    peer.RaiseAutomationEvent(AutomationEvents.StructureChanged);
                }
            }
        }

        private void OnLoadingRow(object? sender, DataGridRowEventArgs e)
        {
            if (e.Row != null)
            {
                UpdateAutomationPropertiesForRow(e.Row);
            }
        }

        private void UpdateAutomationProperties()
        {
            var visibleColumns = GetVisibleColumnsInDisplayOrder();
            var positions = visibleColumns
                .Select((column, index) => (column, index))
                .ToDictionary(entry => entry.column, entry => entry.index);
            var visibleCount = visibleColumns.Count;

            foreach (DataGridColumn column in Columns)
            {
                UpdateColumnHeaderAutomationProperties(column, positions, visibleCount);
            }

            for (var i = 0; i < Items.Count; i++)
            {
                if (ItemContainerGenerator.ContainerFromIndex(i) is DataGridRow row)
                {
                    ApplyAutomationPropertiesToRow(
                        row,
                        positions,
                        visibleCount,
                        IncludeHeadersInRowAutomationName);
                }
            }
        }

        private void UpdateAutomationPropertiesForRow(DataGridRow row)
        {
            if (row.Item is null)
            {
                return;
            }

            var visibleColumns = GetVisibleColumnsInDisplayOrder();
            var positions = visibleColumns
                .Select((column, index) => (column, index))
                .ToDictionary(entry => entry.column, entry => entry.index);
            ApplyAutomationPropertiesToRow(
                row,
                positions,
                visibleColumns.Count,
                IncludeHeadersInRowAutomationName);
        }

        private void UpdateColumnHeaderAutomationProperties(
            DataGridColumn column,
            IReadOnlyDictionary<DataGridColumn, int> positions,
            int visibleCount)
        {
            var columnHeader = GetColumnHeader(column);
            if (columnHeader == null)
            {
                return;
            }

            if (positions.TryGetValue(column, out var position))
            {
                AutomationProperties.SetPositionInSet(columnHeader, position + 1);
                AutomationProperties.SetSizeOfSet(columnHeader, visibleCount);
            }
            else
            {
                AutomationProperties.SetPositionInSet(columnHeader, 0);
                AutomationProperties.SetSizeOfSet(columnHeader, 0);
            }
        }

        private void ApplyAutomationPropertiesToRow(
            DataGridRow row,
            IReadOnlyDictionary<DataGridColumn, int> positions,
            int visibleCount,
            bool includeHeadersInRowName)
        {
            row.ApplyTemplate();
            var segments = new List<(int position, string header, string value)>();

            foreach (DataGridColumn column in Columns)
            {
                var cell = GetCell(row, column);
                if (cell == null)
                {
                    continue;
                }

                if (positions.TryGetValue(column, out var position))
                {
                    AutomationProperties.SetPositionInSet(cell, position + 1);
                    AutomationProperties.SetSizeOfSet(cell, visibleCount);

                    var headerText = GetColumnHeaderText(column);
                    var cellText = GetCellAutomationName(cell);
                    segments.Add((position, headerText, cellText));
                }
                else
                {
                    AutomationProperties.SetPositionInSet(cell, 0);
                    AutomationProperties.SetSizeOfSet(cell, 0);
                }
            }

            UpdateRowAutomationName(row, segments, includeHeadersInRowName);
        }

        private List<DataGridColumn> GetVisibleColumnsInDisplayOrder()
        {
            return Columns
                .Where(c => c.Visibility == Visibility.Visible && c.DisplayIndex >= 0)
                .OrderBy(c => c.DisplayIndex)
                .ToList();
        }

        private static DataGridColumnHeader? GetColumnHeader(DataGridColumn column)
        {
            return ColumnHeaderPropertyInfo?.GetValue(column) as DataGridColumnHeader;
        }

        private static DataGridCell? GetCell(DataGridRow row, DataGridColumn column)
        {
            if (column.GetCellContent(row) is FrameworkElement content)
            {
                return content.GetVisualParent<DataGridCell>();
            }

            return null;
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

        private static void UpdateRowAutomationName(
            DataGridRow row,
            List<(int position, string header, string value)> segments,
            bool includeHeaders)
        {
            if (segments.Count == 0)
            {
                AutomationProperties.SetName(row, string.Empty);
                return;
            }

            segments.Sort((left, right) => left.position.CompareTo(right.position));

            var builder = new StringBuilder();
            foreach (var segment in segments)
            {
                var header = segment.header?.Trim();
                var value = segment.value?.Trim();

                if (string.IsNullOrEmpty(header) && string.IsNullOrEmpty(value))
                {
                    continue;
                }

                if (builder.Length > 0)
                {
                    builder.Append(", ");
                }

                if (includeHeaders)
                {
                    if (string.IsNullOrEmpty(header))
                    {
                        builder.Append(value);
                    }
                    else if (string.IsNullOrEmpty(value))
                    {
                        builder.Append(header);
                    }
                    else
                    {
                        builder.Append(header);
                        builder.Append(": ");
                        builder.Append(value);
                    }
                }
                else
                {
                    if (!string.IsNullOrEmpty(value))
                    {
                        builder.Append(value);
                    }
                    else if (!string.IsNullOrEmpty(header))
                    {
                        builder.Append(header);
                    }
                }
            }

            AutomationProperties.SetName(row, builder.ToString());
        }

        private static string GetColumnHeaderText(DataGridColumn column)
        {
            if (GetColumnHeader(column) is DataGridColumnHeader columnHeader)
            {
                var headerContent = columnHeader.Content;
                if (headerContent is string text)
                {
                    return text;
                }

                if (headerContent is TextBlock textBlock)
                {
                    return textBlock.Text;
                }

                if (headerContent is FrameworkElement element)
                {
                    var peer = UIElementAutomationPeer.CreatePeerForElement(element);
                    var name = peer?.GetName();
                    if (!string.IsNullOrWhiteSpace(name))
                    {
                        return name;
                    }
                }

                return headerContent?.ToString() ?? string.Empty;
            }

            if (column.Header is string headerString)
            {
                return headerString;
            }

            if (column.Header is TextBlock headerTextBlock)
            {
                return headerTextBlock.Text;
            }

            if (column.Header is FrameworkElement headerElement)
            {
                var peer = UIElementAutomationPeer.CreatePeerForElement(headerElement);
                var name = peer?.GetName();
                if (!string.IsNullOrWhiteSpace(name))
                {
                    return name;
                }
            }

            return column.Header?.ToString() ?? string.Empty;
        }

        private static string GetCellAutomationName(DataGridCell cell)
        {
            if (UIElementAutomationPeer.CreatePeerForElement(cell) is AutomationPeer cellPeer)
            {
                var name = cellPeer.GetName();
                if (!string.IsNullOrWhiteSpace(name))
                {
                    return name;
                }
            }

            var content = cell.Content;
            if (content is string contentString)
            {
                return contentString;
            }

            if (content is TextBlock textBlock)
            {
                return textBlock.Text;
            }

            if (content is CheckBox checkBox)
            {
                return checkBox.IsChecked switch
                {
                    true => "Checked",
                    false => "Unchecked",
                    _ => "Indeterminate",
                };
            }

            if (content is ContentPresenter presenter)
            {
                var presenterText = GetContentPresenterText(presenter);
                if (!string.IsNullOrWhiteSpace(presenterText))
                {
                    return presenterText;
                }
            }

            if (content is FrameworkElement element)
            {
                var peer = UIElementAutomationPeer.CreatePeerForElement(element);
                var name = peer?.GetName();
                if (!string.IsNullOrWhiteSpace(name))
                {
                    return name;
                }
            }

            return content?.ToString() ?? string.Empty;
        }

        private static string GetContentPresenterText(ContentPresenter presenter)
        {
            var content = presenter.Content;
            if (content is string text)
            {
                return text;
            }

            if (content is TextBlock textBlock)
            {
                return textBlock.Text;
            }

            if (content is FrameworkElement element)
            {
                var peer = UIElementAutomationPeer.CreatePeerForElement(element);
                var name = peer?.GetName();
                if (!string.IsNullOrWhiteSpace(name))
                {
                    return name;
                }
            }

            return content?.ToString() ?? string.Empty;
        }
    }

    internal sealed class AccessibleDataGridRow : DataGridRow
    {
#if !NET9_0_OR_GREATER
        protected override AutomationPeer OnCreateAutomationPeer()
        {
            return new AccessibleDataGridRowAutomationPeer(this);
        }
#endif
    }

#if !NET9_0_OR_GREATER
    internal sealed class AccessibleDataGridRowAutomationPeer : DataGridRowAutomationPeer
    {
        public AccessibleDataGridRowAutomationPeer(DataGridRow owner)
            : base(owner)
        {
        }

        protected override List<AutomationPeer>? GetChildrenCore()
        {
            var children = base.GetChildrenCore();
            if (children == null || children.Count == 0)
            {
                return children;
            }

            var rowHeaderPeers = new List<AutomationPeer>();
            var cellPeers = new List<(AutomationPeer peer, int position)>();
            var otherPeers = new List<AutomationPeer>();

            foreach (var child in children)
            {
                if (child is FrameworkElementAutomationPeer frameworkElementPeer)
                {
                    if (frameworkElementPeer.Owner is DataGridRowHeader)
                    {
                        rowHeaderPeers.Add(child);
                        continue;
                    }

                    if (frameworkElementPeer.Owner is FrameworkElement element)
                    {
                        var position = AutomationProperties.GetPositionInSet(element);
                        if (position > 0)
                        {
                            cellPeers.Add((child, position));
                            continue;
                        }
                    }
                }

                otherPeers.Add(child);
            }

            if (cellPeers.Count == 0)
            {
                return children;
            }

            cellPeers.Sort((left, right) => left.position.CompareTo(right.position));

            var ordered = new List<AutomationPeer>(children.Count);
            ordered.AddRange(rowHeaderPeers);
            ordered.AddRange(cellPeers.Select(tuple => tuple.peer));
            ordered.AddRange(otherPeers);
            return ordered;
        }
    }
#endif

    internal static class VisualTreeHelpers
    {
        internal static T? GetVisualChild<T>(this DependencyObject parent) where T : Visual
        {
            T? child = default(T);
            var numVisuals = VisualTreeHelper.GetChildrenCount(parent);
            for (var i = 0; i < numVisuals; i++)
            {
                var v = (Visual)VisualTreeHelper.GetChild(parent, i);
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

        internal static T? GetVisualParent<T>(this DependencyObject child) where T : DependencyObject
        {
            var current = child;
            while (current != null)
            {
                var parent = GetParent(current);
                if (parent is T typed)
                {
                    return typed;
                }

                current = parent;
            }

            return null;
        }

        private static DependencyObject? GetParent(DependencyObject child)
        {
            if (child is FrameworkElement fe)
            {
                var parent = fe.Parent ?? fe.TemplatedParent;
                if (parent != null)
                {
                    return parent;
                }
            }

            if (child is FrameworkContentElement fce)
            {
                var parent = fce.Parent ?? fce.TemplatedParent;
                if (parent != null)
                {
                    return parent;
                }
            }

            return VisualTreeHelper.GetParent(child);
        }
    }
}
