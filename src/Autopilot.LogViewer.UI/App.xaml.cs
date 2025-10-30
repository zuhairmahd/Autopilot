using System;
using System.IO;
using System.Windows;
using Autopilot.LogViewer.UI.ViewModels;

namespace Autopilot.LogViewer.UI
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Handle command-line arguments (optional log file path)
            if (e.Args.Length > 0 && File.Exists(e.Args[0]))
            {
                var mainWindow = new Views.MainWindow();
                if (mainWindow.DataContext is MainViewModel viewModel)
                {
                    viewModel.FilePath = e.Args[0];
                }
                mainWindow.Show();
            }
            else
            {
                // Show main window normally
                var mainWindow = new Views.MainWindow();
                mainWindow.Show();
            }
        }
    }
}
