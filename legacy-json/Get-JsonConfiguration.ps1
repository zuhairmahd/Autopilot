function Get-JsonConfiguration()
<#
.SYNOPSIS
    Universal JSON configuration loader with fallback support and validation.

.DESCRIPTION
    This function provides a consolidated approach for loading JSON configuration files with robust 
    error handling, validation, and fallback mechanisms. It supports multiple configuration formats:
    - Simple flat JSON objects
    - Complex structured JSON with sections (like strings.json)
    - Configuration arrays with environment-specific values (like init.json)

.PARAMETER JsonFile
    The full path to the JSON configuration file to load.

.PARAMETER DefaultValues
    A hashtable containing default values to use if the JSON file cannot be loaded or contains
    missing keys. For structured JSON, this should contain sections matching the JSON structure.

.PARAMETER ConfigurationType
    For init.json files, specifies which configuration values to use:
    - 'dev': Uses devdefault values
    - 'release': Uses reldefault values  
    - 'default': Uses default values
    For other JSON types, this parameter is ignored.

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable containing the loaded configuration. Structure depends on the JSON format:
    - Simple JSON: Flat hashtable with key-value pairs
    - Structured JSON: Nested hashtable with sections
    - Init JSON: Flat hashtable with processed configuration values

.EXAMPLE
    # Load strings configuration with fallback
    $defaultStrings = @{
        returnValues = @{ message1 = 'Default message' }
        deviceStates = @{ Ready = 'Device ready' }
    }
    $config = Get-JsonConfiguration -JsonFile "strings.json" -DefaultValues $defaultStrings

.EXAMPLE
    # Load init configuration for release environment
    $defaults = @{ configFile = 'config.json'; maxWaitTime = '30' }
    $config = Get-JsonConfiguration -JsonFile "init.json" -DefaultValues $defaults -ConfigurationType 'release'

.NOTES
    - Validates JSON syntax before processing
    - Preserves ordered hashtables where applicable
    - Merges JSON values with defaults, prioritizing JSON values
    - Adds comprehensive logging for troubleshooting
    - Gracefully handles missing files, invalid JSON, and missing keys
#>
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFile,
        [Parameter(Mandatory = $true)]
        [hashtable]$DefaultValues,
        [string]$ConfigurationType = 'default'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module $functionName -Message "Attempting to load configuration from: $JsonFile" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Attempting to load configuration from: $JsonFile"
    Write-Verbose "[$functionName] Configuration Type: $ConfigurationType"
    
    try
    {
        if (Test-Path -Path $JsonFile)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Loading configuration from JSON file: $JsonFile" -LogLevel "Debug"
            $jsonContent = Get-Content -Path $JsonFile -Raw -Force -ErrorAction Stop
            
            # Validate JSON syntax
            try
            {
                $jsonData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
                Write-Log -LogFile $LogFile -Module $functionName -Message "JSON file is valid" -LogLevel "Debug"
            }
            catch
            {
                Write-Warning "[$functionName] Invalid JSON syntax in file: $JsonFile"
                Write-Verbose "[$functionName] JSON Error: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid JSON syntax in file: $JsonFile - $($_.Exception.Message)" -LogLevel "Error"
                throw "Invalid JSON format in configuration file"
            }
            # Handle different configuration types for init.json
            if ($JsonFile -like "*init.json")
            {
                Write-Verbose "[$functionName] Processing init.json with configuration type: $ConfigurationType"
                # Use regular hashtable for PowerShell 5.1 compatibility
                $processedData = @{}
                
                foreach ($item in $jsonData)
                {
                    $valueToUse = switch ($ConfigurationType)
                    {
                        'dev'
                        {
                            $item.devdefault 
                        }
                        'release'
                        {
                            $item.reldefault 
                        }
                        default
                        {
                            $item.default 
                        }
                    }
                    
                    if ($null -eq $valueToUse)
                    {
                        $valueToUse = $item.value
                    }
                    
                    $processedData[$item.name] = $valueToUse
                    Write-Verbose "[$functionName] Set $($item.name) = $valueToUse"
                }
                
                return $processedData
            }
            
            # Handle strings.json or simple JSON objects
            if ($jsonData -is [PSCustomObject])
            {
                # Use regular hashtable for PowerShell 5.1 compatibility
                $result = @{}
                
                # If it's a complex object like strings.json with sections
                if ($jsonData.PSObject.Properties.Name -contains 'returnValues' -or 
                    $jsonData.PSObject.Properties.Name -contains 'deviceStates' -or 
                    $jsonData.PSObject.Properties.Name -contains 'deviceActions')
                {
                    Write-Verbose "[$functionName] Processing structured JSON with sections"
                    foreach ($sectionName in $DefaultValues.Keys)
                    {
                        # Use regular hashtable for PowerShell 5.1 compatibility
                        $sectionData = @{}
                        $defaultSection = $DefaultValues[$sectionName]
                        
                        if ($jsonData.PSObject.Properties.Name -contains $sectionName)
                        {
                            Write-Verbose "[$functionName] Loading section '$sectionName' from JSON"
                            
                            # Load defaults first
                            foreach ($key in $defaultSection.Keys)
                            {
                                if ($jsonData.$sectionName.PSObject.Properties.Name -contains $key)
                                {
                                    $sectionData[$key] = $jsonData.$sectionName.$key
                                }
                                else
                                {
                                    Write-Verbose "[$functionName] Key '$key' not found in JSON section '$sectionName', using default"
                                    $sectionData[$key] = $defaultSection[$key]
                                }
                            }
                            
                            # Add any additional keys from JSON - PowerShell 5.1 compatible
                            foreach ($property in $jsonData.$sectionName.PSObject.Properties)
                            {
                                if (-not $sectionData.ContainsKey($property.Name))
                                {
                                    Write-Verbose "[$functionName] Adding additional key '$($property.Name)' from JSON section '$sectionName'"
                                    $sectionData[$property.Name] = $property.Value
                                }
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Section '$sectionName' not found in JSON, using defaults"
                            # Create a copy of the defaults
                            $sectionData = @{}
                            foreach ($key in $defaultSection.Keys)
                            {
                                $sectionData[$key] = $defaultSection[$key]
                            }
                        }
                        
                        $result[$sectionName] = $sectionData
                    }
                }
                else
                {
                    # Simple flat JSON object
                    Write-Verbose "[$functionName] Processing flat JSON object"
                    foreach ($property in $jsonData.PSObject.Properties)
                    {
                        $result[$property.Name] = $property.Value
                    }
                }
                
                return $result
            }
            else
            {
                Write-Verbose "[$functionName] JSON data is array type, returning as-is"
                return $jsonData
            }
        }
        else
        {
            Write-Verbose "[$functionName] Configuration file not found: $JsonFile, using default values"
            return $DefaultValues
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error loading configuration from JSON file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        Write-Verbose "[$functionName] Falling back to default values"
        return $DefaultValues
    }
}

