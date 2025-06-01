Get-ChildItem -Path "$PSScriptRoot\*.ps1" | ForEach-Object {. $PSScriptRoot\$($_.Name)}

$functions = Get-ChildItem -Path "$PSScriptRoot\*.ps1" | ForEach-Object {
    (Get-Content $_.FullName) -match '^\s*function\s+\w+' | Where-Object { $_ } | Select-Object -Unique
}

$variables = Get-ChildItem -Path "$PSScriptRoot\*.ps1" | ForEach-Object {
    (Get-Content $_.FullName) -match '^\s*\$[a-zA-Z_][a-zA-Z0-9_]*' | Where-Object { $_ } | Select-Object -Unique
}

# Output the counts of unique functions and variables
Write-Host "Number of unique functions: $($functions.Count)"
Write-Host "Number of unique variables: $($variables.Count)"