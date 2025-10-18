using System;
using System.Collections;
using System.Collections.Generic;

namespace Autopilot.ConfigCore
{
    /// <summary>
    /// Validates configuration hashtables against schema definitions.
    /// Provides structured error reporting for missing or invalid configuration values.
    /// </summary>
    public static class ConfigValidator
    {
        /// <summary>
        /// Validates a configuration hashtable against a schema.
        /// </summary>
        /// <param name="config">Configuration hashtable to validate</param>
        /// <param name="schema">Schema hashtable defining requirements</param>
        /// <returns>Validation result with errors (if any)</returns>
        public static ValidationResult Validate(Hashtable config, Hashtable schema)
        {
            if (config == null)
                throw new ArgumentNullException(nameof(config));
            if (schema == null)
                throw new ArgumentNullException(nameof(schema));

            var result = new ValidationResult { IsValid = true };

            foreach (DictionaryEntry schemaEntry in schema)
            {
                string key = schemaEntry.Key.ToString()!;

                if (!(schemaEntry.Value is Hashtable requirements))
                    continue;

                // Check if key is required
                bool isRequired = requirements.ContainsKey("required") &&
                                  Convert.ToBoolean(requirements["required"]);

                if (isRequired && !config.ContainsKey(key))
                {
                    result.IsValid = false;
                    result.Errors.Add($"Required key '{key}' is missing");
                    continue;
                }

                if (!config.ContainsKey(key))
                    continue; // Optional key not present - OK

                var value = config[key];

                // Type validation
                if (requirements.ContainsKey("type"))
                {
                    string expectedType = requirements["type"].ToString()!;

                    if (!ValidateType(value, expectedType))
                    {
                        result.IsValid = false;
                        result.Errors.Add(
                            $"Key '{key}' has invalid type. Expected: {expectedType}, Got: {GetTypeName(value)}");
                    }
                }

                // Range validation for numbers
                if (requirements.ContainsKey("min") && IsNumeric(value))
                {
                    double numValue = Convert.ToDouble(value);
                    double min = Convert.ToDouble(requirements["min"]);

                    if (numValue < min)
                    {
                        result.IsValid = false;
                        result.Errors.Add($"Key '{key}' value {numValue} is less than minimum {min}");
                    }
                }

                if (requirements.ContainsKey("max") && IsNumeric(value))
                {
                    double numValue = Convert.ToDouble(value);
                    double max = Convert.ToDouble(requirements["max"]);

                    if (numValue > max)
                    {
                        result.IsValid = false;
                        result.Errors.Add($"Key '{key}' value {numValue} is greater than maximum {max}");
                    }
                }

                // Pattern validation for strings
                if (requirements.ContainsKey("pattern") && value is string strValue)
                {
                    string pattern = requirements["pattern"].ToString()!;

                    try
                    {
                        if (!System.Text.RegularExpressions.Regex.IsMatch(strValue, pattern))
                        {
                            result.IsValid = false;
                            result.Errors.Add($"Key '{key}' value '{strValue}' does not match pattern '{pattern}'");
                        }
                    }
                    catch (Exception ex)
                    {
                        result.Errors.Add($"Key '{key}' pattern validation failed: {ex.Message}");
                    }
                }

                // Enum validation (allowed values)
                if (requirements.ContainsKey("enum") && requirements["enum"] is IEnumerable enumValues)
                {
                    bool found = false;

                    foreach (var enumValue in enumValues)
                    {
                        if (Equals(value, enumValue))
                        {
                            found = true;
                            break;
                        }
                    }

                    if (!found)
                    {
                        result.IsValid = false;
                        result.Errors.Add($"Key '{key}' has invalid value. Must be one of the allowed values.");
                    }
                }
            }

            return result;
        }

        /// <summary>
        /// Validates value type against expected type name.
        /// </summary>
        private static bool ValidateType(object? value, string expectedType)
        {
            if (value == null)
                return expectedType.Equals("null", StringComparison.OrdinalIgnoreCase);

            return expectedType.ToLowerInvariant() switch
            {
                "string" => value is string,
                "int" or "integer" => value is int or long or short or byte,
                "number" or "double" or "float" => IsNumeric(value),
                "bool" or "boolean" => value is bool,
                "array" => value is Array or ArrayList or IList,
                "hashtable" or "object" => value is Hashtable,
                _ => true // Unknown type - allow
            };
        }

        /// <summary>
        /// Checks if value is numeric type.
        /// </summary>
        private static bool IsNumeric(object? value)
        {
            return value is int or long or short or byte or
                   float or double or decimal;
        }

        /// <summary>
        /// Gets friendly type name for error messages.
        /// </summary>
        private static string GetTypeName(object? value)
        {
            if (value == null) return "null";
            if (value is Hashtable) return "hashtable";
            if (value is Array) return "array";
            return value.GetType().Name.ToLowerInvariant();
        }

        /// <summary>
        /// Gets list of missing required keys.
        /// </summary>
        /// <param name="config">Configuration hashtable</param>
        /// <param name="requiredKeys">List of required key names</param>
        /// <returns>List of missing keys</returns>
        public static List<string> GetMissingKeys(Hashtable config, IEnumerable<string> requiredKeys)
        {
            if (config == null)
                throw new ArgumentNullException(nameof(config));
            if (requiredKeys == null)
                throw new ArgumentNullException(nameof(requiredKeys));

            var missing = new List<string>();

            foreach (var key in requiredKeys)
            {
                if (!config.ContainsKey(key))
                {
                    missing.Add(key);
                }
            }

            return missing;
        }
    }

    /// <summary>
    /// Result of configuration validation.
    /// </summary>
    public class ValidationResult
    {
        /// <summary>
        /// True if configuration is valid.
        /// </summary>
        public bool IsValid { get; set; }

        /// <summary>
        /// List of validation errors (empty if valid).
        /// </summary>
        public List<string> Errors { get; } = new();

        /// <summary>
        /// Gets formatted error message (all errors joined).
        /// </summary>
        public string ErrorMessage => string.Join("; ", Errors);
    }
}
