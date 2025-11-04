using System;

namespace Autopilot.LogViewer.Core.Models
{
    /// <summary>
    /// Represents a single log entry from an Autopilot log file.
    /// </summary>
    public class LogEntry
    {
        /// <summary>
        /// Gets or sets the timestamp when the log entry was created.
        /// </summary>
        public DateTime Timestamp { get; set; }

        /// <summary>
        /// Gets or sets the log level (Error, Warning, Information, Verbose, Debug).
        /// </summary>
        public string Level { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the module or function name that generated the log entry.
        /// </summary>
        public string Module { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the thread ID that generated the log entry.
        /// </summary>
        public int ThreadId { get; set; }

        /// <summary>
        /// Gets or sets the context (typically username or system context).
        /// </summary>
        public string Context { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the log message content.
        /// </summary>
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the raw log line as it appears in the file.
        /// </summary>
        public string RawLine { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the line number in the source file.
        /// </summary>
        public int LineNumber { get; set; }

        /// <summary>
        /// Returns a string representation of the log entry.
        /// </summary>
        public override string ToString()
        {
            return $"{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level}] [{Module}] [Thread:{ThreadId}] [Context:{Context}] {Message}";
        }
    }
}
