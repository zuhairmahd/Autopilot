using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Autopilot.LogViewer.Core.Parsers
{
    /// <summary>
    /// Factory for creating appropriate log parsers based on file content.
    /// </summary>
    public static class LogParserFactory
    {
        private static readonly ILogParser[] AvailableParsers = new ILogParser[]
        {
            new StandardLogParser(),
            new CMTraceLogParser()
        };

        /// <summary>
        /// Detects the appropriate parser for a log file.
        /// </summary>
        /// <param name="filePath">The path to the log file.</param>
        /// <returns>An appropriate parser, or null if no parser can handle the format.</returns>
        public static ILogParser? DetectParser(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException($"Log file not found: {filePath}", filePath);
            }

            // Read first 20 lines as sample
            var sampleLines = File.ReadLines(filePath).Take(20).ToList();

            // Try each parser
            foreach (var parser in AvailableParsers)
            {
                if (parser.CanParse(sampleLines))
                {
                    return parser;
                }
            }

            return null;
        }

        /// <summary>
        /// Gets a parser by name.
        /// </summary>
        /// <param name="parserName">The name of the parser (e.g., "Standard", "CMTrace").</param>
        /// <returns>The requested parser, or null if not found.</returns>
        public static ILogParser? GetParser(string parserName)
        {
            return parserName?.ToLowerInvariant() switch
            {
                "standard" => new StandardLogParser(),
                "cmtrace" => new CMTraceLogParser(),
                _ => null
            };
        }

        /// <summary>
        /// Gets all available parsers.
        /// </summary>
        /// <returns>A collection of available parsers.</returns>
        public static IEnumerable<ILogParser> GetAllParsers()
        {
            return AvailableParsers;
        }
    }
}
