[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Configuration = "Release",
    [Parameter(Mandatory = $false)]
    [string]$Platform = "Any CPU"
)

#Get the name of the script.
$scriptName = $MyInvocation.MyCommand.Name

$filesList = Get-ChildItem -Path "$pwd\*.ps1" -Recurse
Write-Verbose "[$scriptName] - Found $($filesList.Count) files in the current directory and subdirectories."
Write-Host "Found $($filesList.Count) files in the current directory and subdirectories."

foreach ($file in $filesList)
{
    Write-Host "Processing file $($file.name)"
    #Search the file for a string that starts with "function" and save the string either to the end of the line or to () in a variable.
    $functionName = Select-String -Path $file.FullName -Pattern "^function\s+([A-Za-z0-9\-]+)" | ForEach-Object { $_.Matches.Groups[1].Value 
        Write-Host $($_.Matches.Groups[1].Value)""
    }
    if ($functionName)
    {
        # Write-Host "Found function $functionName in file $($file.name)"
        #Check if the function name is already in the list.
        if ($functionName -notin $functionsList)
        {
            Write-Host "Adding function $functionName to the list."
            #Add the function name to the list.
            $functionsList += $functionName
        }
    }
}
Write-Host "Found $($functionNames.count) functions"
$global:myfunctions = $functionsList