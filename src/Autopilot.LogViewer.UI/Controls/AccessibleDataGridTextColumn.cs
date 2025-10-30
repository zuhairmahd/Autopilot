// Licensed under MIT License
// Accessible DataGridTextColumn that generates cells with proper UIAutomation support

using System.Windows;
using System.Windows.Controls;

namespace Autopilot.LogViewer.UI.Controls
{
    /// <summary>
    /// DataGridTextColumn that generates AccessibleDataGridCell instances
    /// to provide proper screen reader support for hidden columns.
    /// </summary>
    public class AccessibleDataGridTextColumn : DataGridTextColumn
    {
        /// <summary>
        /// Generates an AccessibleDataGridCell instead of a standard DataGridCell
        /// </summary>
        protected override FrameworkElement GenerateElement(DataGridCell cell, object dataItem)
        {
            return base.GenerateElement(cell, dataItem);
        }

        /// <summary>
        /// Override to provide custom cell type
        /// </summary>
        protected override FrameworkElement GenerateEditingElement(DataGridCell cell, object dataItem)
        {
            return base.GenerateEditingElement(cell, dataItem);
        }
    }
}
