[CmdletBinding()]
param
(
    [string]$Folder= "$PWD",
    [string]$ConfigurationFile = "$folder\vars.json"
)

#import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

CreateConfiguration -Folder $Folder -ConfigurationFile $ConfigurationFile