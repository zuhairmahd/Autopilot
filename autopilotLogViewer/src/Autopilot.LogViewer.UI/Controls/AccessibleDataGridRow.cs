using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Automation.Peers;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// Custom DataGridRow that exposes a tailored UI Automation peer to ensure
    /// only visible columns are exposed and in the same order as displayed.
    /// </summary>
    public class AccessibleDataGridRow : DataGridRow
    {
        protected override AutomationPeer OnCreateAutomationPeer()
        {
            return new AccessibleDataGridRowAutomationPeer(this);
        }
    }

    /// <summary>
    /// Automation peer for AccessibleDataGridRow that enumerates child cells
    /// in display order and excludes hidden columns from the Control view.
    /// </summary>
    public class AccessibleDataGridRowAutomationPeer : FrameworkElementAutomationPeer
    {
        public AccessibleDataGridRowAutomationPeer(AccessibleDataGridRow owner) : base(owner)
        {
        }

        protected override List<AutomationPeer>? GetChildrenCore()
        {
            var children = base.GetChildrenCore() ?? new List<AutomationPeer>();

            // Try to reorder/filter the cell peers based on column visibility and DisplayIndex
            var row = (AccessibleDataGridRow)Owner;
            var dataGrid = ItemsControl.ItemsControlFromItemContainer(row) as DataGrid;
            if (dataGrid == null)
            {
                return children;
            }

            // Find the presenter hosting cells
            var presenter = FindVisualChild<DataGridCellsPresenter>(row);
            if (presenter == null)
            {
                return children;
            }

            // Build a list of visible columns in display order
            var visibleColumns = dataGrid.Columns
                .Where(c => c.Visibility == Visibility.Visible)
                .OrderBy(c => c.DisplayIndex)
                .ToList();

            var orderedPeers = new List<AutomationPeer>(visibleColumns.Count);
            foreach (var column in visibleColumns)
            {
                int columnIndex = dataGrid.Columns.IndexOf(column);
                if (columnIndex < 0)
                {
                    continue;
                }

                var cell = presenter.ItemContainerGenerator.ContainerFromIndex(columnIndex) as DataGridCell;
                if (cell == null)
                {
                    continue;
                }

                var peer = UIElementAutomationPeer.CreatePeerForElement(cell);
                if (peer != null)
                {
                    orderedPeers.Add(peer);
                }
            }

            return orderedPeers;
        }

        protected override AutomationControlType GetAutomationControlTypeCore()
        {
            // A row is treated as a data item in a grid
            return AutomationControlType.DataItem;
        }

        protected override string GetClassNameCore()
        {
            return "DataGridRow";
        }

        private static TChild? FindVisualChild<TChild>(DependencyObject parent) where TChild : DependencyObject
        {
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
    }
}
