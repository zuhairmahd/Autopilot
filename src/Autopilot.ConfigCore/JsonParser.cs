using System;
using System.Collections;
using System.Collections.Generic;
using System.Text.Json;

namespace Autopilot.ConfigCore
{
    /// <summary>
    /// High-performance JSON parser using System.Text.Json.
    /// 3-5x faster than PowerShell's ConvertFrom-Json cmdlet.
    /// </summary>
    public static class JsonParser
    {
        private static readonly JsonDocumentOptions _documentOptions = new()
        {
            CommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true,
            MaxDepth = 1000  // Increased from 64 to support deeply nested configurations
        };

        /// <summary>
        /// Parses JSON string to PowerShell-compatible Hashtable.
        /// Handles nested objects, arrays, and all JSON primitive types.
        /// </summary>
        /// <param name="json">JSON string to parse</param>
        /// <returns>Hashtable representation of JSON</returns>
        /// <exception cref="ArgumentNullException">If json is null or empty</exception>
        /// <exception cref="JsonException">If JSON is malformed</exception>
        public static Hashtable ParseToHashtable(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                throw new ArgumentNullException(nameof(json), "JSON string cannot be null or empty");

            try
            {
                using var doc = JsonDocument.Parse(json, _documentOptions);
                return ConvertElement(doc.RootElement);
            }
            catch (JsonException ex)
            {
                throw new JsonException($"Failed to parse JSON: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Converts JsonElement to Hashtable (must be an object).
        /// </summary>
        private static Hashtable ConvertElement(JsonElement element)
        {
            if (element.ValueKind != JsonValueKind.Object)
            {
                throw new ArgumentException(
                    $"Root JSON element must be an object, but was {element.ValueKind}");
            }

            var result = new Hashtable(StringComparer.OrdinalIgnoreCase);

            foreach (var property in element.EnumerateObject())
            {
                result[property.Name] = ConvertValue(property.Value);
            }

            return result;
        }

        /// <summary>
        /// Converts JsonElement values to PowerShell-compatible types using iterative approach.
        /// Prevents stack overflow by avoiding recursion for deeply nested structures.
        /// </summary>
        private static object? ConvertValue(JsonElement element)
        {
            // Use explicit stack to avoid recursion and prevent stack overflow
            var workStack = new Stack<(JsonElement Element, object? Container, object Key)>();
            object? result = null;

            // Start with root element
            workStack.Push((element, null, null!));

            while (workStack.Count > 0)
            {
                var (currentElement, container, key) = workStack.Pop();
                object? convertedValue = null;

                switch (currentElement.ValueKind)
                {
                    case JsonValueKind.Object:
                        // Create hashtable for this object
                        var hashtable = new Hashtable(StringComparer.OrdinalIgnoreCase);
                        convertedValue = hashtable;

                        // Queue all properties for processing
                        foreach (var property in currentElement.EnumerateObject())
                        {
                            workStack.Push((property.Value, hashtable, property.Name));
                        }
                        break;

                    case JsonValueKind.Array:
                        // Create array for this collection
                        var arrayLength = currentElement.GetArrayLength();
                        var array = new object?[arrayLength];
                        convertedValue = array;

                        // Queue all array items for processing (in reverse for correct order)
                        int idx = arrayLength - 1;
                        foreach (var item in currentElement.EnumerateArray())
                        {
                            workStack.Push((item, array, idx--));
                        }
                        break;

                    case JsonValueKind.String:
                        convertedValue = currentElement.GetString();
                        break;

                    case JsonValueKind.Number:
                        // Try to preserve integer types when possible
                        if (currentElement.TryGetInt32(out int i32))
                            convertedValue = i32;
                        else if (currentElement.TryGetInt64(out long i64))
                            convertedValue = i64;
                        else
                            convertedValue = currentElement.GetDouble();
                        break;

                    case JsonValueKind.True:
                        convertedValue = true;
                        break;

                    case JsonValueKind.False:
                        convertedValue = false;
                        break;

                    case JsonValueKind.Null:
                        convertedValue = null;
                        break;

                    default:
                        convertedValue = currentElement.ToString();
                        break;
                }

                // Store the converted value in its container
                if (container == null)
                {
                    // Root element
                    result = convertedValue;
                }
                else if (container is Hashtable ht)
                {
                    ht[(string)key] = convertedValue;
                }
                else if (container is object?[] arr)
                {
                    arr[(int)key] = convertedValue;
                }
            }

            return result;
        }

        /// <summary>
        /// Parses JSON with flattening to dot notation (e.g., "parent.child.key").
        /// Useful for configuration merging scenarios.
        /// </summary>
        /// <param name="json">JSON string to parse</param>
        /// <param name="separator">Key separator (default: ".")</param>
        /// <returns>Flattened hashtable</returns>
        public static Hashtable ParseToHashtableFlattened(string json, string separator = ".")
        {
            var hashtable = ParseToHashtable(json);
            return HashtableHelper.Flatten(hashtable, separator);
        }

        /// <summary>
        /// Safely parses JSON with error handling and returns success status.
        /// </summary>
        /// <param name="json">JSON string to parse</param>
        /// <param name="result">Parsed hashtable (null if parsing fails)</param>
        /// <param name="error">Error message (null if parsing succeeds)</param>
        /// <returns>True if parsing succeeded</returns>
        public static bool TryParseToHashtable(string json, out Hashtable? result, out string? error)
        {
            result = null;
            error = null;

            if (string.IsNullOrWhiteSpace(json))
            {
                error = "JSON string is null or empty";
                return false;
            }

            try
            {
                result = ParseToHashtable(json);
                return true;
            }
            catch (JsonException ex)
            {
                error = $"JSON parsing error: {ex.Message}";
                return false;
            }
            catch (Exception ex)
            {
                error = $"Unexpected error: {ex.Message}";
                return false;
            }
        }
    }
}
