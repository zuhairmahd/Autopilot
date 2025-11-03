using System;

namespace Autopilot.LogViewer.UI.ViewModels
{
    /// <summary>
    /// Represents an individual filter option that can be toggled on or off.
    /// </summary>
    public sealed class FilterOptionViewModel : ViewModelBase
    {
        private readonly Action<FilterOptionViewModel>? _selectionChanged;
        private bool _isSelected;

        public FilterOptionViewModel(
            string name,
            bool isSelected,
            Action<FilterOptionViewModel>? selectionChanged,
            string? automationName = null,
            string? helpText = null)
        {
            Name = name;
            _isSelected = isSelected;
            _selectionChanged = selectionChanged;
            AutomationName = automationName ?? name;
            HelpText = helpText ?? string.Empty;
        }

        /// <summary>
        /// Gets the display name of the filter option.
        /// </summary>
        public string Name { get; }

        /// <summary>
        /// Gets a descriptive name exposed to UI Automation.
        /// </summary>
        public string AutomationName { get; }

        /// <summary>
        /// Gets the help text exposed to UI Automation.
        /// </summary>
        public string HelpText { get; }

        /// <summary>
        /// Gets or sets a value indicating whether the filter option is selected.
        /// </summary>
        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (SetProperty(ref _isSelected, value))
                {
                    _selectionChanged?.Invoke(this);
                }
            }
        }
    }
}
