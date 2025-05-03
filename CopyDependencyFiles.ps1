#region help
<#PSScriptInfo
.VERSION 1.0.0
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Creates separate folders for main.ps1 and register.ps1, each with their own functions subfolder
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES
.SYNOPSIS
Creates separate folders for main.ps1 and register.ps1, each with their own functions subfolder.
.DESCRIPTION
This script creates two separate folders (main and register) under the specified destination root.
Each folder will contain the respective script file and a functions subfolder with only the functions
that particular script requires, as defined in the map.json file. It will also copy necessary
configuration files to each folder.
.PARAMETER SourceRoot
    The path to the source folder that contains main.ps1, register.ps1, and the functions folder.
    The default value is the current directory ($PWD).
.PARAMETER DestinationRoot
    The path to the destination folder where the main and register folders will be created.
    This is a required parameter.
.PARAMETER MapFile
    The path to the JSON file that maps scripts to their required functions.
    The default value is "$SourceRoot\map.json".
.PARAMETER OverwriteExisting
    A switch to overwrite existing files in the destination folders. Default is false.
.EXAMPLE
    CopyDependencyFiles.ps1 -DestinationRoot "C:\Deployment"
    Creates a folder structure at C:\Deployment with separate folders for main.ps1 and register.ps1.
.EXAMPLE
    CopyDependencyFiles.ps1 -SourceRoot "C:\Source\Autopilot" -DestinationRoot "C:\Deployment" -OverwriteExisting
    Creates a folder structure at C:\Deployment using source files from C:\Source\Autopilot, overwriting existing files.
.NOTES
    This script will:
    1. Create two separate folders (main and register) under the DestinationRoot
    2. Copy the main.ps1 and register.ps1 files to their respective folders
    3. Create a functions subfolder in each folder
    4. Copy only the required function files to each functions subfolder based on map.json
    5. Copy required configuration files (initVerify.json for main.ps1; vars.json and init.json for register.ps1)
    6. Log all operations with verbose output
#>
#endregion help

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = $PWD,
    
    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,
    
    [Parameter(Mandatory = $false)]
    [string]$MapFile = "$SourceRoot\map.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$OverwriteExisting
)

#region Helper Functions
function Copy-File
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationFile,
        
        [Parameter(Mandatory = $false)]
        [switch]$OverwriteExisting
    )
    
    Write-Verbose "Processing file: $SourceFile"
    
    # Ensure source file exists
    if (-not (Test-Path -Path $SourceFile))
    {
        Write-Warning "Source file not found: $SourceFile"
        return $false
    }
    
    # Create the destination directory if it doesn't exist
    $destinationDirectory = Split-Path -Path $DestinationFile
    if (-not (Test-Path -Path $destinationDirectory -PathType Container))
    {
        Write-Verbose "Creating directory: $destinationDirectory"
        New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
    }
    
    # Check if destination file exists and handle overwrite
    if ((Test-Path -Path $DestinationFile) -and -not $OverwriteExisting)
    {
        Write-Verbose "Skipping existing file: $DestinationFile"
        return $true
    }
    
    # Copy the file
    try
    {
        Write-Verbose "Copying $SourceFile to $DestinationFile"
        Copy-Item -Path $SourceFile -Destination $DestinationFile -Force
        return $true
    }
    catch
    {
        Write-Warning "Failed to copy file: $_"
        return $false
    }
}

