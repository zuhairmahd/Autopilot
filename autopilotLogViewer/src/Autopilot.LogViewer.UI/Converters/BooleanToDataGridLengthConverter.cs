using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;

namespace Autopilot.LogViewer.UI.Converters
{
    /// <summary>
    /// Converts Boolean to DataGridLength (width) for column visibility.
    /// True = specified width, False = 0 width (hidden from screen readers).
    /// </summary>
    public class BooleanToDataGridLengthConverter : IValueConverter
    {
        /// <summary>
        /// Converts a Boolean to a DataGridLength.
        /// </summary>
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is bool boolValue)
            {
                if (boolValue)
                {
                    // Parse the parameter as the desired width
                    if (parameter is string widthStr && double.TryParse(widthStr, out double width))
                    {
                        return new DataGridLength(width);
                    }
                    // Special handling for "*" (star sizing)
                    if (parameter is string star && star == "*")
                    {
                        return new DataGridLength(1, DataGridLengthUnitType.Star);
                    }
                    return DataGridLength.Auto;
                }
                else
                {
                    // Hidden: width of 0
                    return new DataGridLength(0);
                }
            }
            return DataGridLength.Auto;
        }

        /// <summary>
        /// Converts a DataGridLength back to a Boolean (not used).
        /// </summary>
        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}
