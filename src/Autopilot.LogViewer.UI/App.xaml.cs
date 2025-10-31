using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.IO.Pipes;
using System.Windows;
using Autopilot.LogViewer.UI.ViewModels;

namespace Autopilot.LogViewer.UI
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private const string MutexName = "AutopilotLogViewer_SingleInstance";
        private const string PipeName = "AutopilotLogViewer_Pipe";
        private static Mutex? _singleInstanceMutex;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Single-instance guard
            bool isNew;
            _singleInstanceMutex = new Mutex(true, MutexName, out isNew);

            if (!isNew)
            {
                // Another instance is running — forward file path (if any) and exit
                if (e.Args.Length > 0 && File.Exists(e.Args[0]))
                {
                    try { SendPathToExistingInstance(e.Args[0]); } catch { /* ignore */ }
                }
                Shutdown();
                return;
            }

            // Start named pipe listener to accept file-open requests from subsequent instances
            StartPipeServer();

            // Create or reuse window for initial launch
            var mainWindow = Windows.OfType<Views.MainWindow>().FirstOrDefault();
            if (mainWindow == null)
            {
                mainWindow = new Views.MainWindow();
            }

            if (e.Args.Length > 0 && File.Exists(e.Args[0]) && mainWindow.DataContext is MainViewModel vm)
            {
                vm.FilePath = e.Args[0];
            }

            mainWindow.Show();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            base.OnExit(e);
            try { _singleInstanceMutex?.ReleaseMutex(); } catch { }
            _singleInstanceMutex?.Dispose();
        }

        private static void StartPipeServer()
        {
            Task.Run(async () =>
            {
                while (true)
                {
                    try
                    {
                        using var server = new NamedPipeServerStream(PipeName, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                        await server.WaitForConnectionAsync().ConfigureAwait(false);

                        using var ms = new MemoryStream();
                        await server.CopyToAsync(ms).ConfigureAwait(false);
                        var path = Encoding.UTF8.GetString(ms.ToArray());

                        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
                        {
                            Application.Current.Dispatcher.Invoke(() =>
                            {
                                var existing = Application.Current.Windows.OfType<Views.MainWindow>().FirstOrDefault();
                                if (existing == null)
                                {
                                    existing = new Views.MainWindow();
                                    existing.Show();
                                }

                                if (existing.DataContext is MainViewModel vm)
                                {
                                    vm.FilePath = path;
                                }
                                existing.Activate();
                            });
                        }
                    }
                    catch
                    {
                        // Ignore and continue listening
                        await Task.Delay(250).ConfigureAwait(false);
                    }
                }
            });
        }

        private static void SendPathToExistingInstance(string filePath)
        {
            using var client = new NamedPipeClientStream(".", PipeName, PipeDirection.Out);
            client.Connect(750); // short timeout
            var bytes = Encoding.UTF8.GetBytes(filePath);
            client.Write(bytes, 0, bytes.Length);
            client.Flush();
        }
    }
}