function Get-RequiredFunctions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MapData,
        
        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.HashSet[string]]$FunctionSet = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$ProcessedDependency
    )
    
    # Initialize a new HashSet if not provided
    if ($null -eq $FunctionSet)
    {
        $FunctionSet = New-Object System.Collections.Generic.HashSet[string]
    }
    
    Write-Verbose "Getting required functions for $ScriptName"
    
    # Get direct functions for the script
    if ($MapData.$ScriptName -and $MapData.$ScriptName.directFunctions)
    {
        $directFunctions = $MapData.$ScriptName.directFunctions
        
        # Process each direct function
        foreach ($funcName in $directFunctions.PSObject.Properties.Name)
        {
            if ($FunctionSet.Add($funcName))
            {
                Write-Verbose "Added function: $funcName"
                
                # Process the function's dependencies
                if ($directFunctions.$funcName.dependencies)
                {
                    $dependencies = $directFunctions.$funcName.dependencies
                    
                    if ($dependencies -is [PSCustomObject] -or $dependencies -is [Hashtable])
                    {
                        # Handle nested dependencies
                        foreach ($depName in $dependencies.PSObject.Properties.Name)
                        {
                            if ($FunctionSet.Add($depName))
                            {
                                Write-Verbose "Added dependency: $depName"
                                
                                # Recursively process deeper dependencies
                                if ($dependencies.$depName.dependencies)
                                {
                                    $nestedDeps = $dependencies.$depName.dependencies
                                    foreach ($nestedDepName in $nestedDeps.PSObject.Properties.Name)
                                    {
                                        if ($FunctionSet.Add($nestedDepName))
                                        {
                                            Write-Verbose "Added nested dependency: $nestedDepName"
                                        }
                                    }
                                }
                            }
                        }
                    } 
                    elseif ($dependencies -is [array])
                    {
                        # Handle array of dependencies
                        foreach ($depName in $dependencies)
                        {
                            if ($FunctionSet.Add($depName))
                            {
                                Write-Verbose "Added dependency: $depName"
                            }
                        }
                    }
                    else
                    {
                        # Handle simple string dependencies
                        foreach ($depName in $dependencies)
                        {
                            if ($FunctionSet.Add($depName))
                            {
                                Write-Verbose "Added dependency: $depName"
                            }
                        }
                    }
                }
            }
        }
    }
    
    # Add core components that are used by this script
    if ($MapData.coreComponents)
    {
        foreach ($coreComp in $MapData.coreComponents.PSObject.Properties.Name)
        {
            if ($MapData.coreComponents.$coreComp.usedBy -contains $ScriptName)
            {
                if ($FunctionSet.Add($coreComp))
                {
                    Write-Verbose "Added core component: $coreComp"
                }
            }
        }
    }
    
    return $FunctionSet
}
#endregion Helper Functions

#region Main Script
Write-Host "Starting dependency file copy operation..." -ForegroundColor Cyan
Write-Verbose "Source Root: $SourceRoot"
Write-Verbose "Destination Root: $DestinationRoot"
Write-Verbose "Map File: $MapFile"

# Define the main script files and their required config files
$scriptFiles = @(
    @{
        Name        = 'main.ps1'
        ConfigFiles = @('initVerify.json')
    },
    @{
        Name        = 'register.ps1'
        ConfigFiles = @('init.json', 'vars.json')
    }
)

# Check if source folder exists
if (-not (Test-Path -Path $SourceRoot -PathType Container))
{
    Write-Error "Source folder does not exist: $SourceRoot"
    exit 1
}

# Check if source functions folder exists
$sourceFunctionsFolder = Join-Path -Path $SourceRoot -ChildPath 'functions'
if (-not (Test-Path -Path $sourceFunctionsFolder -PathType Container))
{
    Write-Error "Functions folder does not exist in the source: $sourceFunctionsFolder"
    exit 1
}

# Check if map file exists
if (-not (Test-Path -Path $MapFile))
{
    Write-Error "Map file does not exist: $MapFile"
    exit 1
}

# Load the map file
try
{
    $mapData = Get-Content -Path $MapFile -Raw | ConvertFrom-Json
    Write-Verbose "Map file loaded successfully"
}
catch
{
    Write-Error "Failed to load map file: $_"
    exit 1
}

# Process each script file
$successCount = 0
$failCount = 0

