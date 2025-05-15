[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FileName
)

#Get the name of the script.
$scriptName = $MyInvocation.MyCommand.Name
$FunctionPattern = "^function\s+([A-Za-z0-9\-]+)" 
$filesList = Get-ChildItem -Path "$pwd\*.ps1" -Recurse
Write-Verbose "[$scriptName] - Found $($filesList.Count) files in the current directory and subdirectories."
Write-Host "Found $($filesList.Count) files in the current directory and subdirectories."

foreach ($file in $filesList)
{
    Write-Verbose "[$scriptName] Processing file $($file.name)"
    #Search the file for a string that starts with "function" and save the string either to the end of the line or to () in a variable.
    $functionName = Select-String -Path $file.FullName -Pattern $FunctionPattern | ForEach-Object { $_.Matches.Groups[1].Value }
    if ($functionName)
    {
        #Check if the function name is already in the list.
        if ($functionName -notin $functionsList)
        {
            Write-Verbose "[$scriptName] Adding function $functionName to the list."
            #Add the function name to the list.
            $functionsList += $functionName
        }
    }
}
Write-Host "Found $($functionNames.count) functions"

$functionsInFile = @()
$functionsInFile = Select-String -Path $FileName -Pattern $FunctionPattern | ForEach-Object { $_.Matches.Groups[1].Value }
$functionsInFile = $functionsInFile | Sort-Object -Unique
Write-Host "Found $($functionsInFile.count) functions in file $($FileName)"
#Print the list of functions in the file with a list format.
Write-Host "Functions in file $($FileName):"
foreach ($function in $functionsInFile)
{
    Write-Host " - $function"
}
