[CmdletBinding()]
param
(
    $serialNumber
)

$configFile = '.\.secrets\config.json'
$functionsFolder = "$PWD\functions"
#import functions.
if (Test-Path $functionsFolder) {
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions) {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}


if (connectToTenant($configFile)) {
    Write-Host 'Successfully connected to Microsoft Graph.' -ForegroundColor Green
}
else {
    Write-Host 'Failed to connect to Microsoft Graph.' -ForegroundColor Red
    exit 1
}


