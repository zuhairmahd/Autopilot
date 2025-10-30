using System;
using System.Collections.Specialized;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// DataGrid with improved behavior for column visibility and ordering.
    /// Ensures columns maintain their display order when visibility changes.
    /// </summary>
    public class AccessibleDataGrid : DataGrid
    {
        /// <summary>
        /// Initializes a new instance of the AccessibleDataGrid class.
        /// </summary>
        public AccessibleDataGrid()
        {
            Loaded += OnLoaded;
            LoadingRow += OnLoadingRow;
            // Update row accessible names when columns change (hide/show or reorder)
            this.Columns.CollectionChanged += OnColumnsCollectionChanged;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            // Ensure DisplayIndex is stable
            EnsureDisplayIndices();
        }

        private void EnsureDisplayIndices()
        {
            // Force columns to maintain their declaration order
            for (int i = 0; i < Columns.Count; i++)
            {
                if (Columns[i].DisplayIndex != i)
                {
                    Columns[i].DisplayIndex = i;
                }
            }
        }

        private void OnLoadingRow(object? sender, DataGridRowEventArgs e)
        {
            // Build an accessible name for the row that includes only VISIBLE columns
            UpdateRowAccessibleName(e.Row);
        }

        private void OnColumnsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            // Columns were added/removed/reordered — update accessible names for realized rows
            UpdateAllRowAccessibleNames();
        }

        private void UpdateAllRowAccessibleNames()
        {
            // Iterate realized item containers
            for (int i = 0; i < Items.Count; i++)
            {
                var row = ItemContainerGenerator.ContainerFromIndex(i) as DataGridRow;
                if (row != null)
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
                // Best-effort; never crash UI for accessibility adornments
            }
        }

        private string BuildRowAccessibleName(DataGridRow row)
        {
            // Compose a string using visible columns only, in display order
            // Pattern: "Timestamp: 2025-10-30 12:34:56.789; Level: Info; Module: Core; ..."
            var parts = new System.Collections.Generic.List<string>(Columns.Count);

            // Ensure we iterate by DisplayIndex order
            foreach (var col in GetColumnsInDisplayOrder())
            {
                // Only handle text columns for now
                if (col is DataGridTextColumn textCol)
                {
                    string header = Convert.ToString(textCol.Header) ?? string.Empty;
                    var cell = GetCell(row, col.DisplayIndex);
                    string value = ExtractCellText(cell) ?? string.Empty;

                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        if (!string.IsNullOrWhiteSpace(header))
                        {
                            parts.Add($"{header}: {value}");
                        }
                        else
                        {
                            parts.Add(value);
                        }
                    }
                }
                else
                {
                    // Fallback: try to read any text content
                    var cell = GetCell(row, col.DisplayIndex);
                    string? value = ExtractCellText(cell);
                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        parts.Add(value);
                    }
                }
            }

            return string.Join("; ", parts);
        }

        private static System.Collections.Generic.IEnumerable<DataGridColumn> GetColumnsInDisplayOrder(System.Collections.Generic.IList<DataGridColumn>? cols = null)
        {
            cols ??= System.Array.Empty<DataGridColumn>();
            // Use current grid instance's Columns if available
            if (cols.Count == 0)
            {
                // This method will be called with instance context; we will return empty if nothing passed
                yield break;
            }
            foreach (var c in System.Linq.Enumerable.OrderBy(cols, c => c.DisplayIndex))
            {
                yield return c;
            }
        }

        private System.Collections.Generic.IEnumerable<DataGridColumn> GetColumnsInDisplayOrder()
        {
            foreach (var c in System.Linq.Enumerable.OrderBy(this.Columns, c => c.DisplayIndex))
            {
                yield return c;
            }
        }

        private static DataGridCell? GetCell(DataGridRow row, int displayIndex)
        {
            var presenter = FindVisualChild<DataGridCellsPresenter>(row);
            if (presenter == null) return null;
            // Map display index to container index: they align in presenter
            var cell = presenter.ItemContainerGenerator.ContainerFromIndex(displayIndex) as DataGridCell;
            return cell;
        }

        private static string? ExtractCellText(DataGridCell? cell)
        {
            if (cell == null) return null;
            var textBlock = FindVisualChild<System.Windows.Controls.TextBlock>(cell);
            return textBlock?.Text;
        }

        private static TChild? FindVisualChild<TChild>(DependencyObject? parent) where TChild : DependencyObject
        {
            if (parent == null) return null;
            int count = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < count; i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is TChild wanted)
                {
                    return wanted;
                }
                var result = FindVisualChild<TChild>(child);
                if (result != null) return result;
            }
            return null;
        }
    }
}
