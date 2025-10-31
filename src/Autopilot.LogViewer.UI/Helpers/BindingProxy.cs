using System.Windows;

namespace Autopilot.LogViewer.UI.Helpers
{
    /// <summary>
    /// Proxy class to enable binding to DataContext properties from elements
    /// that are not part of the visual tree (like DataGrid columns).
    /// </summary>
    public class BindingProxy : Freezable
    {
        /// <summary>
        /// Gets or sets the data object for binding.
        /// </summary>
        public object Data
        {
            get { return GetValue(DataProperty); }
            set { SetValue(DataProperty, value); }
        }

        /// <summary>
        /// Dependency property for Data.
        /// </summary>
        public static readonly DependencyProperty DataProperty =
            DependencyProperty.Register(nameof(Data), typeof(object), typeof(BindingProxy), new UIPropertyMetadata(null));

        /// <summary>
        /// Creates a new instance of the Freezable derived class.
        /// </summary>
        protected override Freezable CreateInstanceCore()
        {
            return new BindingProxy();
        }
    }
}
