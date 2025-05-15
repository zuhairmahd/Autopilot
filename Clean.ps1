[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        ValueFromRemainingArguments = $true,
        Position = 0
    )]
    [string[]]$PathsToCheck,
    [switch]$Recurse
)


#region Initial checks
if ($recurse)
{
    foreach ($item in $pathsToCheck)
    {
        $files += Get-ChildItem -Path $item -Filter *.ps1 -Recurse
    }
}
else
{
    foreach ($item in $PathsToCheck)
    {
        $files += Get-ChildItem -Path $item -Filter *.ps1
    }
}
Write-Host "Found $($files.Count) files in $($PathsToCheck -join ', ')."

foreach ($file in $files)
{
    #add the full name to a comma-separated string.
    if (-not $filesToClean)
    {
        $filesToClean = $file.FullName
    }
    else
    {
        $filesToClean += ",$($file.FullName)"
    }
}
#endregion

#Create a comma  delimitted string from the filesToClean array.

function CheckForInvalidSignatureBlocks()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$FilesToCheck
    )

    Write-Verbose "Received $($FilesToCheck.Count) files to check for invalid signature blocks."
    $returnObject = @{}
    $cleanedFiles = @()
    $filesWithInvalidSignature = @()
    $signatureBlock = "# SIG # Begin signature block"
    $fileCleanSuccessMessage = ''
    $fileCleanFailureMessage = ''
    Write-Verbose 'Checking for invalid signature blocks.'
    foreach ($file in $FilesToCheck)
    {
        Write-Verbose "Checking file $file for an invalid signature block."
        $signature = Get-AuthenticodeSignature -FilePath $file -ErrorAction Stop
        if ($signature.status -ne 'notSigned')
        {
            Write-Verbose "The file $file is signed with an invalid signature."
            Write-Verbose "The signature status is $($signature.status)."
            Write-Verbose "Removing the invalid signature block"
            $filesWithInvalidSignature += $file
            try 
            {
                Write-Verbose "Reading content of file $file."
                $signatureBlock = Get-Content -Path $file -Raw -Force -ErrorAction Stop
                Write-Verbose "Removing the invalid signature block from file $file."
                $signatureBlock = $signatureBlock -replace [regex]::Escape("$signatureBlock.*"), ''
                Write-Verbose "Writing the cleaned content to file $file."
                Set-Content -Path $file -Value $signatureBlock -Force
                Write-Verbose "The signature block has been removed."
                $cleanedFiles += $file
                Write-Verbose "The file $file has been cleaned of the invalid signature block."
            }
            catch
            {
                Write-Host "An error occurred while removing the invalid signature block from $fileToSign."
                Write-Verbose $_.Exception.Message
                return $null
            }
        }
        else
        {
            Write-Verbose "The file $fileToSign is not signed."
            Write-Verbose "The signature status is $($signature.status)."
        }
    }
    Write-Verbose "Finished checking for invalid signature blocks."
    Write-Verbose "Found $($filesWithInvalidSignature.Count) files with invalid signature blocks."
    Write-Verbose "Cleaned $($cleanedFiles.Count) files of the invalid signature block."
    switch ($filesWithInvalidSignature.Count)
    {
        0
        {
            Write-Host 'No files with invalid signature blocks were found.' 
        }
        1 
        { 
            Write-Verbose "Found $($filesWithInvalidSignature.Count) file with invalid signature block." 
            $fileCleanSuccessMessage = "The file has been cleaned of the invalid signature block."
            $fileCleanFailureMessage = "The following file could not be cleaned of the invalid signature block:"
        }
        default
        {
            Write-Verbose "Found $($filesWithInvalidSignature.Count) files with invalid signature blocks." 
            $fileCleanSuccessMessage = "All files have been cleaned of the invalid signature block."
            $fileCleanFailureMessage = "The following files could not be cleaned of the invalid signature block:"
        }
    }
    if ($filesWithInvalidSignature.count -eq $cleanedFiles.count)
    {
        Write-Verbose $fileCleanSuccessMessage
        $returnObject = @{
            Success                   = $true
            CleanedFiles              = $cleanedFiles
            FilesWithInvalidSignature = $filesWithInvalidSignature
            SuccessMessage            = $fileCleanSuccessMessage
            FailureMessage            = $fileCleanFailureMessage
        }
    }
    else
    {
        Write-Verbose $fileCleanFailureMessage
        $returnObject = @{
            Success                   = $false
            CleanedFiles              = $cleanedFiles
            FilesWithInvalidSignature = $filesWithInvalidSignature
            SuccessMessage            = $fileCleanSuccessMessage
            FailureMessage            = $fileCleanFailureMessage
        }
    }
    Write-Verbose "Returning results to calling function."
    return $returnObject
}

$invalidSignatureCheck = CheckForInvalidSignatureBlocks -FilesToCheck ($filesToClean -split ',')

if ($null -ne $invalidSignatureCheck)
{
    if ($invalidSignatureCheck.success )
    {
        Write-Host "$($invalidSignatureCheck.SuccessMessage)."
    }
    else
    {
        Write-Host "$($invalidSignatureCheck.FailureMessage) $($invalidSignatureCheck.FilesWithInvalidSignature -join ', ')"
        Write-Host 'We will continue, but you may encounter some errors during the signature process.'
        Write-Host "If you do, run the script with the -verbose parameter to see the errors."
    }
}
