using System.Windows.Controls;
using System.Windows;

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
    }
}
