using System;
using System.Collections.Concurrent;
using System.IO;
using System.Text;
using System.Threading;

namespace Autopilot.LogCore
{
    /// <summary>
    /// High-performance logging engine with support for synchronous and asynchronous operations.
    /// Thread-safe, supports CMTrace format, log rotation, and multiple log levels.
    /// Compatible with both PowerShell 5.1 (.NET Framework 4.8) and PowerShell 7+ (.NET 9.0).
    /// </summary>
    public class Logger
    {
        private readonly string _logFilePath;
        private readonly int _maxLogSizeMB;
        private readonly LogLevel _minimumLogLevel;
        private readonly bool _useCMTraceFormat;
        private readonly ConcurrentQueue<LogEntry> _asyncQueue;
        private readonly Thread? _asyncThread;
        private readonly AutoResetEvent _asyncSignal;
        private bool _isShuttingDown;
        private long _totalEnqueued;
        private long _totalProcessed;

        public enum LogLevel
        {
            Error = 1,
            Warning = 2,
            Information = 3,
            Verbose = 4,
            Debug = 5
        }

        public Logger(string logFilePath, LogLevel minimumLogLevel = LogLevel.Information,
                      bool useCMTraceFormat = false, int maxLogSizeMB = 10, bool enableAsync = false)
        {
            _logFilePath = logFilePath ?? throw new ArgumentNullException(nameof(logFilePath));
            _minimumLogLevel = minimumLogLevel;
            _useCMTraceFormat = useCMTraceFormat;
            _maxLogSizeMB = maxLogSizeMB;
            _asyncQueue = new ConcurrentQueue<LogEntry>();
            _asyncSignal = new AutoResetEvent(false);
            _isShuttingDown = false;
            _totalEnqueued = 0;
            _totalProcessed = 0;

            // Ensure log directory exists
            var logDirectory = Path.GetDirectoryName(_logFilePath);
            if (!string.IsNullOrEmpty(logDirectory) && !Directory.Exists(logDirectory))
            {
                Directory.CreateDirectory(logDirectory);
            }

            // Start async logging thread if enabled
            if (enableAsync)
            {
                _asyncThread = new Thread(ProcessAsyncLogQueue)
                {
                    IsBackground = true,
                    Name = "AutopilotAsyncLogger"
                };
                _asyncThread.Start();
            }
        }

        /// <summary>
        /// Write a log entry synchronously (thread-safe)
        /// </summary>
        public void WriteLog(string module, string message, LogLevel level = LogLevel.Information)
        {
            if (level > _minimumLogLevel)
                return;

            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Module = module,
                Message = message,
                Level = level,
                ThreadId = Thread.CurrentThread.ManagedThreadId,
                Context = GetContext()
            };

            WriteLogEntry(entry);
        }

        /// <summary>
        /// Write a log entry asynchronously (non-blocking)
        /// </summary>
        public void WriteLogAsync(string module, string message, LogLevel level = LogLevel.Information)
        {
            if (level > _minimumLogLevel)
                return;

            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Module = module,
                Message = message,
                Level = level,
                ThreadId = Thread.CurrentThread.ManagedThreadId,
                Context = GetContext()
            };

