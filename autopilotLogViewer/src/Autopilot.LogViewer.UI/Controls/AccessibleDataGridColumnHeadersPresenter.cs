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
    /// Custom DataGridColumnHeadersPresenter that provides an accessibility-aware automation peer.
    /// Ensures that only visible columns are exposed to UI Automation, in the current DisplayIndex order.
    /// </summary>
    public class AccessibleDataGridColumnHeadersPresenter : DataGridColumnHeadersPresenter
    {
        /// <summary>
        /// Creates the automation peer for the presenter that filters header children by visibility and order.
        /// </summary>
        /// <returns>The automation peer instance.</returns>
        protected override AutomationPeer OnCreateAutomationPeer()
        {
            return new AccessibleDataGridColumnHeadersPresenterAutomationPeer(this);
        }
    }

    /// <summary>
    /// Automation peer for <see cref="AccessibleDataGridColumnHeadersPresenter"/> that rebuilds the header child list
    /// to include only visible columns in DisplayIndex order. This fixes cases where UIA caches header peers when
    /// columns are hidden/shown and navigation becomes out of sync.
    /// </summary>
    public class AccessibleDataGridColumnHeadersPresenterAutomationPeer : FrameworkElementAutomationPeer
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="AccessibleDataGridColumnHeadersPresenterAutomationPeer"/> class.
        /// </summary>
        /// <param name="owner">The presenter that owns this automation peer.</param>
        public AccessibleDataGridColumnHeadersPresenterAutomationPeer(AccessibleDataGridColumnHeadersPresenter owner)
            : base(owner)
        {
        }

        private AccessibleDataGridColumnHeadersPresenter OwningPresenter =>
            (AccessibleDataGridColumnHeadersPresenter)Owner;

        /// <summary>
        /// Returns the list of automation peers for header items, filtered to visible columns and sorted by DisplayIndex.
        /// </summary>
        /// <returns>A list of child automation peers or null if none.</returns>
        protected override List<AutomationPeer>? GetChildrenCore()
        {
            // Get parent DataGrid
            var dataGrid = ItemsControl.ItemsControlFromItemContainer(OwningPresenter) as DataGrid;
            if (dataGrid == null)
            {
                return null;
            }

            // Only visible columns, in DisplayIndex order
            var visibleColumns = dataGrid.Columns
                .Where(c => c.Visibility == Visibility.Visible)
                .OrderBy(c => c.DisplayIndex)
                .ToList();

            if (visibleColumns.Count == 0)
            {
                return null;
            }

            // Find all DataGridColumnHeader visual children under the presenter
            var headerContainers = FindVisualChildren<DataGridColumnHeader>(OwningPresenter).ToList();

            // Create peers for the header containers corresponding to visible columns, in order
            var peers = new List<AutomationPeer>(visibleColumns.Count);
            foreach (var column in visibleColumns)
            {
                var header = headerContainers.FirstOrDefault(h => h.Column == column);
                if (header != null)
                {
                    var peer = UIElementAutomationPeer.CreatePeerForElement(header);
                    if (peer != null)
                    {
                        peers.Add(peer);
                    }
                }
            }

            return peers;
        }

        /// <summary>
        /// Returns the automation control type for the presenter.
        /// </summary>
        protected override AutomationControlType GetAutomationControlTypeCore()
        {
            return AutomationControlType.Header;
        }

        /// <summary>
        /// Returns the class name reported to automation clients.
        /// </summary>
        protected override string GetClassNameCore()
        {
            return "DataGridColumnHeadersPresenter";
        }

        /// <summary>
        /// Header presenter is not a content element; it is a structural container.
        /// </summary>
        protected override bool IsContentElementCore()
        {
            return false;
        }

        private static IEnumerable<TChild> FindVisualChildren<TChild>(DependencyObject parent)
            where TChild : DependencyObject
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
    }
}
