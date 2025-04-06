<#
.SYNOPSIS
Downloads and updates scripts from a remote manifest.

.DESCRIPTION
The DownloadScriptUpdates function downloads specified scripts (functions, scripts, and commands) from a remote URI based on a provided manifest.
It verifies the downloaded files, updates the local manifest, and copies the files to the appropriate destination.

.PARAMETER scriptsToUpdate
An array of objects specifying the scripts to update, categorized by type (functions, scripts, cmds).

.PARAMETER scriptURI
The base URI from which the scripts will be downloaded.

.PARAMETER ScriptRoot
The root directory where the scripts and manifests are stored.

.EXAMPLE
DownloadScriptUpdates -scriptsToUpdate $scripts -scriptURI "https://example.com/scripts" -ScriptRoot "C:\Scripts"
Downloads and updates the specified scripts from the remote URI to the local script root directory.

.NOTES
Version: 3.0.0
Author: [Your Name]
#>

function DownloadScriptUpdates() 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [system.object[]]$scriptsToUpdate,
        [Parameter(Mandatory = $true)]
        [string]$scriptURI,
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )
    $success = $true
    $categories = @('functions', 'scripts', 'cmds')
    $statusCodes = @()
    $tempFolder = "$ScriptRoot\temp"
    $localManifest = "manifest.json"
    $remoteManifest = "remoteManifest.json"
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURI: $scriptURI"
    Write-Debug "Received ScriptsToUpdate: $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host "Downloading $($scriptsToUpdate.functions.count) functions, $($scriptsToUpdate.scripts.count) scripts, and $($scriptsToUpdate.cmds.count) cmds from the remote manifest." 
    
    #Check if the temp folder exists, if not create it.  If it exists, delete it and create it again.
    if (Test-Path $tempFolder)
    {
        Write-Verbose "Deleting temp folder $tempFolder"
        Remove-Item -Path $tempFolder -Recurse -Force
    }
    # Create the temp folder.
    Write-Verbose "Creating temp folder $tempFolder"
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
    Write-Verbose "Create functions folder in $tempFolder\functions"
    New-Item -Path "$tempFolder\functions" -ItemType Directory -Force | Out-Null
    Write-Verbose "Created temp folder $tempFolder and function folder $tempFolder\functions"
    
    foreach ($category in $categories)
    {
        $items = $scriptsToUpdate.$category
        Write-Verbose "Processing $($items.Count) $category"
        foreach ($item in $items)
        {
            Write-Verbose "Processing file: $($item.name)"
            switch ($category)
            {
                functions
                {
                    $extension = 'ps1'
                    $fullFunctionName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath "functions\$fullFunctionName"
                    Write-Host "Downloading function $($fullFunctionName):"
                    Write-Verbose "Remote URL: $($scriptURI)/functions/$fullFunctionName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/functions/$fullFunctionName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullFunctionName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullFunctionName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
                scripts
                {
                    $extension = 'ps1'
                    $fullScriptName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullScriptName
                    Write-Host "Downloading script $($fullScriptName):"
                    Write-Verbose "Remote URL: $($scriptURI)/$fullScriptName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullScriptName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullScriptName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullScriptName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
                cmds
                {
                    $extension = 'cmd'
                    $fullCmdName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullCmdName
                    Write-Host "Downloading file $($fullCmdName):"
                    Write-Verbose "Remote URL: $($scriptURI)/$fullcmdName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullCmdName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullCmdName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullCmdName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
            }
            $statusCodes += @{
                filename = $fullCmdName; statuscode = $response.StatusCode 
            }
        }
    }
    # Check if all files were downloaded successfully.
    Write-Host "Verifying downloaded files."
    foreach ($statusCode in $statusCodes)
    {
        Write-Verbose "Verifying file ($statusCode.filename) with status code: $($statusCode.statuscode)"
        if ($statusCode.statuscode -ne 200)
        {
            $success = $false
            Write-Host "Failed to download file $($statusCode.filename). Status code: $($statusCode.statuscode)" -ForegroundColor Red
        }
        else 
        {
            Write-Verbose "Successfully downloaded file $($statusCode.filename)." -ForegroundColor Green
        }
    }
    if ($success -eq $true)
    {
        Write-Host "All files downloaded successfully." -ForegroundColor Green
        Write-Host "Updating the local manifest."
        remove-item "$ScriptRoot\$localManifest" -Force
        rename-item "$ScriptRoot\$remoteManifest" -NewName "$localManifest"
        Write-Verbose "Creating temporary manifest file."
        $scriptsToUpdate | ConvertTo-Json | Set-Content "$tempFolder\$localManifest"
        Write-Host "Copying files..."
        if (CopyFiles -SourceFolder $tempFolder -DestinationFolder $ScriptRoot -manifestFile $tempFolder\$localManifest)
        {
            Write-Host "Files copied successfully."
            Write-Verbose "Cleaning up temp folder."
            Remove-Item -Path $tempFolder -Recurse -Force
        }
        else
        {
            Write-Host "Failed to copy files." -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Failed to download one or more files. Please check the logs." -ForegroundColor Red
    }
    return $success
}

# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBRwDmwoSb47dDE
# yxaMMZRyJbn+r4Y/4/BVkt/jpQMmw6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAMVHlg5
# gWYqQMnfAAAAAxUeMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwMzI0MDcwMDM5WhcNMjUwMzI3
# MDcwMDM5WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# nab4bPyKWEQobHp0R47lcM00uZzLPiT90EL5FLbdx72agnLr1enPBr3pqOfD0tdV
# J1oyQ8ygsdH26+ZA07C8A1Sh/zXCZKvaPl1Tm7myXVZkgd0pZ8XeJQbZY6qb/nKI
# AUS30GLyGyERuJUoXg9B7AChnDIU4zal/NZKikLTsOoO0D+IIftoHGSzjScISiVG
# Msu+TWJrATlnxaZQOvPCwUiDpXr+WVm2CkaQNE98YJRRrtiXqKNHucnL7PuoaBkC
# QPEYCNefo6+U6V42wfcIvVj+obbDl5TJubmNvsKP0hNjGlrcpLvxUOcCw/IkeEU0
# M/DVzg/UT3H2MM0JshiBpEj03z+rxpmEFCvSv602cGKiOn76IBRsVTOkoifIE1tG
# fn90KFqqNaRA9yeT7x3mAp1kBRBEnvnMu2mmf6HVb7rFQL3Iyshjle1EjS7XpH2+ 
# WHXRwpMV5C4C3PTMLSM3YJW+4uuDtVZpWo/dLA9vil4NMizgX1XHIGJRFukguG2n
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFJ3lzRLRAIvkV9pg0HjX0jqKd21OMB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAA2ESQyXn0crR1au
# 5n87mZ2nTntlvNlBW9i/CnanNly72jKC/jgNhmZUFRplHqjl4uRsoiJkZrBl6QO/
# RsYUmNsJBxjEqI4Q8uWeNG7wEYcoFbO+O+jpgkkKUrADYVyhVQbacDCxBunpLW4C
# K+D+HUlA0/FEuxdgUJMw2aJ1i3paxZATm6Vfa7uEiQzTeAzCxaR/GlO6dI8orZF8
# nG6cVpYgFKfq9CEKsY7Q8QbfuVUDvPhnf/mBVe4O2sydK2nqxjmgd8GFC0BAQ76N
# XrUGFQm42n9gCGtc2BDLbGZ1iSH93pfI1MIDsELSHOyKSiiL9x06IzVERs94GQUk
# vAt2xLULsWDfhz+jw0653j1tH8aTkUXIZziqFsEUwhjwrY2PEiYl7LgBbNV47gxj
# b3Yhc/zL+PRGt5PDYBaBBHizfKgyjgawaeCGdx3XoAWIzW6zTSfRE55Y7Mgruufd
# qdQPCG7/Sm7dpONoq/dVtuidbni0U3P8CRZOcBJPEa3YG6OvsSqXYBOSlahH34Mw
# qqFdFqlwM9X982lXT7i88i+AFdGVHxa/vW3fjP+kd07Wix9plj3XeM1eWhpTfT0i
# 7X1Yg15re0oDOGsXQddSTfmeFqZk8tQuK8OpUw2aDgYg6RR990HROsNo4G6/XJrY
# GyMm9AkQuLYpD9IbmPyyQF/e8HcyMIIG5zCCBM+gAwIBAgITMwADFR5YOYFmKkDJ
# 3wAAAAMVHjANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDMyNDA3MDAzOVoXDTI1MDMyNzA3MDAz
# OVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJ2m+Gz8
# ilhEKGx6dEeO5XDNNLmcyz4k/dBC+RS23ce9moJy69Xpzwa96ajnw9LXVSdaMkPM
# oLHR9uvmQNOwvANUof81wmSr2j5dU5u5sl1WZIHdKWfF3iUG2WOqm/5yiAFEt9Bi
# 8hshEbiVKF4PQewAoZwyFOM2pfzWSopC07DqDtA/iCH7aBxks40nCEolRjLLvk1i
# awE5Z8WmUDrzwsFIg6V6/llZtgpGkDRPfGCUUa7Yl6ijR7nJy+z7qGgZAkDxGAjX
# n6OvlOleNsH3CL1Y/qG2w5eUybm5jb7Cj9ITYxpa3KS78VDnAsPyJHhFNDPw1c4P
# 1E9x9jDNCbIYgaRI9N8/q8aZhBQr0r+tNnBiojp++iAUbFUzpKInyBNbRn5/dCha
# qjWkQPcnk+8d5gKdZAUQRJ75zLtppn+h1W+6xUC9yMrIY5XtRI0u16R9vlh10cKT
# FeQuAtz0zC0jN2CVvuLrg7VWaVqP3SwPb4peDTIs4F9VxyBiURbpILhtpwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBSd5c0S0QCL5FfaYNB419I6indtTjAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQANhEkMl59HK0dWruZ/O5md
# p057ZbzZQVvYvwp2pzZcu9oygv44DYZmVBUaZR6o5eLkbKIiZGawZekDv0bGFJjb
# CQcYxKiOEPLlnjRu8BGHKBWzvjvo6YJJClKwA2FcoVUG2nAwsQbp6S1uAivg/h1J
# QNPxRLsXYFCTMNmidYt6WsWQE5ulX2u7hIkM03gMwsWkfxpTunSPKK2RfJxunFaW
# IBSn6vQhCrGO0PEG37lVA7z4Z3/5gVXuDtrMnStp6sY5oHfBhQtAQEO+jV61BhUJ
# uNp/YAhrXNgQy2xmdYkh/d6XyNTCA7BC0hzsikooi/cdOiM1REbPeBkFJLwLdsS1
# C7Fg34c/o8NOud49bR/Gk5FFyGc4qhbBFMIY8K2NjxImJey4AWzVeO4MY292IXP8
# y/j0RreTw2AWgQR4s3yoMo4GsGnghncd16AFiM1us00n0ROeWOzIK7rn3anUDwhu
# /0pu3aTjaKv3VbbonW54tFNz/AkWTnASTxGt2Bujr7Eql2ATkpWoR9+DMKqhXRap
# cDPV/fNpV0+4vPIvgBXRlR8Wv71t34z/pHdO1osfaZY913jNXloaU309Iu19WINe
# a3tKAzhrF0HXUk35nhamZPLULivDqVMNmg4GIOkUffdB0TrDaOBuv1ya2BsjJvQJ
# ELi2KQ/SG5j8skBf3vB3MjCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmllZCUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUy
# MDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQu
# Y29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+60si2TAtOng1+H32+tulKwvw
# 3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72gRwBkkOIaMRbK3Mxq8PoGKHe
# cRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE04dmItRC2asXhXojG1QWO8GeK
# Npn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7ohqfdA3diZt197DNK+dCYpuSJO
# JsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJbDDXRt+U54EqqRvdJoI1BPPye
# yFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV+4vgA4YK2g1085avH28FlNcB
# V1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgNZDhpSgJFdywF5GGxyWTuRVc/
# 7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJeS7AILZnhdx/IyM8OGplgA8YZ
# NQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+HLeyfvNQeAgL9iw5MzFW4xCL9
# uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2AgddynYXQ4dxXB7cqcRdrySrMwN+
# tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8XngsbraLp9+FMJ6gVP1n2ltSjaDGX
# JMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAAAAeHozSje6WOHAAAAAAABzAN
# BgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZp
# Y2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAx
# MjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIICIjANBgkqhkiG9w0BAQEFAAO
# CAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJtFL/ekr4weslKPdnF3cpTeu
# V8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgHfjPF/nZsOkg7c0mV8hpMT
# /GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuXWJzBDoLrmtThX01CE1TC
# CvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g
# 9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4
# eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXVNLz8UaeARo0BatvJ8
# 2sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3VT2d/iVd7OTLpSH9
# yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86rcaGMhNsJrhysLN
# NMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5
# yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBG
# fN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwE
# AAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgN
# VHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBgRVHSAAMEE
# wPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9
# jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgN
# VHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIG
# EBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3B
# zL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3Q
# lMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQc
# BAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9
# wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllZCUyMFJ
# vb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MC0GCCsGAQU
# FBzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvc
# NAQEMBQADggIBAHf+60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4
# dlTE0b6s15lr5HO72gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955W
# sriLUsbuMneQ8tGE04dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNC
# scEVYcYNuSbH7I7ohqfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdG
# w858WCfOEtWpl0TJbDDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4
# /ZISkEXtGiUQLeWWV+4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY
# 0WfqRUJzkF10zvGgNZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wH
# oUM7huUa4auiAynJeS7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150
# JqG248wOAHJ8+LG+HLeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7E
# qmD2oN5+Pl8n2AgddynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U
# 40OZa3rUwtC8XngsbraLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8Y
