using System;
using System.Collections.Concurrent;
using System.IO;

namespace Autopilot.ConfigCore
{
    /// <summary>
    /// Tracks configuration file metadata for efficient change detection.
    /// Avoids unnecessary file parsing when files haven't changed.
    /// </summary>
    public static class ConfigFileWatcher
    {
        private static readonly ConcurrentDictionary<string, FileMetadata> _metadata = new();

        /// <summary>
        /// Checks if a file has changed since last check.
        /// Uses LastWriteTimeUtc and file length for fast detection.
        /// </summary>
        /// <param name="filePath">Absolute path to configuration file</param>
        /// <returns>True if file has changed or is being tracked for the first time</returns>
        public static bool HasChanged(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
                throw new ArgumentNullException(nameof(filePath));

            if (!File.Exists(filePath))
            {
                // File doesn't exist - consider it changed
                return true;
            }

            var currentInfo = new FileInfo(filePath);
            string key = NormalizeFilePath(filePath);

            if (_metadata.TryGetValue(key, out var cached))
            {
                // Compare timestamps and size
                bool changed = cached.LastWriteTimeUtc != currentInfo.LastWriteTimeUtc ||
                              cached.Length != currentInfo.Length;

                return changed;
            }

            // First time seeing this file - record metadata
            _metadata[key] = new FileMetadata
            {
                LastWriteTimeUtc = currentInfo.LastWriteTimeUtc,
                Length = currentInfo.Length
            };

            return true; // Changed (first load)
        }

        /// <summary>
        /// Updates the tracked metadata for a file after loading.
        /// Call this after successfully loading/parsing a configuration file.
        /// </summary>
        /// <param name="filePath">Absolute path to configuration file</param>
        public static void UpdateMetadata(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
                throw new ArgumentNullException(nameof(filePath));

            if (!File.Exists(filePath))
                return;

            var info = new FileInfo(filePath);
            string key = NormalizeFilePath(filePath);

            _metadata[key] = new FileMetadata
            {
                LastWriteTimeUtc = info.LastWriteTimeUtc,
                Length = info.Length
            };
        }

        /// <summary>
        /// Clears all tracked file metadata.
        /// Useful for testing or forcing full reload.
        /// </summary>
        public static void ClearAll()
        {
            _metadata.Clear();
        }

        /// <summary>
        /// Removes metadata tracking for a specific file.
        /// </summary>
        /// <param name="filePath">Absolute path to configuration file</param>
        /// <returns>True if metadata was removed</returns>
        public static bool Remove(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
                return false;

            string key = NormalizeFilePath(filePath);
            return _metadata.TryRemove(key, out _);
        }

        /// <summary>
        /// Gets the count of tracked files.
        /// </summary>
        public static int TrackedFileCount => _metadata.Count;

        /// <summary>
        /// Normalizes file path for consistent dictionary lookups.
        /// </summary>
        private static string NormalizeFilePath(string filePath)
        {
            // Use full path and lowercase for case-insensitive comparison
            return Path.GetFullPath(filePath).ToLowerInvariant();
        }

        /// <summary>
        /// Internal metadata structure for file tracking.
        /// </summary>
        private class FileMetadata
        {
            public DateTime LastWriteTimeUtc { get; set; }
            public long Length { get; set; }
        }
    }
}