foreach ($scriptFile in $scriptFiles)
{
    $scriptFileName = $scriptFile.Name
    $configFiles = $scriptFile.ConfigFiles
    
    # Define source and destination paths
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFileName) # 'main' or 'register'
    $sourceScriptPath = Join-Path -Path $SourceRoot -ChildPath $scriptFileName
    
    # Skip if source script doesn't exist
    if (-not (Test-Path -Path $sourceScriptPath -PathType Leaf))
    {
        Write-Warning "Source script not found, skipping: $sourceScriptPath"
        continue
    }
    
    # Create the destination script folder
    $destScriptFolder = Join-Path -Path $DestinationRoot -ChildPath $scriptName
    if (-not (Test-Path -Path $destScriptFolder -PathType Container))
    {
        Write-Verbose "Creating script folder: $destScriptFolder"
        New-Item -Path $destScriptFolder -ItemType Directory -Force | Out-Null
    }
    
    # Copy the script file
    $destScriptFile = Join-Path -Path $destScriptFolder -ChildPath $scriptFileName
    $result = Copy-File -SourceFile $sourceScriptPath -DestinationFile $destScriptFile -OverwriteExisting:$OverwriteExisting
    
    if ($result)
    {
        Write-Host "Copied $scriptFileName to $destScriptFolder" -ForegroundColor Green
        $successCount++
    }
    else
    {
        Write-Error "Failed to copy $scriptFileName"
        $failCount++
    }
    
    # Copy configuration files
    foreach ($configFile in $configFiles)
    {
        $sourceConfigPath = Join-Path -Path $SourceRoot -ChildPath $configFile
        
        # Check if source config file exists
        if (-not (Test-Path -Path $sourceConfigPath -PathType Leaf))
        {
            # Try to find in Release folder if not in root
            $sourceConfigPath = Join-Path -Path $SourceRoot -ChildPath "Release\$configFile"
            
            if (-not (Test-Path -Path $sourceConfigPath -PathType Leaf))
            {
                Write-Warning "Config file not found, skipping: $configFile"
                continue
            }
        }
        
        $destConfigFile = Join-Path -Path $destScriptFolder -ChildPath $configFile
        $result = Copy-File -SourceFile $sourceConfigPath -DestinationFile $destConfigFile -OverwriteExisting:$OverwriteExisting
        
        if ($result)
        {
            Write-Host "Copied configuration file $configFile to $destScriptFolder" -ForegroundColor Green
            $successCount++
        }
        else
        {
            Write-Warning "Failed to copy configuration file: $configFile"
            $failCount++
        }
    }
    
    # Create functions subfolder
    $destFunctionsFolder = Join-Path -Path $destScriptFolder -ChildPath 'functions'
    if (-not (Test-Path -Path $destFunctionsFolder -PathType Container))
    {
        Write-Verbose "Creating functions folder: $destFunctionsFolder"
        New-Item -Path $destFunctionsFolder -ItemType Directory -Force | Out-Null
    }
    
    # Get the required functions for this script
    $requiredFunctions = Get-RequiredFunctions -ScriptName $scriptFileName -MapData $mapData
    
    if ($requiredFunctions.Count -eq 0)
    {
        Write-Warning "No required functions found for $scriptFileName in the map file"
    }
    else
    {
        Write-Host "Found $($requiredFunctions.Count) required functions for $scriptFileName" -ForegroundColor Cyan
        
        # Copy the required function files
        foreach ($functionName in $requiredFunctions)
        {
            $functionFile = "$functionName.ps1"
            $sourceFunctionPath = Join-Path -Path $sourceFunctionsFolder -ChildPath $functionFile
            
            if (Test-Path -Path $sourceFunctionPath)
            {
                $destFunctionPath = Join-Path -Path $destFunctionsFolder -ChildPath $functionFile
                $result = Copy-File -SourceFile $sourceFunctionPath -DestinationFile $destFunctionPath -OverwriteExisting:$OverwriteExisting
                
                if ($result)
                {
                    Write-Verbose "Copied function: $functionFile"
                    $successCount++
                }
                else
                {
                    Write-Warning "Failed to copy function: $functionFile"
                    $failCount++
                }
            }
            else
            {
                Write-Warning "Function file not found: $sourceFunctionPath"
            }
        }
    }
}

# Summary
Write-Host "`nOperation complete!" -ForegroundColor Cyan
Write-Host "Files successfully copied: $successCount" -ForegroundColor Green
if ($failCount -gt 0)
{
    Write-Host "Files failed to copy: $failCount" -ForegroundColor Red
}

Write-Host "`nFolder structure created:" -ForegroundColor Cyan
Write-Host "├─ $DestinationRoot" -ForegroundColor White
Write-Host "│   ├─ main" -ForegroundColor White
Write-Host "│   │   ├─ main.ps1" -ForegroundColor White
Write-Host "│   │   ├─ initVerify.json" -ForegroundColor White
Write-Host "│   │   └─ functions" -ForegroundColor White
Write-Host "│   │       └─ [required function files]" -ForegroundColor White
Write-Host "│   └─ register" -ForegroundColor White
Write-Host "│       ├─ register.ps1" -ForegroundColor White
Write-Host "│       ├─ init.json" -ForegroundColor White
Write-Host "│       ├─ vars.json" -ForegroundColor White
Write-Host "│       └─ functions" -ForegroundColor White
Write-Host "│           └─ [required function files]" -ForegroundColor White
#endregion Main Script