            if (_asyncThread != null && !_isShuttingDown)
            {
                _asyncQueue.Enqueue(entry);
                Interlocked.Increment(ref _totalEnqueued);
                _asyncSignal.Set();
            }
            else
            {
                // Fallback to synchronous if async not available
                WriteLogEntry(entry);
            }
        }

        /// <summary>
        /// Write a separator line to the log
        /// </summary>
        public void WriteSeparator()
        {
            var separator = new string('=', 80);
            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Module = "Separator",
                Message = separator,
                Level = LogLevel.Information,
                ThreadId = Thread.CurrentThread.ManagedThreadId,
                Context = string.Empty
            };

            WriteLogEntry(entry);
        }

        /// <summary>
        /// Gracefully shutdown async logging and flush queue
        /// </summary>
        public void Shutdown(int timeoutSeconds = 10)
        {
            if (_asyncThread == null)
                return;

            _isShuttingDown = true;
            _asyncSignal.Set();

            if (!_asyncThread.Join(TimeSpan.FromSeconds(timeoutSeconds)))
            {
                // Force abort if timeout exceeded
#pragma warning disable SYSLIB0006 // Thread.Abort is obsolete in .NET 5+, but we need PS 5.1 compat
                // Note: Thread.Abort only called in .NET Framework path, safe in our use case
                try { _asyncThread.Abort(); } catch { /* Best effort */ }
#pragma warning restore SYSLIB0006
            }
        }

        /// <summary>
        /// Get logging statistics
        /// </summary>
        public LogStatistics GetStatistics()
        {
            return new LogStatistics
            {
                TotalEnqueued = Interlocked.Read(ref _totalEnqueued),
                TotalProcessed = Interlocked.Read(ref _totalProcessed),
                QueueSize = _asyncQueue.Count,
                IsAsyncEnabled = _asyncThread != null
            };
        }

        private void WriteLogEntry(LogEntry entry)
        {
            try
            {
                CheckAndRotateLog();

                var logLine = _useCMTraceFormat
                    ? FormatCMTrace(entry)
                    : FormatStandard(entry);

                // Thread-safe file write using lock
                lock (_logFilePath)
                {
                    File.AppendAllText(_logFilePath, logLine + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                // Fallback to console if file write fails
                Console.Error.WriteLine($"Logging failed: {ex.Message}");
                Console.WriteLine($"{entry.Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{entry.Level}] [{entry.Module}] {entry.Message}");
            }
        }

        private void ProcessAsyncLogQueue()
        {
            var batch = new System.Collections.Generic.List<LogEntry>();

            while (!_isShuttingDown || !_asyncQueue.IsEmpty)
            {
                // Wait for signal or timeout
                _asyncSignal.WaitOne(500);

                // Process available entries in batches
                while (_asyncQueue.TryDequeue(out var entry) && batch.Count < 100)
                {
                    batch.Add(entry);
                }

                // Write batch if we have entries
                if (batch.Count > 0)
                {
                    try
                    {
                        CheckAndRotateLog();

                        var sb = new StringBuilder();
                        foreach (var entry in batch)
                        {
                            var logLine = _useCMTraceFormat
                                ? FormatCMTrace(entry)
                                : FormatStandard(entry);
                            sb.AppendLine(logLine);
                        }

                        lock (_logFilePath)
                        {
                            File.AppendAllText(_logFilePath, sb.ToString(), Encoding.UTF8);
                        }

                        Interlocked.Add(ref _totalProcessed, batch.Count);
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"Async logging batch failed: {ex.Message}");
                    }

                    batch.Clear();
                }
            }

            // Final flush
            while (_asyncQueue.TryDequeue(out var entry))
            {
                WriteLogEntry(entry);
            }
        }

        private void CheckAndRotateLog()
        {
            if (!File.Exists(_logFilePath))
                return;

            var fileInfo = new FileInfo(_logFilePath);
            if (fileInfo.Length > _maxLogSizeMB * 1024 * 1024)
            {
                var archivePath = _logFilePath.Replace(".log", $"_{DateTime.Now:yyyyMMdd_HHmmss}.log");
                File.Move(_logFilePath, archivePath);
            }
        }

        private string FormatStandard(LogEntry entry)
        {
            return $"{entry.Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{entry.Level}] [{entry.Module}] [Thread:{entry.ThreadId}] [Context:{entry.Context}] {entry.Message}";
        }

        private string FormatCMTrace(LogEntry entry)
        {
            var time = entry.Timestamp.ToString("HH:mm:ss.fff+000");
            var date = entry.Timestamp.ToString("MM-dd-yyyy");
            var severity = entry.Level switch
            {
                LogLevel.Error => 3,
                LogLevel.Warning => 2,
                _ => 1
            };

            return $"<![LOG[{entry.Message}]LOG]!><time=\"{time}\" date=\"{date}\" component=\"{entry.Module}\" context=\"\" type=\"{severity}\" thread=\"{entry.ThreadId}\" file=\"\">";
        }

        private string GetContext()
        {
            try
            {
                return Environment.UserName ?? "Unknown";
            }
            catch
            {
                return "Unknown";
            }
        }

        private class LogEntry
        {
            public DateTime Timestamp { get; set; }
            public string Module { get; set; } = string.Empty;
            public string Message { get; set; } = string.Empty;
            public LogLevel Level { get; set; }
            public int ThreadId { get; set; }
            public string Context { get; set; } = string.Empty;
        }
    }

    public class LogStatistics
    {
        public long TotalEnqueued { get; set; }
        public long TotalProcessed { get; set; }
        public int QueueSize { get; set; }
        public bool IsAsyncEnabled { get; set; }
    }
}
