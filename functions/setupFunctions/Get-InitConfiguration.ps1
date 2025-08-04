function Get-InitConfiguration()
<#
.SYNOPSIS
    Loads initialization configuration from init.json with environment-specific value selection.

.DESCRIPTION
    This function loads configuration values from the init.json file and selects the appropriate
    values based on the specified configuration type (dev, release, or default). It uses the
    consolidated Get-JsonConfiguration function for robust JSON handling and fallback support.

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$PWD\init.json".

.PARAMETER ConfigurationType
    Specifies which configuration values to load from the init.json structure:
    - 'dev': Uses devdefault values from each configuration item
    - 'release': Uses reldefault values from each configuration item
    - 'default': Uses default values from each configuration item

.OUTPUTS
    System.Collections.Hashtable
    Returns a flat hashtable with configuration name-value pairs selected based on ConfigurationType.

.EXAMPLE
    # Load development configuration
    $devConfig = Get-InitConfiguration -ConfigurationType 'dev'

.EXAMPLE
    # Load release configuration from specific file
    $releaseConfig = Get-InitConfiguration -InitFile "C:\Config\init.json" -ConfigurationType 'release'

.NOTES
    - Depends on Get-JsonConfiguration function
    - Provides sensible defaults for common configuration values
    - Handles missing files gracefully by returning default values
    - Includes comprehensive logging for troubleshooting
#>
{
    [CmdletBinding()]
    param(
        [string]$InitFile = "$PWD\init.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'default'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading initialization configuration from: $InitFile"
    Write-Verbose "[$functionName] Configuration Type: $ConfigurationType"
    # Default initialization values (fallback)
    $defaultInitValues = @{
        configFile          = ".\\.secrets\\config.json"
        configuration       = "settings.json" 
        ShowAdvancedOptions = "False"
        GroupTag            = ""
        maxWaitTime         = "30"
        timeInSeconds       = "30"
        Repo                = "Github"
        Release             = "main"
    }
    
    try
    {
        $config = Get-JsonConfiguration -JsonFile $InitFile -DefaultValues $defaultInitValues -ConfigurationType $ConfigurationType
        Write-Verbose "[$functionName] Successfully loaded initialization configuration"
        return $config
    }
    catch
    {
        Write-Warning "[$functionName] Failed to load initialization configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default values"
        return $defaultInitValues
    }
}

