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
# MII94AYJKoZIhvcNAQcCoII90TCCPc0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+5dBqgVHJJSJS
# jH3Ed0lgYEZhDyeyzQOxWxRMjbupPKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAIuPHTH
# MqChChR4AAAAAi48MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwMzIzMDcwNTE3WhcNMjUwMzI2
# MDcwNTE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# jq07Oc856+3Ar5sHEN8BkdCRP7uZCDM2SCvyXjno19/OfMlTIkrkSTVhd7t89i/R
# z8rZh0Paeqx9kJVzbLPgaiHQjQNjBiAOaBCNXrbI/BO4+VQSbufELlhbuPUvMENu
# Z9LXtgYfdpR3rdhukeDuyFtehpr4AU0IgGbfEiR2FPqsVibESebdB7hS2qfUntC5
# kyi2lRUJ5juOvOvV7CUWeG4gGf68td0yILRbXTAuO6Xdjp8DIHvJbVbAmifiWctR
# gqITnSBgdX8KRTyFyKA1nWsKA1xFzRB1B7ZWvanBZG7eMcDCRUsAgpVKJIxIz9sM
# ArrJIEzgSWUxRtbaxEAiTe3Aaln4JrjR6ngPJLN+Ueq8Rz7wWGxDRtnbf23skByf
# YYTw90kmeAWt1NuYvyxvlgYaRq1m+snwfZ85h+WlbecP1jCt8Is29grlcCrthiaZ
# BuEt3VDk+gHL5Yyx1ZmHbiPv103w5s5n8WMz1n2Yrsyxho90+0zWXNCQHgCfxDmP
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFP0DrSq+3Bg1I0fWPLvz2OOId/T2MB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAIa5KqNBil9JzDDA
# bwYwAtBECoU1CaE3A5gjRdWU1G9PanUkG0EVOyPG2/bn4tz9A3pPZLqTk+g6jdWY
# 0w526YhOJzYV/YysDZN6Few33TgXcW4S4dlF29nNhcBre7KQYRmDO8S194hoFq0h
# fvaSTp2Pbvz5nofEhQxmB1sxA9gbAaXhUqJ61wVJZNEtN9H83Ia+9qFJl+gJU/8g
# TliqE/HM7op+05r08x/46tLoYhvBL8tJ1GA3JMB3RM7xBvu0sELgvNJSqI3gUL8W
# HJYkUuCN4uv86r/0F/mo+0/zUtVpKp112QmCCjTj/XkRMV63In94t2FpmqQFNVmm
# bRLMEMHJeLLUYfW05FfobW5j49rEuswDkQwhBBWvqugHzdEKFsmGPn3Mw2zUUwTm
# /FOHNOHvEN2sCl2N1hgZRsqnnX+otH7/60nQz0vDoRC2ssYZxS8Ck2Guv884wPrb
# WfxL9Yykc51gbT7ywcrJpLgCRO9D1krtTR/j2MTttT3hrb1E38zaOjknlLvuBDAE
# M3usM5sQiy2AAMHAjoYH6Mb1E+p6Nf4F5vfL7F2almZUMi9tMxFwsBcw3FAH35vA
# wM669BBGPYG0e7QcLWLxofYNfGNmG3L8M2lpR/m/POFOnZwDfRR5WI+YAXS5Awc2
# A2NremqS9vgmvambJYB4wW2ynPzmMIIG5zCCBM+gAwIBAgITMwACLjx0xzKgoQoU
# eAAAAAIuPDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDMyMzA3MDUxN1oXDTI1MDMyNjA3MDUx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAI6tOznP
# OevtwK+bBxDfAZHQkT+7mQgzNkgr8l456NffznzJUyJK5Ek1YXe7fPYv0c/K2YdD
# 2nqsfZCVc2yz4Goh0I0DYwYgDmgQjV62yPwTuPlUEm7nxC5YW7j1LzBDbmfS17YG
# H3aUd63YbpHg7shbXoaa+AFNCIBm3xIkdhT6rFYmxEnm3Qe4Utqn1J7QuZMotpUV
# CeY7jrzr1ewlFnhuIBn+vLXdMiC0W10wLjul3Y6fAyB7yW1WwJon4lnLUYKiE50g
# YHV/CkU8hcigNZ1rCgNcRc0QdQe2Vr2pwWRu3jHAwkVLAIKVSiSMSM/bDAK6ySBM
# 4EllMUbW2sRAIk3twGpZ+Ca40ep4DySzflHqvEc+8FhsQ0bZ239t7JAcn2GE8PdJ
# JngFrdTbmL8sb5YGGkatZvrJ8H2fOYflpW3nD9YwrfCLNvYK5XAq7YYmmQbhLd1Q
# 5PoBy+WMsdWZh24j79dN8ObOZ/FjM9Z9mK7MsYaPdPtM1lzQkB4An8Q5jwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBT9A60qvtwYNSNH1jy789jjiHf09jAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCGuSqjQYpfScwwwG8GMALQ
# RAqFNQmhNwOYI0XVlNRvT2p1JBtBFTsjxtv25+Lc/QN6T2S6k5PoOo3VmNMOdumI
# Tic2Ff2MrA2TehXsN904F3FuEuHZRdvZzYXAa3uykGEZgzvEtfeIaBatIX72kk6d
# j278+Z6HxIUMZgdbMQPYGwGl4VKietcFSWTRLTfR/NyGvvahSZfoCVP/IE5YqhPx
# zO6KftOa9PMf+OrS6GIbwS/LSdRgNyTAd0TO8Qb7tLBC4LzSUqiN4FC/FhyWJFLg
# jeLr/Oq/9Bf5qPtP81LVaSqdddkJggo04/15ETFetyJ/eLdhaZqkBTVZpm0SzBDB
# yXiy1GH1tORX6G1uY+PaxLrMA5EMIQQVr6roB83RChbJhj59zMNs1FME5vxThzTh
# 7xDdrApdjdYYGUbKp51/qLR+/+tJ0M9Lw6EQtrLGGcUvApNhrr/POMD621n8S/WM
# pHOdYG0+8sHKyaS4AkTvQ9ZK7U0f49jE7bU94a29RN/M2jo5J5S77gQwBDN7rDOb
# EIstgADBwI6GB+jG9RPqejX+Beb3y+xdmpZmVDIvbTMRcLAXMNxQB9+bwMDOuvQQ
# Rj2BtHu0HC1i8aH2DXxjZhty/DNpaUf5vzzhTp2cA30UeViPmAF0uQMHNgNja3pq
# kvb4Jr2pmyWAeMFtspz85jCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
# AAYwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDH48g/9CHdxhnAu8XL
# q64nh9OneWfsaqzuzyVNXJ+A4lY/VoAHCTb+jF1WN9IdSrgxM9eKUvnuqL98ftid
# 0Qrgqd3e7lx50XCvZodJOnq+X88vV0Av2x+gO82l0bQ39HzgCFg2kFBOGk7j8GrG
# YKCXeIhF+GHagVU66JOINVa9cGDvptyOcecQS1fO8BbAm7RsFTuhFGpB53hVcm0g
# JW35mgpRKOpjnBSWEB3AeH7fUGekE8LMW0pWIunrMS1HI7FF6BqAVT7IuBe++Z3T
# sgM3RLZMti6JmNPD6Rxg62g2AqvuTQLoT1Z/cfiMdq+TYzGoWm2B8vSAv7NtJv5U
# E0qJVPSarNckgmZaarDQr4Pcwp+YJ6vd7cJus/4XlG0JvRdoTS5Fwk9kmNbByIMH
# EEhuQ0XgYvXaGXm/J2AUybNBw26h0rJf//eUsnWrbaugdVLVyC2wuCmNZhmUGWEJ
# Nxcl5nfG5om9dkH2twsJfXk6BcvbW1RTAkIsTbtXkAZnGQ7eLniaBIKzC06ZZTgA
# p38H97cq1e/pcFREq4C157PUSmCWhpnBB6P2Xl031SHxbX0FmD0iUuX7EdFfi8OI
# xYBR//sA17gyhL3wXjmvvogYnSELTYQy4xnEASvBmPSWfRovncTOUxrkkKJE5tvR
# Sgsd8ZJ00mwyDS6PcMBAN1VZMQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBR2nDZ0E9GQfWFfswLrgPSZS6U+
# hTBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGov
# CZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZD
# ozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZ
# SP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIH
# Qf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQT
# nPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn
# 6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KR
# zUmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF
# I912w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40
# fLpMEydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4Z
# GMfnP6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAA
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
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpAwghqMAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACLjx0xzKgoQoUeAAAAAIuPDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCtCvxdu0SqsoIlusBINkA7FfaZ
# T8MwFEpj+YnC/WaV1jANBgkqhkiG9w0BAQEFAASCAYAQjGgg66CJ+eIDh79qNLBn
# e+b8EdZE1PdoIHFZXfodEfSSq0erdpLqmV8ZGsSmOOWCrWL6Lncmqpd/baXjC6uq
# rbKsH8ONAgE/RM6kE9tv0v11I2eKoJRg9lQiZs9Bzuez6btyIcY7dLiMUpyYRT+V
# Wq1/onxzLLkptSuLhchBrdEA/iL5hgq8zcbEnQWRLTbwBjb+/CrfEZ0fv3Sfdkc5
# n3h98XTE/vMvYlTIW6a8v1niy04jFIBTczVBoyZqGlVbmRMvviICp8sxVt8+K9I5
# GZJyVFZGgpWnz4ruxiWHRJ1CC3TrNbuCRICTRCUzc5Evt0TX2Mb4AB5AxEhOh5CT
# f3xNFiXN0AkSEAoD5E6uSDPOwD+VKqJOKL8m96AqQBAe3up/bUd2lSLa891J9jOO
# R1VoW0mXuRP4D3oMx3Cr7DGcPGEC66YctHglxCsRZ6SrDTuizBWReWggZ+BEd2By
# MBprJGxLtrAsiLP5WMwRu+Ar90QgACwCVWswCL3tfMmhghgQMIIYDAYKKwYBBAGC
# NwMDATGCF/wwghf4BgkqhkiG9w0BBwKgghfpMIIX5QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQghHYXC6MDsWjxFe5gO7n1HWNqEJ3OvUaaukSdo5uk
# fcECBmfdoLiwjRgSMjAyNTAzMjQwNDI3NTMuMjlaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046NzgwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABMG0ucY8Lk03oAAAAAAEwwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU5WhcNMjUxMTE5MTg0ODU5WjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjc4MDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANx17xcRfgeMRNi7
# pge1aI/v7pV/Zpt5Sj+yLg1xp6IqtExMXwXuakKg8nKj+HlUduHIoNlrM6bVwu7M
# p5UQzMM3i+5/d9lvmFKWlWUJcFIndgEvAudEm1Y2T5eRQxwBz3pF1qVOhVhaW04j
# BsIKSMTjZ+cJp/CNlqPDVQZrGXi1FA0fBWTmDALbCVVVIlEQmoJKwH1NdccgrE8e
# ecUmon8sjWCgn5V7QFqvg+IqIx+e+dnwtHeS1bbhfoUNAlEouOclDQlV5tAS8j6r
# xj9+uF5SV1d4tUPhJ9A2XV8so3nyj40mxYjQRPoLzBhlz5674SqvO5sg9cHuYoj1
# xu2YYe/O2yXPUr82ZG8YZCR4oQp05Z+l9G5jGaGZ5WZHVAwt7mkFxwmJfDs9Qhb7
# cwHSkzlIEXkUfog21PWB/m8fAED29t6KKCBuKMky4rSq7rewhtsT9g3iJisJRG+N
# lqamxO3GaUS033bU3Spc202BTS9q91z+8mX+sN5/p8x5C4kCKcgfFwnM8NOw5dmV
# 6DBwKv8nnZ6KPpP2zMyU9IJBUC3m79qA1wnbXa3qp3BniFhgXguQKZdCAM9mlHWU
# YMJqiMAHrPL8fucwT6edO9OBMy1Hh3iUdUFDGkkOe9g28Y+6uuc/sVlPe57xjN8U
# SITlyGYmJrxMd7GzjoXy0KvxPlTFAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUauoj
# dLG7fnuspPKWmDBxUAXU3D8wHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQAAVhx3uus1UdFlah+ETh+31g1k
# 9UTNpD3SIT/mQIOhCUIpMTuMVicVx/EROsvh53wlKPQnEJlIlBVTASnqFpRI+SJK
# DiZ/uur6bepsKMcHwOPzauwVLECzw2oj/TwOrUKL+vFWGvI85Jma1dGA14nPHAOp
# JyHnSk0EZAxTwA8tKfCmrOHBE3vowrk9dgJWqb+7+/nv358UmHRsizDj3/BNxMJe
# HezQL3LSICZK+wkqdN8S+19755L2rDbDJ/Yt0nmfySUUno60ODxgH2f4T7S9fUQk
# gM/E3bJfv7awmIAFxRJznmMgfE9MCsN3NHRhTBAiNk7SP2EiPIxtFiOCMnhQr1ku
# u83adTJzS6kuooq+ECoo/WNfQUvkzTC6d5n39IbLZkWf8GDwhIE6nfiuL7jXa06X
# OpH1lT4JT1efUypxZe+8OFOqN7HEpkxVEyoaNEQJBZIDrZZ0IZiMQ5acfmVAmoth
# GFil4DC+OzN0QCNIW0VcUsZNHDhtIqhp3lONQS+woU7wNU8KOtswTMZ2S7jOeZ4V
# 11updHjUeW6enI4u5KgLUgj8GH5pfSdTX0lTv1PXQ4VEpkMUpQjctYH2NN1P7cQ4
# mv+lDlPR8V56LQDtR2ZOBduY/ghoJtNzjU0bsoyayZXpfJqeTioHlpIvfS56Cuu+
# cc+NAEstiN6sYI21AzGCB0Mwggc/AgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABMG0ucY8Lk03oAAAAA
# AEwwDQYJYIZIAWUDBAIBBQCgggScMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyNDA0Mjc1
# M1owLwYJKoZIhvcNAQkEMSIEIGlVb+RWOSkrzk0BZaoTuM+Vmma8SWVYRvxLV0d7
# p0XiMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg3jps6hWaqnZG38bpMjxU
# hmSDuonw512I8OqTqNj6aJ0wfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABMG0ucY8Lk03oAAAAAAEww
# ggNeBgsqhkiG9w0BCRACEjGCA00wggNJoYIDRTCCA0EwggIpAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjc4MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# m55az/m9Y1g/4kbGY5+mPzxm/MGgZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# isI2MCIYDzIwMjUwMzIzMTcyNDA2WhgPMjAyNTAzMjQxNzI0MDZaMHQwOgYKKwYB
# BAGEWQoEATEsMCowCgIFAOuKwjYCAQAwBwIBAAICK7QwBwIBAAICE3QwCgIFAOuM
# E7YCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAweh
# IKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAOeHHH18dvtEgVWgWYWub
# 1AtSKG+yD+lOOKaitNAaDSLqlzMKsHUvC0133rSgMJkq5/Ig/YQHqRN+SxzdXvh2
# y8O12zwEyOLWOXpW88moCunG9QQYDg36EvtOcSemWp7T/2/FLvU3YLR4UGBkqTVr
# oNGC1U1b9UlyCERWMu4GvZK4jgpHAlpxuIi6v4uyrZcmtaSewp/IBkTMMFrGAmdh
# gDJnnCBlrENE7pxezNT29yz8mX4MHB0ML+der2/nnBlCHmHlFVR6mBoeb94203iI
# /fi87pg8+c/FeNRBhMwF3MokOb7eEG4bVxq623Azwt9MYquusZmPjAs86lxTupZl
# TTANBgkqhkiG9w0BAQEFAASCAgBpDGJ6X7rKlRwTkQpteVYFaDNl833LqXXyHWLu
# 5QeaFVh+N0Xi7ZwGqTG0/GkwxKx4THA1JtExjTIV+NvJ9W34dfRT2VLfgau5E8DG
# 22VmGrjhzpDHDgTr6kus/c7xrgRFsTv2eQTp9eq84AjvquLhbK3HlXJ2mi0+31np
# 7j0CXRIcN/M4Le2B7fgxuPV6cbZ16sRsTagDJHXfgaTTebuTAzsGyeX91Edab7V2
# /ZLMjtFxh1bO7QNIBOLs1a0VYosrwP6/T1pkLosnTbSEIpK0Eanh4QnwCYex4NDH
# d63MrtagysOYKkd+nV2MqEcUUKnC+lhwnxgFCCBChIyjlUez+Cdd19+Qk1nrv3cI
# 5O6kPeDShddrIBpozI2v+Dh/Pa5iUfIyr2I2CMgePLKR6+JZasajRNKtsMvaoh44
# sjo5ODl7xz+tRBW3oEWZzv2hnk5DAQVsnAwgfVF/zX75xeyNj5Pf4uoCJnx3h1ZZ
# CeggXs8xe+QT9Wo7WBZR/aVuiphQdCHMxxoSERKotVTva00Y9VoF8JCBxdHpyIEo
# uN1OM9kHnnwZIyVVogyrPoHeGBZbouHiW2+N7WmvNxmbRbIFjpOmdrqBYEVYmKac
# 3DREqVKHHr4HxsB8snh/TwDU0MXLhrhdTNbUGrQOe1sIAme3oKmBNPdDkbgSvh0n
# B6b7yA==
# SIG # End signature block
