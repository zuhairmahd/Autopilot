using System.Windows.Input;

namespace Autopilot.LogViewer.UI.Commands
{
    /// <summary>
    /// Routed commands that drive column reordering actions from multiple entry points.
    /// </summary>
    public static class ColumnReorderCommands
    {
        public static readonly RoutedUICommand MoveColumnToBeginning = new(
            "Move Column to Beginning",
            nameof(MoveColumnToBeginning),
            typeof(ColumnReorderCommands),
            new InputGestureCollection
            {
                new KeyGesture(Key.Home, ModifierKeys.Control | ModifierKeys.Shift)
            });

        public static readonly RoutedUICommand MoveColumnLeft = new(
            "Move Column Left",
            nameof(MoveColumnLeft),
            typeof(ColumnReorderCommands),
            new InputGestureCollection
            {
                new KeyGesture(Key.Left, ModifierKeys.Control | ModifierKeys.Shift)
            });

        public static readonly RoutedUICommand MoveColumnRight = new(
            "Move Column Right",
            nameof(MoveColumnRight),
            typeof(ColumnReorderCommands),
            new InputGestureCollection
            {
                new KeyGesture(Key.Right, ModifierKeys.Control | ModifierKeys.Shift)
            });

        public static readonly RoutedUICommand MoveColumnToEnd = new(
            "Move Column to End",
            nameof(MoveColumnToEnd),
            typeof(ColumnReorderCommands),
            new InputGestureCollection
            {
                new KeyGesture(Key.End, ModifierKeys.Control | ModifierKeys.Shift)
            });

        public static readonly RoutedUICommand ResetColumnOrder = new(
            "Reset Column Order",
            nameof(ResetColumnOrder),
            typeof(ColumnReorderCommands));
    }
}
