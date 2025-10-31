using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Autopilot.LogViewer.Core.Models;

namespace Autopilot.LogViewer.Core.Parsers
{
    /// <summary>
    /// Parser for CMTrace XML log format:
    /// &lt;![LOG[Message]LOG]!&gt;&lt;time="14:23:45.123" date="01-15-2025" component="Module" context="User" type="1" thread="5" file=""&gt;
    /// </summary>
    public class CMTraceLogParser : ILogParser
    {
        // Regex pattern for CMTrace format
        private static readonly Regex LogLineRegex = new Regex(
            @"<!\[LOG\[(.+?)\]LOG\]!><time=""([^""]+)"" date=""([^""]+)"" component=""([^""]+)"" context=""([^""]*)"" type=""(\d+)"" thread=""(\d+)"" file=""[^""]*"">",
            RegexOptions.Compiled | RegexOptions.Singleline
        );

        /// <inheritdoc/>
        public IEnumerable<LogEntry> ParseFile(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException($"Log file not found: {filePath}", filePath);
            }

            var entries = new List<LogEntry>();
            int lineNumber = 0;

            foreach (var line in File.ReadLines(filePath))
            {
                lineNumber++;
                if (TryParseLine(line, lineNumber, out var entry) && entry != null)
                {
                    entries.Add(entry);
                }
            }

            return entries;
        }

        /// <inheritdoc/>
        public bool TryParseLine(string line, int lineNumber, out LogEntry? entry)
        {
            entry = null;

            if (string.IsNullOrWhiteSpace(line))
            {
                return false;
            }

            var match = LogLineRegex.Match(line);
            if (!match.Success)
            {
                return false;
            }

            try
            {
                var message = match.Groups[1].Value;
                var time = match.Groups[2].Value;
                var date = match.Groups[3].Value;
                var component = match.Groups[4].Value;
                var context = match.Groups[5].Value;
                var typeInt = int.Parse(match.Groups[6].Value);
                var threadId = int.Parse(match.Groups[7].Value);

                // Parse timestamp (date format: MM-DD-YYYY, time format: HH:mm:ss.fff)
                var timestamp = DateTime.Parse($"{date} {time}");

                // Map CMTrace type to log level
                var level = typeInt switch
                {
                    1 => "Information",
                    2 => "Warning",
                    3 => "Error",
                    _ => "Verbose"
                };

                entry = new LogEntry
                {
                    Timestamp = timestamp,
                    Level = level,
                    Module = component,
                    ThreadId = threadId,
                    Context = context,
                    Message = message,
                    RawLine = line,
                    LineNumber = lineNumber
                };

                return true;
            }
            catch
            {
                return false;
            }
        }

        /// <inheritdoc/>
        public bool CanParse(IEnumerable<string> sampleLines)
        {
            // Check if at least one line matches the CMTrace format
            return sampleLines
                .Where(line => !string.IsNullOrWhiteSpace(line))
                .Take(10)
                .Any(line => LogLineRegex.IsMatch(line));
        }
    }
}
