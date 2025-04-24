<#
.SYNOPSIS
Checks for updates to scripts by comparing a local manifest with a remote manifest.

.DESCRIPTION
The CheckForScriptUpdates function retrieves a remote manifest and compares it with the local manifest content. It identifies scripts that are missing, outdated, or up-to-date. If updates are found, it generates an updated manifest and optionally writes the remote manifest to a file.

.PARAMETER RemoteManifestPath
The URL or path to the remote manifest file.

.PARAMETER LocalManifestContent
The content of the local manifest as an array of objects.

.EXAMPLE
CheckForScriptUpdates -RemoteManifestPath "https://example.com/manifest.json" -LocalManifestContent $localManifest
Compares the local manifest with the remote manifest at the specified URL and returns an updated manifest if changes are detected.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 4b825dc2-8a00-3a93-830e-4b00e8b8d8a1
Date: April 5, 2025
#>
function CheckForScriptUpdates
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$RemoteManifestPath,
        [Parameter(Mandatory = $True)]
        [System.Object[]]$LocalManifestContent,
        [string]$Application = $Application
    )

    #write verbose record of all parameters passed to the function.
    Write-Verbose "RemoteManifestPath: $RemoteManifestPath"
    Write-Verbose "LocalManifestContent: $($LocalManifestContent | ConvertTo-Json -Depth 10)"
    Write-Verbose "Local manifest functions: $($LocalManifestContent.functions.count)."
    # If LocalManifestContent is an object for a single application, ensure we reference its properties directly
    Write-Verbose "Local manifest scripts: $($LocalManifestContent.scripts.Count)"
    Write-Verbose "Local manifest cmds: $($LocalManifestContent.cmds.count)."
    Write-Verbose "Local manifest configurations: $($LocalManifestContent.configurations.count)."
    $updatedManifestContent = @{
        $application = @{
            "Functions"      = @()
            "Scripts"        = @()
            "Cmds"           = @()
            "configurations" = @()
        }
    }   
    
    Write-Verbose "Retrieving remote manifest from $RemoteManifestPath"
    $response = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get -UseBasicParsing
    if ($response.gettype().name -eq 'string') 
    {
        Write-Verbose "Response is a string. Attempting to parse as JSON."
        $response = $response.Substring(1, $response.Length - 2)
        Write-Verbose "Removed first and last characters from response..."
        # Unescape any escaped quotes
        $response = $response -replace '\\\"', '"'
        Write-Verbose "Removed double quotes..."
        # Unescape any escaped newlines
        $response = $response -replace '\\r\\n', "`r`n"
        Write-Verbose "Removed single quotes..."
    }
    Write-Verbose "Attempting to convert response to JSON."
    $remoteManifestContent = ($response | ConvertFrom-Json).$Application
    #Check if the conversion worked.
    if ($response.gettype().name -ne 'string') 
    {
        Write-Verbose "Looks like it may have worked."
        Write-Verbose "Attempting to continue..."
    }
    else
    {
        Write-Verbose "Failed to convert response to JSON.
        write-verbose " "This will likely result in an error."
    }
    Write-Verbose "Read $($LocalManifestContent.functions.count) functions, $($LocalManifestContent.scripts.count) scripts, $($LocalManifestContent.cmds.count) cmds and $($LocalManifestContent.configurations.count) configurations from the local manifest."
    Write-Verbose "Read $($remoteManifestContent.functions.count) functions, $($remoteManifestContent.scripts.count) scripts, $($remoteManifestContent.cmds.count) cmds and $($remoteManifestContent.configurations.count) configurations from the remote manifest."

    foreach ($type in $remoteManifestContent.PSObject.Properties)
    {
        Write-Verbose "Processing $($type.Value.count) $($type.Name)"
        switch ($type.Name)
        {
            functions
            {
                $fileExtension = 'ps1'
            }
            scripts
            {
                $fileExtension = 'ps1'
            }
            cmds
            {
                $fileExtension = 'cmd'
            }
        }
        foreach ($remoteItem in $remoteManifestContent.$($type.Name))
        {
            $localItem = $LocalManifestContent.$($type.Name) | Where-Object { $_.name -eq $remoteItem.name }
            Write-Verbose 'comparing items:'
            Write-Verbose "Local item name: $($localItem.name).$fileExtension"
            Write-Verbose "Local item version: $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build)"
            Write-Verbose "Remote item name: $($remoteItem.name).$fileExtension"
            Write-Verbose "Remote item version: $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
            $remoteItemVersion = New-Object System.Version -ArgumentList (
                $remoteItem.version.Major,
                $remoteItem.version.Minor,
                $remoteItem.version.Build,
                [Math]::Max($remoteItem.version.Revision, 0)
            )
            $localItemVersion = New-Object System.Version -ArgumentList (
                $localItem.version.Major,
                $localItem.version.Minor,
                $localItem.version.Build,
                [Math]::Max($localItem.version.Revision, 0)
            )
            Write-Verbose "Variable declaration for local item version: $localItemVersion"
            Write-Verbose "Variable declaration for remote item version: $remoteItemVersion"
            if ($null -eq $localItem)
            {
                Write-Verbose "Script $($remoteItem.name) not found in local manifest. Adding to updated manifest and queuing for download."
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'add' }
            }
            elseif ($localItemVersion -lt $remoteItemVersion )
            {
                Write-Verbose "Updating script $($remoteItem.name) from version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) to version $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'update' }
            }
            else
            {
                Write-Verbose "script $($remoteItem.name) with version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) is up to date."
                # $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'none' }
            }
        }
    }
    Write-Verbose "Updated manifest content: $($updatedManifestContent | ConvertTo-Json -Depth 10)"
    if ($updatedManifestContent.functions.count -eq 0 -and $updatedManifestContent.scripts.count -eq 0 -and $updatedManifestContent.cmds.count -eq 0 -and $updatedManifestContent.configurations.count -eq 0)
    {
        Write-Verbose "No updates found. Returning empty array."
        $updatedManifestContent = @()
    }
    else
    {
        Write-Verbose "Updated manifest content: $($updatedManifestContent.functions.count) functions, $($updatedManifestContent.scripts.count) scripts, $($updatedManifestContent.cmds.count) cmds and $($updatedManifestContent.configurations.count) configurations."
        $remoteManifestContent | ConvertTo-Json -Depth 10 | Set-Content -Path remoteManifest.json
    }
    return $updatedManifestContent
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCClH/EwST7oYCAD
# gvKdmLFAhmzuOu5dqfSagC89lm8cjKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAKZLXLd
# C8+fUGcaAAAAApktMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwNDI0MDQ0MDMyWhcNMjUwNDI3
# MDQ0MDMyWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# 5hkQco7D48Z2PmxPIwWxayf0baRANPffCssfn1K0fRYGRfQbTSSEdqgWsJswpFNj
# 1AhRtJ3a42Hz9B6r+zZaJuKpm5rsDblGRQhmjATshSnnCGQetusKd7HLVunqUPWM
# 50kxoXlUJfl4EeJCYYa5zp99jWYWf5hwONhbNv0vMTGBNeN8h8PyPDOQR0Bq9Aid
# muLfT2yCS+mvhg9Lmgw38catxujNMwaHzSYha9iWhhb2Uwimqr/F3OFegP4fd2rl
# 3nEJoCAer3hDUenQtaY+C4ODEy/8juIGIuB5jdZ2/jdZkBp4ZEa0gNeab3083D5o
# B16F+51GOGcAH5C4jbSq07+ykka2LqqS8hgFUlLxzU3f7gDpdAaPwt5a8vAUEQQq
# BCKCnmMprl2eaM+tEO1qCwofTX4bMX84wKWbpruxp3MIWjpEcl1Oe3H7sG3vvQqE
# +OXai+qWU+0ucXikaAj0bzkUqAwVUgFY/4i3SM5xOjRlreDt8L2myBxT+T88Y/G/
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFGrNWdlJNXtPUqNgkdmIo9w5ZecMMB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAD2jFaZbIETRFWPj
# uJJ6Vr0oezUUjG4JOblltnDzJ1LjP0XUQW0DsTBasaSMfMRpn3Bs40IlntLj7LAi
# 6UaVn/7d7X+AFhcj6qUJNmSssPPZCGWuMyBSI+96f8LTwbHV3BxB1iIGYhZQNYeI
# f4Zka+IJZVxaPNc+ak3b9DjI0yuNDNYDfVbqeewbUKQ8OtTDr36MeDv5UZbzcKju
# j6JAUpBBYPo95k/51baf14zA/fn+baAkBKHt6mYgFrOOYK12fVw4gxzjlORgW/eT
# PRfg1UM1HJXlx/GGmpqHHxyzlAnqzwnz7854r4TjrLoMCNmDFBZgbYzjwGFQw8r3
# Uis7U0nolsat8Tn/6H/HJzfDz9u3TNFGWYfTnO3bgsaxnGuKVkpjf1HSiTB0qaqi
# 2KNxOA8HSPLUSEGn5uvcuD0zwyrc2HYGgOkUm7kAfjdy9KKn4Ob0wXW1dLDN9bZM
# w2FnIMS/vBi/D+oOMJAka1Fy39y7aakaVLQ0jWKDLphJAGUZiM+ldGam7ajOlhOL
# HiYebbQ1KC+TbmnTDyfmgndyBu7MAbetJirxuMW9x/a6cUAdpP40gGMvlo3OTEM3
# R0wImciO4zUV6S1fBhOkh6DZMA0FVf7cgIX23nr7qbkhWWXowwp9bFyyTMmHq0Nl
# sYlqJoovd2Bfk05PfM9AtoiQ/cPGMIIG5zCCBM+gAwIBAgITMwACmS1y3QvPn1Bn
# GgAAAAKZLTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDQyNDA0NDAzMloXDTI1MDQyNzA0NDAz
# MlowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAOYZEHKO
# w+PGdj5sTyMFsWsn9G2kQDT33wrLH59StH0WBkX0G00khHaoFrCbMKRTY9QIUbSd
# 2uNh8/Qeq/s2WibiqZua7A25RkUIZowE7IUp5whkHrbrCnexy1bp6lD1jOdJMaF5
# VCX5eBHiQmGGuc6ffY1mFn+YcDjYWzb9LzExgTXjfIfD8jwzkEdAavQInZri309s
# gkvpr4YPS5oMN/HGrcbozTMGh80mIWvYloYW9lMIpqq/xdzhXoD+H3dq5d5xCaAg
# Hq94Q1Hp0LWmPguDgxMv/I7iBiLgeY3Wdv43WZAaeGRGtIDXmm99PNw+aAdehfud
# RjhnAB+QuI20qtO/spJGti6qkvIYBVJS8c1N3+4A6XQGj8LeWvLwFBEEKgQigp5j
# Ka5dnmjPrRDtagsKH01+GzF/OMClm6a7sadzCFo6RHJdTntx+7Bt770KhPjl2ovq
# llPtLnF4pGgI9G85FKgMFVIBWP+It0jOcTo0Za3g7fC9psgcU/k/PGPxvwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRqzVnZSTV7T1KjYJHZiKPcOWXnDDAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQA9oxWmWyBE0RVj47iSela9
# KHs1FIxuCTm5ZbZw8ydS4z9F1EFtA7EwWrGkjHzEaZ9wbONCJZ7S4+ywIulGlZ/+
# 3e1/gBYXI+qlCTZkrLDz2QhlrjMgUiPven/C08Gx1dwcQdYiBmIWUDWHiH+GZGvi
# CWVcWjzXPmpN2/Q4yNMrjQzWA31W6nnsG1CkPDrUw69+jHg7+VGW83Co7o+iQFKQ
# QWD6PeZP+dW2n9eMwP35/m2gJASh7epmIBazjmCtdn1cOIMc45TkYFv3kz0X4NVD
# NRyV5cfxhpqahx8cs5QJ6s8J8+/OeK+E46y6DAjZgxQWYG2M48BhUMPK91IrO1NJ
# 6JbGrfE5/+h/xyc3w8/bt0zRRlmH05zt24LGsZxrilZKY39R0okwdKmqotijcTgP
# B0jy1EhBp+br3Lg9M8Mq3Nh2BoDpFJu5AH43cvSip+Dm9MF1tXSwzfW2TMNhZyDE
# v7wYvw/qDjCQJGtRct/cu2mpGlS0NI1igy6YSQBlGYjPpXRmpu2ozpYTix4mHm20
# NSgvk25p0w8n5oJ3cgbuzAG3rSYq8bjFvcf2unFAHaT+NIBjL5aNzkxDN0dMCJnI
# juM1FektXwYTpIeg2TANBVX+3ICF9t56+6m5IVll6MMKfWxcskzJh6tDZbGJaiaK
# L3dgX5NOT3zPQLaIkP3DxjCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
# AAUwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTNaFw0yNjA0MTMx
# NzMxNTNaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDSGpl8PzKQpMDoINta
# +yGYGkOgF/su/XfZFW5KpXBA7doAsuS5GedMihGYwajR8gxCu3BHpQcHTrF2o6QB
# +oHp7G5tdMe7jj524dQJ0TieCMQsFDKW4y5I6cdoR294hu3fU6EwRf/idCSmHj4C
# HR5HgfaxNGtUqYquU6hCWGJrvdCDZ0eiK1xfW5PW9bcqem30y3voftkdss2ykxku
# RYFpsoyXoF1pZldik8Z1L6pjzSANo0K8WrR3XRQy7vEd6wipelMNPdDcB47FLKVJ
# Nz/vg/eiD2Pc656YQVq4XMvnm3Uy+lp0SFCYPy4UzEW/+Jk6PC9x1jXOFqdUsvKm
# XPXf83NKhTdCOE92oAaFEjCH9gPOjeMJ1UmBZBGtbzc/epYUWTE2IwTaI7gi5iCP
# tHCx4bC/sj1zE7JoeKEox1P016hKOlI3NWcooZxgy050y0oWqhXsKKbabzgaYhhl
# MGitH8+j2LCVqxNgoWkZmp1YrJick7YVXygyZaQgrWJqAsuAS3plpHSuT/WNRiyz
# JOJGpavzhCzdcv9XkpQES1QRB9D/hG2cjT24UVQgYllX2YP/E5SSxah0asJBJ6bo
# fLbrXEwkAepOoy4MqDCLzGT+Z+WvvKFc8vvdI5Qua7UCq7gjsal7pDA1bZO1AHEz
# e+1JOZ09bqsrnLSAQPnVGOzIrQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRln1HOhWh/L4pFiKrdpzG7Hg0A
# XjBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAEVJ
# YNR3TxfiDkfO9V+sHVKJXymTpc8dP2M+QKa9T+68HOZlECNiTaAphHelehK1Elon
# +WGMLkOr/ZHs/VhFkcINjIrTO9JEx0TphC2AaOax2HMPScJLqFVVyB+Y1Cxw8nVY
# fFu8bkRCBhDRkQPUU3Qw49DNZ7XNsflVrR1LG2eh0FVGOfINgSbuw0Ry8kdMbd5f
# MDJ3TQTkoMKwSXjPk7Sa9erBofY9LTbTQTo/haovCCz82ZS7n4BrwvD/YSfZWQhb
# s+SKvhSfWMbr62P96G6qAXJQ88KHqRue+TjxuKyL/M+MBWSPuoSuvt9JggILMniz
# hhQ1VUeB2gWfbFtbtl8FPdAD3N+Gr27gTFdutUPmvFdJMURSDaDNCr0kfGx0fIx9
# wIosVA5c4NLNxh4ukJ36voZygMFOjI90pxyMLqYCrr7+GIwOem8pQgenJgTNZR5q
# 23Ipe0x/5Csl5D6fLmMEv7Gp0448TPd2Duqfz+imtStRsYsG/19abXx9Zd0C/U8K
# 0sv9pwwu0ejJ5JUwpBioMdvdCbS5D41DRgTiRTFJBr5b9wLNgAjfa43Sdv0zgyvW
# mPhslmJ02QzgnJip7OiEgvFiSAdtuglAhKtBaublFh3KEoGmm0n0kmfRnrcuN2fO
# U5TGOWwBtCKvZabP84kTvTcFseZBlHDM/HW+7tLnMIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACmS1y3QvPn1BnGgAAAAKZLTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCR9fvOfXkC2xZV4rTJxdjLZRQX
# 5SrVXIpltun+7f9WFjANBgkqhkiG9w0BAQEFAASCAYAGxKgT0X8AXLuhKmnYjPZ/
# hy0pWQZeeK4iVoRO1YJMB1jaNpvFj7ivQw5odPgAHWQf0xihkr2eJtZC0AunuBTH
# ViiEGLf6W1XDZzd4wSziZQhHFg8ZnV1QIwXKB5i45a/T5WWhu2CH1ANHYwq5XDxP
# NMu8kQM9Yo5KnrVxtZ7MvAndWG5CWQZwVpRhJVGWC4GZVMAoyUy9iicxnGc6v+kY
# OophRrf8J7hqocfOHFaUnOmfYwYGzfaqqpyD4jNkD+4Gf8QKZY5uBfEp0lscxIAE
# 3mDsU+A15lFtW0luB76YpyI3vyaEBJgfK3ZryJE1yhq5RcldNQfPjjOqEZxqGSNq
# V1Y2DeI6GSaRDmMMeuJ+KOEBvXj7PE0I4ID1DiuRNpSrswIxr3VYYCsnuaOwttO2
# llhI9X9jVGM62Oy70Mb6p7jdyaRb3TBtdkdMSHOxb4AC3oAvHkawxGAfln0Mc+5X
# 4hqKD6bWY47niFtdp0lDnjdgoiIh1YKq09oKRpu2Yl+hghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgxQNhnyxaqRPXxJe9HjugXi42LUBb5mj7lOdSn/Qg
# gpACBmfnx0JXNBgTMjAyNTA0MjQwNzQ2MjMuMjQzWjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAS6GxreFZ/Oc0AAAAAABLMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1N1oXDTI1MTExOTE4NDg1N1owgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCdnYqzfzSDLZ8t
# /IcnBhZ/VS77fz7MIUKa1I9mDjnJRNPdVWovmgU5UbARCbLCIIzZj8J0/YDeyJBD
# YFTySXAgaHlDw06rUBcryq2eaxoWfShTHSdlOnyzhDUw8GXGYJT1x/q+nGm6k1or
# uwW2wrYNR86/Q5sr1XYCJlM8yteWaJFvZJGE6vCOPQxni/lEN2qoTrq2ejmpVVMP
# ngkX9IMCyrlxav40gC15WTU7dZ3o19bQs7u+drzbzON0MtKsqa1vDFsHuqvH2q1S
# 21zETmed/llmTK5QaRLLhk5WCd9w1n/Do5gHarg6Jv861uSCqAdMdNnI34fnTsIR
# naEtCGWGu7W1Zd7blHSligBaGALIC61vJzWj1Mb8JxhhmhfPX20d6nB1Jpmm4qIP
# /FW02uCxJSq9Fe8ziedvlg4m1aCqjWX0Q566/i7VieVsOA3rx1xRXeIbADmsxnw3
# 6YlZohsqREsZUMjQZ4e6cCfKAlaO02ca7GizIRn7mNvzHNYc47gQCFEC+YgX2SLv
# w4b6R5Taq43XJ0hfhDwPSPiT60dySjLUIcmDcs2vI878t3WxEl2an9HJCaYPKvV/
# UZ1Ay9HjkSJc3ZqIXvgGlh1VI7kCpPTBayY7RC0IzJl5a7+DM7FcBhei9h1eJ8Ad
# ZszVcUGk+LkF+uqU3GAnjYadJC/x2QIDAQABo4IByzCCAccwHQYDVR0OBBYEFCCZ
# GsUvRVF/zToRWkE3JYWmuHQmMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMb3YbNgyOUIdvrmh8yK25QWz
# U4kVUvlJmCygDGdnUKokh4ZAMzZu+c7cTlw+hcCH8vbx7zMRbKbLzp1XOXP+/Bvn
# UKynTgEGBkXPEbKwEezCtNwGZm7fAHHh7fAC8GN0R4dEneZBuyvUwjv/RMa3bRCN
# 0IuMTsIpjzwOVivH6lDU8o6dxkE6w+1EhKgImb3iCnGXS1gnotzJ6oa0x3lYMuir
# YOpLFlc54xJR1RncJBKqVqC+2vu31GRaVmBiwVU/bFuYN0o6LVnAPTcu1fMDcn6t
# s5EbW5chgEMFIoUM3tSDMNXoMIQkMQvN3beZpjnLDb4V8OANLd5oXz+bd+p5zW21
# v6odGTBUX/qhjSxBhTbwTPqlV1/Dx95x/6/52PrETq6bQb6t6TAFq4fpXTmRo8uB
# Vj1pkGVljJPDxvi6DyaBZECqlHQws8wM4qDWTk9hTIZrKlK/mvD6J3hR782HLG6W
# JiEuuVSxv+8zsI86ibPK6ywwjlBloH6/+YEtQtS4gIx4D/1xnP7qVfK7FcPtRO4A
# HEw2g+Nm37R+6B+RDime4WvUvxR8FweNjEry0QGtQVvZcEIflDXryIp2UdQIIgW+
# zmUO2b05TulkFPIsiVsgcAYPZjeBuyJkdlhZpYdP0JpYPQiUZTY3hjkum3n/7FnE
# aVhOV+ZdS+0XXVa3A7kxggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAA
# AABLMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjQwNzQ2
# MjNaMC8GCSqGSIb3DQEJBDEiBCCL5TLc63COj5O4PfNbRbVc0ns6PervTyeLeiEK
# dlXd3jCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEINuJKJ0rsvRcScm4woZm
# CKowMSTh9DWm0OSNAeUABkSnMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAAAABL
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# APV6ws6b5FNHUOmEILADVgzql5kzoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67PjiDAiGA8yMDI1MDQyMzIyMDkxMloYDzIwMjUwNDI0MjIwOTEyWjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDrs+OIAgEAMAcCAQACAhMDMAcCAQACAhJHMAoCBQDr
# tTUIAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAJ0zYp4+0DpREjsN9nLz
# Mtl8uVlL2lnjpeW/MQiP/+Q/gaFaIpJvEs/HtxXTh6yJBNiya4cKgjjrmkZ/MBVB
# c8p4NI43Or++E70H83KKqbNrzzdCwKmJeQcTf66irjdE+55H5wtHYVstAw7j/tST
# RCRGW85OHUQoBETXwe3oeZ0SYrKZ9Xv0GJnqmrvnSwbSpq/EfpOtCQYzN51Cufm/
# IESlFoMqK5PO72UPW/k2mehvEsEqLWTorHshqYSTXJ2i+oef2L2YcNfBkFasIYUZ
# C7VdX2p4Gp2wDG2CcPIlQIsFM2VpiNL1ukZH2a0zB4nm+GsnjW6XZgKkTC1RZGk/
# xPswDQYJKoZIhvcNAQEBBQAEggIAAsoxXdLVJ/U87iOxkcRzAyF1zrGehbN6wM55
# gCRLQYAlZt1gAYpWISjIN/AtSS8kCLohUlY2bVW7g15dJD/SkfF4yCXfZ4wgMuaK
# Ah4umTX8lOSscj7zfQN/u4njM51+Hb3TeJcnwaSrJm/i0eILfSLzWLVvehjtUN3T
# RMlCgJcxCrdHas+Af9QPQLnUPuAwRlgoSUUPRUKBfYuT1as7o7l3UPlvV01370GA
# 62TkUxEflYpD8hjCpOnFUYrNP8jcvcGEwNPh1Zd7H6ebRr/zxxUw7y2YNhIaEer1
# f5lcQU0ou2xJrKCoXbN4BYg4L6c8dHSwZ93lrw8car10U3gpCD1Y58Fs7MQrQ5cE
# 36Qu0pLPow9S7rgu19lWhkNwuMRl0oM6iYuh4DvGysBK9Jue20Egw0HJdzp/8MPG
# G+LiE98LqQNpj7r9wgC4YKb99hyRpn1Kw9jwhjTt2raI3AVfKhT0ZwAToPzZ8j+1
# GGHPyvL4miFiw/qwqmkYwEA6QixxMrIvGPNsw9pMyJJDwQK76YnSsK1dnVbzWTnn
# dAL/CsmrgEZuHujrB+Z5I1DGaLAWeOgRTqFqrXbnJ6aiH/p//mHZiy8WdhLvMRpc
# 0WY3wvaomvsHZ8XthQvzj+UyAVRMiWJgeMYYdli6pfr2d31EZqghPjmqLintpJxB
# 4LaCt8E=
# SIG # End signature block
