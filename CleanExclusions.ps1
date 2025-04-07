#region help
<#PSScriptInfo
.VERSION 3.0.0
.GUID 8f2b9cde-1234-4abc-9def-5678abcdef12
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Script to clean and sort exclusions.json
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES None
.SYNOPSIS
Cleans and sorts the exclusions.json file by removing duplicates and sorting alphabetically.
.DESCRIPTION
    This script reads the exclusions.json file, removes duplicate entries, and sorts the exclusions alphabetically. The updated content is then written back to the file.
.PARAMETER FilePath
    The path to the exclusions.json file. Default is './exclusions.json'.
.EXAMPLE
    .\CleanExclusions.ps1 -FilePath './exclusions.json'
    Cleans and sorts the exclusions.json file located at './exclusions.json'.
.NOTES
  1. Ensure the file exists before running the script.
  2. Backup the file if needed before running the script.
#>
#endregion help

param (
    [string]$FilePath = './exclusions.json'
)

# Check if the file exists
if (-Not (Test-Path -Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

# Read the JSON file
try {
    $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

# Ensure the exclusions property exists and is an array
if (-Not $jsonContent.exclusions -or -Not ($jsonContent.exclusions -is [System.Collections.IEnumerable])) {
    Write-Error "Invalid JSON structure: 'exclusions' property is missing or not an array."
    exit 1
}

# Count the initial number of entries
$initialCount = $jsonContent.exclusions.Count

# Remove duplicates and sort alphabetically
$jsonContent.exclusions = $jsonContent.exclusions | Sort-Object -Unique

# Count the final number of entries and calculate duplicates removed
$finalCount = $jsonContent.exclusions.Count
$duplicatesRemoved = $initialCount - $finalCount

# Write the updated JSON back to the file
try {
    $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    Write-Output "Exclusions file cleaned and sorted successfully."
    Write-Output "Entries read: $initialCount"
    Write-Output "Duplicates removed: $duplicatesRemoved"
    Write-Output "Entries remaining: $finalCount"
} catch {
    Write-Error "Failed to write updated JSON to file: $_"
    exit 1
}