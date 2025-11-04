using System.Collections.Generic;
using Autopilot.LogViewer.Core.Models;

namespace Autopilot.LogViewer.Core.Parsers
{
    /// <summary>
    /// Interface for log file parsers.
    /// </summary>
    public interface ILogParser
    {
        /// <summary>
        /// Parses a log file and returns a collection of log entries.
        /// </summary>
        /// <param name="filePath">The path to the log file.</param>
        /// <returns>A collection of parsed log entries.</returns>
        IEnumerable<LogEntry> ParseFile(string filePath);

        /// <summary>
        /// Attempts to parse a single line from a log file.
        /// </summary>
        /// <param name="line">The log line to parse.</param>
        /// <param name="lineNumber">The line number in the file.</param>
        /// <param name="entry">The parsed log entry if successful.</param>
        /// <returns>True if the line was successfully parsed; otherwise, false.</returns>
        bool TryParseLine(string line, int lineNumber, out LogEntry? entry);

        /// <summary>
        /// Detects if this parser can handle the specified log file format.
        /// </summary>
        /// <param name="sampleLines">A sample of lines from the log file.</param>
        /// <returns>True if this parser can handle the format; otherwise, false.</returns>
        bool CanParse(IEnumerable<string> sampleLines);
    }
}
