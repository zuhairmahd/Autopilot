
#region Helper Functions
function Find-FolderPath()
{
    <#
    .SYNOPSIS
        Searches upward from the given path for a folder with the specified name.
    .PARAMETER Path
        The starting path to begin searching from.
    .PARAMETER FolderName
        The name of the folder to search for.
    .OUTPUTS
        Returns the full path to the folder if found, otherwise $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose log of received parameters
    Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
    try
    {
        $currentPath = (Resolve-Path -Path $Path).Path
        Write-Verbose "[$functionName] Current path resolved to: $currentPath"

        # 1. Search children (recursively) of the starting path
        Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
        $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
        Write-Verbose "[$functionName] Checking child match: $($childMatch.FullName)"
        if ($childMatch)
        {
            Write-Verbose "[$functionName] Found folder in children: $($childMatch.FullName)"
            return $childMatch.FullName
        }
        # Also check if the starting path itself matches
        if ((Split-Path -Path $currentPath -Leaf) -ieq $FolderName)
        {
            Write-Verbose "[$functionName] Starting path itself matches: $currentPath"
            return $currentPath
        }

        # 2. Search up the parent chain, at each level search its children for the folder
        while ($currentPath)
        {
            $parent = Split-Path -Path $currentPath -Parent
            if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
            {
                break
            } # Reached root
            Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
            $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($siblingMatch)
            {
                Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                return $siblingMatch.FullName
            }
            # Also check if the parent itself matches
            if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Parent itself matches: $parent"
                return $parent
            }
            $currentPath = $parent
        }
        Write-Verbose "[$functionName] No folder found with name $FolderName in children or parent hierarchy."
        return $null
    }
    catch
    {
        Write-Error "[$functionName] Error occurred while searching for folder: $_"
        return $null
    }
}

function Get-FunctionDefinitions()
{
    <#
    .SYNOPSIS
        Extracts function definitions from a PowerShell file.
    #>
    param(
        [string]$FilePath
    )

    Write-Verbose "Scanning file for function definitions: $FilePath"

    $functions = @()

    try
    {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        # Match function definitions: function FunctionName { ... }
        # Also match: function Script:FunctionName, function Global:FunctionName
        $pattern = '(?m)^\s*function\s+(?:script:|global:)?([\w-]+)\s*(?:\([^\)]*\))?\s*\{'
        $regexMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        foreach ($match in $regexMatches)
        {
            $functionName = $match.Groups[1].Value
            $functions += $functionName
            Write-Verbose "  Found function: $functionName"
        }
    }
    catch
    {
        Write-Warning "Failed to read file ${FilePath}: $_"
    }

    return $functions
}

function Find-AllDefinedFunctions()
{
    <#
    .SYNOPSIS
        Discovers all function definitions in the functions folder.
    #>
    param(
        [string]$FolderPath
    )

    Write-Host "Discovering all function definitions..." -ForegroundColor Cyan

    $allFiles = Get-ChildItem -Path $FolderPath -Filter "*.ps1" -Recurse -File -ErrorAction SilentlyContinue
    $totalFiles = $allFiles.Count
    $currentFile = 0
    $returnObject = @()
    $functionObject = @{
        functionName = ""
        definedIn    = ""
        relativePath = ""
    }
    foreach ($file in $allFiles)
    {
        $currentFile++
        $percentComplete = [int](($currentFile / $totalFiles) * 100)
        $functions = Get-FunctionDefinitions -FilePath $file.FullName
        foreach ($func in $functions)
        {
            $functionObject = [PSCustomObject]@{
                functionName = $func
                definedIn    = $file.FullName
                relativePath = $file.FullName.Substring($FolderPath.Length).TrimStart('\')
            }
            $returnObject += $functionObject
        }
    }

    Write-Progress -Activity "Discovering Functions" -Completed
    Write-Host "  Found $($returnObject.Count) functions in total." -ForegroundColor Green
    return $returnObject
}

function Get-FunctionCalls()
{
    [CmdletBinding()                            ]
    param(
        [PSCustomObject]$functionsList,
        [string]$fileName
    )

    try
    {
        $content = Get-Content -Path $fileName -Raw -ErrorAction Stop

        # Remove comments to avoid false positives
        $content = $content -replace '(?m)^\s*#.*$', ''
        $content = $content -replace '<#[\s\S]*?#>', ''
        $calls = @()
        foreach ($func in $functionsList)
        {
            $pattern = "\b$($func.functionName)\b"
            if ($content -match $pattern)
            {
                $calls += $func.functionName
            }
        }
    }
    catch
    {
        Write-Warning "Failed to read file ${FilePath}: $_"
    }
    return $calls
}
#endregion


$functionsFolder = Find-FolderPath -Path (Get-Location).Path -FolderName "functions"
if (-not $functionsFolder)
{
    Write-Error "Functions folder not found in the directory hierarchy."
    exit 1
}
$mainScriptFile = "$(Split-Path -Path $functionsFolder -Parent)\main.ps1"
$functionsList = Find-AllDefinedFunctions -FolderPath $functionsFolder | Sort-Object definedIn
$global:calls = Get-FunctionCalls -functionsList $functionsList -fileName "$mainScriptFile


"