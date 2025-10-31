// Licensed under MIT License
// Accessible DataGridCell with proper UIAutomation support for hidden columns

using System.Windows;
using System.Windows.Automation.Peers;
using System.Windows.Controls;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// Custom DataGridCell that provides proper accessibility support for hidden columns.
    /// When a column is hidden (Width=0), this cell is excluded from the UIAutomation Control view,
    /// preventing screen readers from announcing it.
    /// </summary>
    public class AccessibleDataGridCell : DataGridCell
    {
        protected override AutomationPeer OnCreateAutomationPeer()
        {
            return new AccessibleDataGridCellAutomationPeer(this);
        }

        /// <summary>
        /// Checks if this cell's column is currently visible (Width > 0)
        /// </summary>
        internal bool IsColumnVisible()
        {
            if (Column != null)
            {
                return Column.Width.Value > 0;
            }
            return true; // Default to visible if no column reference
        }
    }

    /// <summary>
    /// Custom AutomationPeer for AccessibleDataGridCell that excludes hidden columns
    /// from the UIAutomation Control view and Content view.
    /// </summary>
    public class AccessibleDataGridCellAutomationPeer : FrameworkElementAutomationPeer
    {
        private AccessibleDataGridCell OwningCell => (AccessibleDataGridCell)Owner;

        public AccessibleDataGridCellAutomationPeer(AccessibleDataGridCell owner)
            : base(owner)
        {
        }

        protected override string GetClassNameCore()
        {
            return "DataGridCell";
        }

        protected override AutomationControlType GetAutomationControlTypeCore()
        {
            return AutomationControlType.Custom;
        }

        /// <summary>
        /// Determines if this cell should be included in the UIAutomation Control view.
        /// Returns false when the column is hidden (Width=0), which causes screen readers
        /// to skip this cell during navigation.
        /// </summary>
        protected override bool IsControlElementCore()
        {
            // Only include in Control view if the column is visible
            return OwningCell.IsColumnVisible();
        }

        /// <summary>
        /// Determines if this cell should be included in the UIAutomation Content view.
        /// Returns false when the column is hidden (Width=0).
        /// </summary>
        protected override bool IsContentElementCore()
        {
            // Only include in Content view if the column is visible
            return OwningCell.IsColumnVisible();
        }
    }
}
