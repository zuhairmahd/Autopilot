using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Autopilot.LogViewer.Core.Models;

namespace Autopilot.LogViewer.Core.Parsers
{
    /// <summary>
    /// Parser for standard Autopilot log format:
    /// 2025-01-15 14:23:45.123 [Information] [Get-DeviceInfo] [Thread:5] [Context:SYSTEM] Device query started
    /// </summary>
    public class StandardLogParser : ILogParser
    {
        // Regex pattern for standard log format
        private static readonly Regex LogLineRegex = new Regex(
            @"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(\w+)\] \[([^\]]+)\] \[Thread:(\d+)\] \[Context:([^\]]+)\] (.+)$",
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
                entry = new LogEntry
                {
                    Timestamp = DateTime.Parse(match.Groups[1].Value),
                    Level = match.Groups[2].Value,
                    Module = match.Groups[3].Value,
                    ThreadId = int.Parse(match.Groups[4].Value),
                    Context = match.Groups[5].Value,
                    Message = match.Groups[6].Value,
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
            // Check if at least one line matches the standard format
            return sampleLines
                .Where(line => !string.IsNullOrWhiteSpace(line))
                .Take(10)
                .Any(line => LogLineRegex.IsMatch(line));
        }
    }
}
