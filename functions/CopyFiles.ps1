<#
.SYNOPSIS
Copies files from the source folder to the destination folder based on a manifest file.

.DESCRIPTION
The CopyFiles function reads a manifest file in JSON format to determine which functions, scripts, and command files
should be copied from the source folder to the destination folder. It validates the existence of required paths and
handles errors during the copy process.

.PARAMETER SourceFolder
The folder containing the source files to be copied.

.PARAMETER DestinationFolder
The folder where the files will be copied. Defaults to a "Release" subfolder in the source folder.

.PARAMETER FunctionsFolder
The folder containing function scripts. Defaults to a "functions" subfolder in the source folder.

.PARAMETER manifestFile
The path to the manifest file in JSON format. Defaults to a "manifest.json" file in the source folder.

.EXAMPLE
CopyFiles -SourceFolder "C:\Source" -DestinationFolder "C:\Destination"
Copies files from "C:\Source" to "C:\Destination" based on the manifest file.

.EXAMPLE
CopyFiles -SourceFolder "C:\Source"
Copies files from "C:\Source" to the default "Release" subfolder based on the manifest file.

.NOTES
Version: 3.0.0
Author: [Your Name]
#>

function CopyFiles()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $false)]
        [string]$DestinationFolder = "$sourceFolder\Release",
        [Parameter(Mandatory = $false)]
        [string]$FunctionsFolder = "$sourceFolder\functions",
        [Parameter(Mandatory = $false)]
        [string]$manifestFile = "$SourceFolder\manifest.json"
    )
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    Write-Verbose "FunctionsFolder: $FunctionsFolder"
    Write-Verbose "Manifest: $manifestFile"
    $success = $false
    $destinationFunctionsFolder = "$DestinationFolder\functions"
    # Check if any of the required paths do not exist, set $success to false and return $success.
    if (-not (Test-Path -Path $DestinationFolder) -or -not (Test-Path -Path $manifestFile) -or -not (Test-Path -Path $FunctionsFolder))
    {
        Write-Host "Cannot find one or more required paths: DestinationFolder ($DestinationFolder), ManifestFile ($manifest), or FunctionsFolder ($FunctionsFolder)."
        return $success
    }
    # Get the manifest file and convert it to a hashtable.
    $manifest = Get-Content -Path $manifestFile | ConvertFrom-Json
    Write-Host "Read $($manifest.functions.Count) functions, $($manifest.scripts.Count) scripts and $($manifest.cmds.Count) command files from $($manifestFile)."
    foreach ($category in $manifest.PSObject.Properties)
    {
        Write-Host "Processing $($category.Value.Count) $($category.Name)s"
        switch ($category.Name) 
        {
            functions
            {
                foreach ($function in $category.Value)
                {
                    Write-Verbose "Copying $($function.name) to $destinationFunctionsFolder"
                    try
                    {
                        Copy-Item -Path "$FunctionsFolder\$($function.name).ps1" -Destination $destinationFunctionsFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($function.name) to $destinationFunctionsFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) functions."
            }
            scripts
            {
                foreach ($script in $category.Value)
                {
                    Write-Verbose "Copying $($script.name) to $DestinationFolder"
                    try
                    {
                        Copy-Item -Path "$SourceFolder\$($script.name).ps1" -Destination $DestinationFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($script.name) to $DestinationFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) scripts."
            }
            cmds
            {
                foreach ($cmd in $category.Value)
                {
                    Write-Verbose "Copying $($cmd.name) to $DestinationFolder"
                    try
                    {
                        Copy-Item -Path "$SourceFolder\$($cmd.name).cmd" -Destination $DestinationFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($cmd.name) to $DestinationFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) command files."
            }
            Default
            {
                Write-Host 'Unknown category'
            }
        }
    }
    $success = $true
    return $success
}


# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAgcKMI955Mlygo
# LUJ1dMwLBYkmg4gh3+yCSsJpfCZfz6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# cmxpbmd0b24xFzAVBgNVBAMTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
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
# IENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0y
# NjA0MTMxNzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBF
# T0MgQ0EgMDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDH48g/9CHd
# xhnAu8XLq64nh9OneWfsaqzuzyVNXJ+A4lY/VoAHCTb+jF1WN9IdSrgxM9eKUvnu
# qL98ftid0Qrgqd3e7lx50XCvZodJOnq+X88vV0Av2x+gO82l0bQ39HzgCFg2kFBO
# Gk7j8GrGYKCXeIhF+GHagVU66JOINVa9cGDvptyOcecQS1fO8BbAm7RsFTuhFGpB
# 53hVcm0gJW35mgpRKOpjnBSWEB3AeH7fUGekE8LMW0pWIunrMS1HI7FF6BqAVT7I
# uBe++Z3TsgM3RLZMti6JmNPD6Rxg62g2AqvuTQLoT1Z/cfiMdq+TYzGoWm2B8vSA
# v7NtJv5UE0qJVPSarNckgmZaarDQr4Pcwp+YJ6vd7cJus/4XlG0JvRdoTS5Fwk9k
# mNbByIMHEEhuQ0XgYvXaGXm/J2AUybNBw26h0rJf//eUsnWrbaugdVLVyC2wuCmN
# ZhmUGWEJNxcl5nfG5om9dkH2twsJfXk6BcvbW1RTAkIsTbtXkAZnGQ7eLniaBIKz
# C06ZZTgAp38H97cq1e/pcFREq4C157PUSmCWhpnBB6P2Xl031SHxbX0FmD0iUuX7
# EdFfi8OIxYBR//sA17gyhL3wXjmvvogYnSELTYQy4xnEASvBmPSWfRovncTOUxrk
# kKJE5tvRSgsd8ZJ00mwyDS6PcMBAN1VZMQIDAQABo4ICDjCCAgowDgYDVR0PAQH/
# BAQDAgGGMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBR2nDZ0E9GQfWFfswLr
# gPSZS6U+hTBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkG
# CSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYD
# VR0jBBgwFoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZf
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIw
# SUQlMjBWZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmww
# ga4GCCsGAQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQl
# MjBDb2RlJTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFo
# dHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQAD
# ggIBAGovCZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+
# ogqMTfZDozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3f
# BCmzYLVZSP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlAC
# U/+8wbIHQf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTx
# vmWKUiQTnPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM
# /KZiCCcn6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6
# ZhKGcWuBXXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07
# ZsnQ72KRzUmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy
# 7qIxQIUF912w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3E
# zYT/H40fLpMEydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m
# 3CngY4ZGMfnP6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBA
# gITMwAAAAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEw
# JVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWN
# yb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0
# aG9yaXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswC
# QYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQ
# QDEytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJt
# FL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGcgH
# fjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8JuX
# WJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2QfzZFmw
# fccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4Gzg2Y
# c7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmPf6KLXV
# NLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZEZsBRc3
# VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/hFMIQa86
# rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL8F9gn6jOy
# 3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4Fre+ZQ5Od8o
# uwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILhAV5Q/ZgCJ0u
# 2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEE
# AwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYDVR0gBE0wSzBJBg
# RVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQT
# APBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiM
# IGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBD
# ZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtjCB
# szCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmllY2F0aW9uJTIwUm9vdCUyMENl
# cnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6
# Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20vb2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdM
# g30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQB/
# JSqe/tSr6t1mCttXI0y6XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bgu
# orTCNr58HOcA1tcsHQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4
# pkeAhBEjABvIUpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8B
# mQXv5hT2RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59P
# YwISFCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyzwdG/
# L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+zt6J0Gwz
# vU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifaIMYTzU4YKt4v
# MNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7VB7fwT4ze+ErCbMh
# 6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6EnTiOL60cPqfny+Fq8Uiu
# ZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0IElEIFZlcmlmaWVkIENTIEVPQyBD
# QSAwMQITMwACLjx0xzKgoQoUeAAAAAIuPDANBglghkgBZQMEAgEFAKBeMBAGCisGAQQB
# gjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEi
# BCBlGYi+NP8rxOB1NK9GWw0VWZazstcc/61bMi3a996HmDANBgkqhkiG9w0BAQEFAASC
# AYBeAnkvgzuaAT71G1SiP/MlVuRm71SqxWVfM6pmY4+m39+UEK9T1rEjfs1AS018s4qj
# FcZyN/wkXL6uBUvrPUfkIT31rOmYtOv2aIfpuD130P3Erxak5eEUvcs5fOm8dD5bWcp8
# SbOlvoK4o6yS5ctZ7uA2i8o461nguIYN0HPYEWXp8le2rIKrIY/toHf4i8nzuBFDcf0w
# 2Pz+beccDYXgESKGEhCHfY6bf1+Tsx9fQxcItJ/4ELzNgcP+ZcvrbOCq5oBxO4BWjEsU
# NAeDbKrFdNGRMVAULRIH5RtIOqG3WHIoKea5wc1iQdlho+//8RRwy5L1cLfU9yT2Rkz2
# LMkxPkZjioraiAXoqBONic/WmsivmLBH9C7g1Fs/r30T3R/5cAuwqg7AsptsTjznpqtw
# SX18p05ACUKdCgWMDIUS5uHT9Z+U129ZJSWJfqlmo4f+qPZeaXxhMLjWCbhmxw1/esju
# ko1visXdJKnabnbBBtGF7JrmDgNJq1LGG1Yv1e6hghgRMIIYDQYKKwYBBAGCNwMDATGC
# F/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBYgYL
# KoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQME
# AgEFAAQglJSLxrimRhyUYaUx7BaSYXTUI1g4azDjOrVTsXP38u8CBmfdoLig9xgTMjAy
# NTAzMjQwNDA1MzAuNzc1WjAEgAIB9KCB4aSB3jCB2zELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9u
# czEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjc4MDAtMDVFMC1EOTQ3MTUwMwYDVQQD
# EyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEw
# ggeCMIIFaqADAgECAhMzAAAABeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcx
# CzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNV
# BAMTP01pY3Jvc29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGEx
# CzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eXM9ET
# Bb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3TOYtgoBjx
# nG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/Ssah8nWo5hJM1
# xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i5F9YciFlyAKwn6yj
# N/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx69uKqKhTPVi3gVErnc/qi
# +dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3GgZwetEKxLms73KG/Z+MkeuaV
# DQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2HVJo9XxRYR/JPGAaM6xGl57Ei95H
# Uw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTk
# mG1hSuWYBunFGNv21Kt4N20AKmbeuSnGnsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo
# 3liwkGdzPJYHgnJ54UxbckF914AqHOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo
# 27xjlLAHWW3l1CEAFjLNHd3EQ79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB
# /wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0np
# Ptk92yEwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTAD
# AQH/MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQl
# MjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1
# dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYIKwYBBQUHMAKG
# dWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# SWRlbnRpdHklMjBWZXJpZmllY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRlJTIwQXV0
# aG9yaXR5JTIwMjAyMC5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jv
# c29mdC5jb20vb2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUF
# BwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9y
# eS5odG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcsHQqt
# 0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvIUpD2LKPh
# o5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2RurVsJHZgP4y
# 26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwISFCX2DaLZ+zpU4bX0
# I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6mvNIxTk4OaswIkTXbFL8
# 1ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyzwdG/L6uderJQn0cGpLQMStUu
# NDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+zt6J0GwzvU8g0rYGgTZR8zDEIJfe
# ZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifaIMYTzU4YKt4vMNwwBmetQDHhdAtTPplO
# XrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K
# 4aMfZN1oLVk6YFeIJEokuPgNPa6EnTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEw
# WjELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkG
# A1UEAxMiTWljcm9zb2Z0IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACLjx0xzKg
# oQoUeAAAAAIuPDANBglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBlGYi+NP8rxOB1NK9G
# Ww0VWZazstcc/61bMi3a996HmDANBgkqhkiG9w0BAQEFAASCAYBeAnkvgzuaAT71G1Si
# P/MlVuRm71SqxWVfM6pmY4+m39+UEK9T1rEjfs1AS018s4qjFcZyN/wkXL6uBUvrPUfk
# IT31rOmYtOv2aIfpuD130P3Erxak5eEUvcs5fOm8dD5bWcp8SbOlvoK4o6yS5ctZ7uA2
# i8o461nguIYN0HPYEWXp8le2rIKrIY/toHf4i8nzuBFDcf0w2Pz+beccDYXgESKGEhCH
# fY6bf1+Tsx9fQxcItJ/4ELzNgcP+ZcvrbOCq5oBxO4BWjEsUNAeDbKrFdNGRMVAULRIH
# 5RtIOqG3WHIoKea5wc1iQdlho+//8RRwy5L1cLfU9yT2Rkz2LMkxPkZjioraiAXoqBON
# ic/WmsivmLBH9C7g1Fs/r30T3R/5cAuwqg7AsptsTjznpqtwSX18p05ACUKdCgWMDIUS
# 5uHT9Z+U129ZJSWJfqlmo4f+qPZeaXxhMLjWCbhmxw1/esjuko1visXdJKnabnbBBtGF
# 7JrmDgNJq1LGG1Yv1e6hghgRMIIYDQYKKwYBBAGCNwMDATGCF/0wghf5BgkqhkiG9w0B
# BwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBYgYLKoZIhvcNAQkQAQSgggFR
# BIIBTTCCAUkCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQglJSLxrimRhyU
# YaUx7BaSYXTUI1g4azDjOrVTsXP38u8CBmfdoLig9xgTMjAyNTAzMjQwNDA1MzAuNzc1
# WjAEgAIB9KCB4aSB3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEl
# MCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjc4MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMz
# AAAABeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJ
# ZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjANBgkqhkiG9w0BAQEFAAOCA
# g8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eXM9ETBb1lRkd3kcFdcG9/sqtDl
# wxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3TOYtgoBjxnG/eViS4sOx8y4gSq8Zg4
# 9REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/Ssah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa
# 1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B
# 8U/pdoZkZZQbxNlqJOiBGgCWpx69uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqIN
# Gbmw5OIRC0EsZ31WF3Uxp3GgZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55n
# gI0Tdy1bi69INBV5Kn2HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJ
# QawSC3xzY/EXzsT4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N
# 20AKmbeuSnGnsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54Uxbc
# kF914AqHOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLN
# Hd3EQ79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0gBE0w
# SzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkr
# BgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAu
# Y3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJp
# ZmllY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5j
# cnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20vb2NzcDBm
# BgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wCAYGZ4EMAQQB
# MA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6XmyQ41uGWzl9xw+WYhvO
# L47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcsHQqt0wJsdClsu8bpQD9e/al+
# lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvIUpD2LKPho5Z4DPCT5/0TlK02nlPw
# Ubv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2RurVsJHZgP4y26dJDVF+3pcbtvh7R6NE
# DuYHYihfmE2HdQRq5jRvLE1Eb59PYwISFCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA
# 1vRElItaOKcwtc04CBrXSfyL2Op6mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7
# VHLfnxlMVzHQVL+bHa9KhTyzwdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWg
# KA8Kqv48M8HfFqNifN6+zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LI
# AtB7o9PXbjXzGifaIMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/
# 7ygbahmYOHk7VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEok
# uPgNPa6EnTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACLjx0xzKgoQoUeAAAAAIuPDANBglg
# hkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBlGYi+NP8rxOB1NK9GWw0VWZazstcc/61bMi3a
# 996HmDANBgkqhkiG9w0BAQEFAASCAYBeAnkvgzuaAT71G1SiP/MlVuRm71SqxWVfM6pm
# Y4+m39+UEK9T1rEjfs1AS018s4qjFcZyN/wkXL6uBUvrPUfkIT31rOmYtOv2aIfpuD13
# 0P3Erxak5eEUvcs5fOm8dD5bWcp8SbOlvoK4o6yS5ctZ7uA2i8o461nguIYN0HPYEWXp
# 8le2rIKrIY/toHf4i8nzuBFDcf0w2Pz+beccDYXgESKGEhCHfY6bf1+Tsx9fQxcItJ/4
# ELzNgcP+ZcvrbOCq5oBxO4BWjEsUNAeDbKrFdNGRMVAULRIH5RtIOqG3WHIoKea5wc1i
# Qdlho+//8RRwy5L1cLfU9yT2Rkz2LMkxPkZjioraiAXoqBONic/WmsivmLBH9C7g1Fs/
# r30T3R/5cAuwqg7AsptsTjznpqtwSX18p05ACUKdCgWMDIUS5uHT9Z+U129ZJSWJfqlm
# o4f+qPZeaXxhMLjWCbhmxw1/esjuko1visXdJKnabnbBBtGF7JrmDgNJq1LGG1Yv1e6h
# ghgRMIIYDQYKKwYBBAGCNwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEP
# MA0GCWCGSAFlAwQCAQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisG
# AQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQglJSLxrimRhyUYaUx7BaSYXTUI1g4azDj
# OrVTsXP38u8CBmfdoLig9xgTMjAyNTAzMjQwNDA1MzAuNzc1WjAEgAIB9KCB4aSB3jCB
# 2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9z
# b2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjc4
# MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFNu
# dGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMVAJueWs/5vWNYP+JGxmOfpj88
# ZvzBoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBD
# QSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA64rCNjAiGA8yMDI1MDMyMzE3MjQwNloYDzIw
# MjUwMzI0MTcyNDA2WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDrisI2AgEAMAcCAQAC
# Aiu0MAcCAQACAhN0MAoCBQDrjBO2AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBADnh
# xx9fHb7RIFVoFmFrm9QLUihvsg/pTjimorTQGg0i6pczCrB1LwtNd960oDCZKufyIP2E
# B6kTfksc3V74dsvDtds8BMji1jl6VvPJqArpxvUEGA4N+hL7TnEnplqe0/9vxS71N2C0
# eFBgZKk1a6DRgtVNW/VJcghEVjLuBr2SuI4KRwJacbiIur+Lsq2XJrWknsKfyAZEzDBa
# xgJnYYAyZ5wgZaxDRO6cXszU9vcs/Jl+DBwdDC/nXq9v55wZQh5h5RVUepgaHm/eNtN4
# iP34vO6YPPnPxXjUQYTMBdzKJDm+3hBuG1cauttwM8LfTGKrrrGZj4wLPOpcU7qWZU0w
# DQYJKoZIhvcNAQEBBQAEggIAFWwcDs0UgcmErpwzcZfvnFR61jeYv7KggMeGqQzmOugf
# 3+CsQsFincxnpYIzHfV3f6AP209kQKhOrxk/21Jrugf6Tk8CmVD+Turu
# jN6JG6wkyTFN31S8vb8DtjsaP2keTSXBXyM8hzgb0DDey0RRWlpxDHUidCH8u+yV2ExD
# YaGIU8i+/Qfwd/mH3eeHyyPu5jTsCZ1UY6fy2+EbCty9hZhCp+xN4ky1SWw3EZ1sLezc
# b2WxqbijBISRPZ8ziBdQgkGkclBiKEYyneZuxBYl/WIgaG31fBSijCCNC/i+CfC54iFs
# UHdt64SDUvUGatbVXoZHr7Idy+mzMvPZWxDgkmdDR+Ftfd+CFlm83u3lHKf80GQbT1ks
# iqifMtq8t8CNNaQJuTWgVaTUg3CcEn/i8zKLz1e3bHcB+8B1p5t2HmZhEfbalIWgwLQ6
# eo5kW7MoV3vXl/h68JAxXw2i1923o5+Lj4I8ddeQmJ2cOXF2cRWdQZvKgvlNQbi0kibN
# +ucygAT1+le3Xjp1FC8BdZAMIbUXIh+COVVm7xDVj4T7X3fNMsy21yp8q2agUVcsuDPJ
# Tgz5+9Y+CsdI9pSHhPNTiTHlklL2xNkOHX97eGz8HEXaZY8vbtBgFytDfkDQP8oLmxjK
# AY+BjkyTtepKECBEFrx7UzFaOb10ccC04778laY=
# SIG # End signature block
