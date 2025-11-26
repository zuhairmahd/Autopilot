[CmdletBinding()]
param(
    $inputFile,
    $OutputFile
)
#region Sort and backup strings.psd1
# Load the strings file

$stringsFilePath = if ($inputFile) { $inputFile } else { Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "strings.psd1" }          

# Read the original file to preserve the order of top-level keys
$fileContent = Get-Content -Path $stringsFilePath -Raw
$stringsData = Import-PowerShellDataFile -Path $stringsFilePath

# Extract the order of top-level keys from the original file
$topLevelKeys = [System.Collections.ArrayList]@()
$matches = [regex]::Matches($fileContent, '^\s*(\w+)\s*=', [System.Text.RegularExpressions.RegexOptions]::Multiline)
foreach ($match in $matches)
{
    $keyName = $match.Groups[1].Value
    if ($stringsData.ContainsKey($keyName) -and -not $topLevelKeys.Contains($keyName))
    {
        [void]$topLevelKeys.Add($keyName)
    }
}

# Create an ordered hashtable to preserve object order
$sortedStrings = [ordered]@{}

# Iterate through each top-level key in the original order
foreach ($key in $topLevelKeys)
{
    $value = $stringsData[$key]
    
    # If the value is a hashtable or dictionary, sort its keys alphabetically
    if ($value -is [System.Collections.IDictionary])
    {
        $sortedHashtable = [ordered]@{}
        $value.Keys | Sort-Object | ForEach-Object {
            $sortedHashtable[$_] = $value[$_]
        }
        $sortedStrings[$key] = $sortedHashtable
    }
    else
    {
        # Preserve non-hashtable values as-is
        $sortedStrings[$key] = $value
    }
}

# Generate the backup file path
$backupFilePath = if ($OutputFile) { $OutputFile } else { Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "strings_sorted.psd1" }  

# Write the sorted content to the backup file
$content = "@{`n"
foreach ($key in $sortedStrings.Keys)
{
    $value = $sortedStrings[$key]
    $content += "    $key"
    $content += " " * (14 - $key.Length)  # Align the = sign
    
    if ($value -is [System.Collections.IDictionary])
    {
        # Value is a hashtable - format it as nested structure
        $content += "= @{`n"
        foreach ($subKey in $value.Keys)
        {
            $subValue = $value[$subKey]
            # Calculate padding for alignment
            $maxKeyLength = ($value.Keys | Measure-Object -Maximum -Property Length).Maximum
            $padding = " " * ($maxKeyLength - $subKey.Length + 1)
            $content += "        $subKey$padding= '$subValue'`n"
        }
        $content += "    }`n"
    }
    else
    {
        # Value is a simple string - format it directly
        $content += "= '$value'`n"
    }
}
$content += "}`n"

# Write to file
Set-Content -Path $backupFilePath -Value $content -Encoding UTF8
Write-Host "Sorted strings saved to: $backupFilePath"
#endregion Sort and backup strings.psd1
