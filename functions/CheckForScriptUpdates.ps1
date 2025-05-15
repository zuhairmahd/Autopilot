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
    if ($psVersionTable.PSVersion.Major -eq 5 -and $psVersionTable.PSVersion.Minor -eq 1)
    {
        Write-Verbose "PS Version is 5.1."
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
            Write-Verbose "Failed to convert response to JSON."
            Write-Verbose "This will likely result in an error."
        }
    }
    else 
    {
        Write-Verbose "The running version of Powershell is $($psVersionTable.PSVersion.Major).$($psVersionTable.PSVersion.Minor)."
        $response = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get 
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
# MII6bwYJKoZIhvcNAQcCoII6YDCCOlwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD/SlW0g0/2Kod4
# 2oLDDcsBFOW4aLCjmZ9UQ2pdrDoKvKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN7hFrp
# 1U6LB3wLAAAAA3uEMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI2MDQyODMwWhcNMjUwNDI5
# MDQyODMwWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h5g5eiaYpPz1B08V9hqjElk20N+8/puFpgJ1zJ64xzYtACnPYFYdSdVAojyK4Az8
# YcbYxE+1ik8TVFsB9ARcIOszkpm24IGKMGrQued67wrw6bszHlgwV0/9orSviw8/
# TzVue0Qbd/jflcK03TXjTN5PSELqRCXl+4j3b+Mt78Gc8u2UR/p+WrmYEkgeTRsn
# 6mIOr9n/vnDyiK8ECU4E5jjUoQ7oe7COcPQVsRJ1/sYH8nghkPCSQVG0n0y3Fi0Q
# 4MSe+LayByyO1u/A9EMsk0yTUFBvsFJDF//sAcO4kyCaKcfNPnIHvVa992z1u9uT
# Rw11WWrFqNor8Weume2PZY8BGhSaJL0j0iWWhTGwxQR6OwnRjhNI8QflLgxAUImO
# OsvfQZSCi1YWk2cFvX+AT9+o+6LBRlNyLnroMr1l5zJBL2ZCkoKbG1wp1sf+m2bO
# dwlKinAvviG+GBqvGkCfXEqF62cj0o06+Uox3ieyKi9vL1F1L4JLZQaGFpSHydeZ
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFLT4rWHrwwfh86z/13qLIjtysJzWMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFJ3H+2emMur6q4x
# 2ou6dltN2XEVNCMfjWsWryWLfyHyA5iBWHiZd7Fu37GXhOhj1oVZrQVxTZkrQRgZ
# f4fbejbBUwCsozJMb9dNB3ZtPahGfbOcWwcKBzXS4V/sDkGwt4Lu2maYwjgIquGh
# 6sdLLPFtXXkIcQ6bCP16283T8sndrX/hLvusFY80o3COvQG6mJBXM4HSdY+ZAOPO
# 3Ddows/3cJUP3ZpTjxrQGIDXq2ZPFm5/eOMjW7fM64NUYq+LPTMYlB2X2zlv6cX+
# DleOK4VXVjGORe3A3jaYqeWq5yh5Csos05JPXosgi01bAaOLwDYCQj+ElhqpQaqR
# 3zcLLF25mYLGgNIV3owuIgEVVpVE/iMo76g4ME5a+hEzcS2G1UVKkK0o8gGxDlrc
# KDgsrE/3koPFSubzVfWORrLzJYfbzB0R1M5fk4GsQhFiWY1sFmzMc4wHcV/+ilUh
# STVT6hvCYV5546l4/nGIrS4MQF01SxmutmhtQAdz0vay4ni5FKaoW3afZIFVE6NU
# RRT/gHvzWDc1AIkdBcfEkUgx4tZrC0Qkj+tsCX6Z04MPuoyBrEuLYrPIg5NbAcLu
# +4doG7Reu5pmuKhN6xl3F1MQ/2qhWxwNcecmkzK8qjOblVnwbGbOD/rdO2xilgrl
# oZDi+vcePFW2TOnG31Do716PWRqYMIIG5zCCBM+gAwIBAgITMwADe4Ra6dVOiwd8
# CwAAAAN7hDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyNjA0MjgzMFoXDTI1MDQyOTA0Mjgz
# MFowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIeYOXom
# mKT89QdPFfYaoxJZNtDfvP6bhaYCdcyeuMc2LQApz2BWHUnVQKI8iuAM/GHG2MRP
# tYpPE1RbAfQEXCDrM5KZtuCBijBq0Lnneu8K8Om7Mx5YMFdP/aK0r4sPP081bntE
# G3f435XCtN0140zeT0hC6kQl5fuI92/jLe/BnPLtlEf6flq5mBJIHk0bJ+piDq/Z
# /75w8oivBAlOBOY41KEO6HuwjnD0FbESdf7GB/J4IZDwkkFRtJ9MtxYtEODEnvi2
# sgcsjtbvwPRDLJNMk1BQb7BSQxf/7AHDuJMgminHzT5yB71Wvfds9bvbk0cNdVlq
# xajaK/Fnrpntj2WPARoUmiS9I9IlloUxsMUEejsJ0Y4TSPEH5S4MQFCJjjrL30GU
# gotWFpNnBb1/gE/fqPuiwUZTci566DK9ZecyQS9mQpKCmxtcKdbH/ptmzncJSopw
# L74hvhgarxpAn1xKhetnI9KNOvlKMd4nsiovby9RdS+CS2UGhhaUh8nXmQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBS0+K1h68MH4fOs/9d6iyI7crCc1jAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBSdx/tnpjLq+quMdqLunZb
# TdlxFTQjH41rFq8li38h8gOYgVh4mXexbt+xl4ToY9aFWa0FcU2ZK0EYGX+H23o2
# wVMArKMyTG/XTQd2bT2oRn2znFsHCgc10uFf7A5BsLeC7tpmmMI4CKrhoerHSyzx
# bV15CHEOmwj9etvN0/LJ3a1/4S77rBWPNKNwjr0BupiQVzOB0nWPmQDjztw3aMLP
# 93CVD92aU48a0BiA16tmTxZuf3jjI1u3zOuDVGKviz0zGJQdl9s5b+nF/g5XjiuF
# V1YxjkXtwN42mKnlqucoeQrKLNOST16LIItNWwGji8A2AkI/hJYaqUGqkd83Cyxd
# uZmCxoDSFd6MLiIBFVaVRP4jKO+oODBOWvoRM3EthtVFSpCtKPIBsQ5a3Cg4LKxP
# 95KDxUrm81X1jkay8yWH28wdEdTOX5OBrEIRYlmNbBZszHOMB3Ff/opVIUk1U+ob
# wmFeeeOpeP5xiK0uDEBdNUsZrrZobUAHc9L2suJ4uRSmqFt2n2SBVROjVEUU/4B7
# 81g3NQCJHQXHxJFIMeLWawtEJI/rbAl+mdODD7qMgaxLi2KzyIOTWwHC7vuHaBu0
# XruaZrioTesZdxdTEP9qoVscDXHnJpMyvKozm5VZ8Gxmzg/63TtsYpYK5aGQ4vr3
# HjxVtkzpxt9Q6O9ej1kamDCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFx8wghcbAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADe4Ra6dVOiwd8CwAAAAN7hDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCtnS5zSsx1cSw5mgRjWQtkCfpj
# 7NJpEqKW5B0qyI7CHzANBgkqhkiG9w0BAQEFAASCAYBMcumtkgVN7p4rAyI9IK8d
# QI+KK7SxNZ/3LhML2wn3slZpzBG2Bb/4pB4WPUQRkKKA21ltEZFmqUP+ovQCZg4p
# Bke/+JjcA1yt5wQVc9w+WXvbUN6M1t9fdbzt9reXiVxvDnNkGuGjKu/a6fYbVg0J
# vmI4iabuRWZ32Fru/M3IkrQf36EV4xte7rF2SebbN+GMgCwg5UpuoObEkKfElgeQ
# J3vnSavBShZC1z07KTpggwj7o2gWG3fo792QwSH4C5aRwLCmc5cdqzBgPs7vIoDA
# WRxTeWCUWbIpFXQcs6TW3oIo+dDTQV9V/TytU7NLuxnWCfAfEwXpHlZyqCY2wSYd
# ZFaLnwltJZgp4i61IzPioscp2Ddt8c8RVyDPXMZkWPhhQGH67AFzxTZGSi1756wi
# 1jsjbl9e6X3rnCbDTIpbPGL38ArEntMIkGIVqVdejmAqObimnGvoywuaDPhxYv33
# YnBgW+v+kZ0t/quF0UXo9KF88QZSmoxUulbH0dMyLEWhghSfMIIUmwYKKwYBBAGC
# NwMDATGCFIswghSHBgkqhkiG9w0BBwKgghR4MIIUdAIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYAYLKoZIhvcNAQkQAQSgggFPBIIBSzCCAUcCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgYAVFhXkZQV0TmRFbMxVAB2gt9pEwnEvYsum8rbc/
# EVECBmgHpBXhxBgSMjAyNTA0MjcwMDExNDAuMzVaMASAAgH0oIHgpIHdMIHaMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVT
# TjpFNDYyLTk2RjAtNDQyRTE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0Eg
# VGltZSBTdGFtcGluZyBBdXRob3JpdHmggg8gMIIHgjCCBWqgAwIBAgITMwAAAAXl
# zw//Zi7JhwAAAAAABTANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQg
# SWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMjAwHhcNMjAxMTE5MjAzMjMxWhcNMzUxMTE5MjA0MjMxWjBhMQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylN
# aWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ5851Jj/eDFnwV9Y7UGIqMcHtfnlzPR
# EwW9ZUZHd5HBXXBvf7KrQ5cMSqFSHGqg2/qJhYqOQxwuEQXG8kB41wsDJP5d0zmL
# YKAY8Zxv3lYkuLDsfMuIEqvGYOPURAH+Ybl4SJEESnt0MbPEoKdNihwM5xGv0rGo
# fJ1qOYSTNcc55EbBT7uq3wx3mXhtVmtcCEr5ZKTkKKE1CxZvNPWdGWJUPC6e4uRf
# WHIhZcgCsJ+sozf5EeH5KrlFnxpjKKTavwfFP6XaGZGWUG8TZaiTogRoAlqcevbi
# qioUz1Yt4FRK53P6ovnUfANjIgM9JDdJ4e0qiDRm5sOTiEQtBLGd9Vhd1MadxoGc
# HrRCsS5rO9yhv2fjJHrmlQ0EIXmp4DhDBieKUGR+eZ4CNE3ctW4uvSDQVeSp9h1S
# aPV8UWEfyTxgGjOsRpeexIveR1MPTVf7gt8hY64XNPO6iyUGsEgt8c2PxF87E+CO
# 7A28TpjNq5eLiiunhKbq0XbjkNoU5JhtYUrlmAbpxRjb9tSreDdtACpm3rkpxp7A
# QndnI0Shu/fk1/rE3oWsDqMX3jjv40e8KN5YsJBnczyWB4JyeeFMW3JBfdeAKhzo
# hFe8U5w9WuvcP1E8cIxLoKSDzCCBOu0hWdjzKNu8Y5SwB1lt5dQhABYyzR3dxEO/
# T1K/BVF3rV69AgMBAAGjggIbMIICFzAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFGtpKDo1L0hjQM972K9J6T7ZPdshMFQGA1UdIARN
# MEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYDVR0fBH0wezB5oHeg
# dYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0
# JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUl
# MjBBdXRob3JpdHklMjAyMDIwLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwgYEGCCsG
# AQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRp
# ZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwDQYJKoZIhvcNAQEMBQADggIB
# AF+Idsd+bbVaFXXnTHho+k7h2ESZJRWluLE0Oa/pO+4ge/XEizXvhs0Y7+KVYyb4
# nHlugBesnFqBGEdC2IWmtKMyS1OWIviwpnK3aL5JedwzbeBF7POyg6IGG/XhhJ3U
# qWeWTO+Czb1c2NP5zyEh89F72u9UIw+IfvM9lzDmc2O2END7MPnrcjWdQnrLn1Nt
# day7JSyrDvBdmgbNnCKNZPmhzoa8PccOiQljjTW6GePe5sGFuRHzdFt8y+bN2neF
# 7Zu8hTO1I64XNGqst8S+w+RUdie8fXC1jKu3m9KGIqF4aldrYBamyh3g4nJPj/LR
# 2CBaLyD+2BuGZCVmoNR/dSpRCxlot0i79dKOChmoONqbMI8m04uLaEHAv4qwKHQ1
# vBzbV/nG89LDKbRSSvijmwJwxRxLLpMQ/u4xXxFfR4f/gksSkbJp7oqLwliDm/h+
# w0aJ/U5ccnYhYb7vPKNMN+SZDWycU5ODIRfyoGl59BsXR/HpRGtiJquOYGmvA/pk
# 5vC1lcnbeMrcWD/26ozePQ/TWfNXKBOmkFpvPE8CH+EeGGWzqTCjdAsno2jzTeNS
# xlx3glDGJgcdz5D/AAxw9Sdgq/+rY7jjgs7X6fqPTXPmaCAJKVHAP19oEjJIBwD1
# LyHbaEgBxFCogYSOiUIr0Xqcr1nJfiWG2GwYe6ZoAF1bMIIHljCCBX6gAwIBAgIT
# MwAAAEr9uFXHYqrJiQAAAAAASjANBgkqhkiG9w0BAQwFADBhMQswCQYDVQQGEwJV
# UzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDAeFw0yNDExMjYx
# ODQ4NTVaFw0yNTExMTkxODQ4NTVaMIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRp
# b25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpFNDYyLTk2RjAtNDQyRTE1MDMG
# A1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3Jp
# dHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDoORBhnrNiXDUBvEWQ
# U3BzRXQFpcIKjX/53TVgqLNqUr1tfx8ashRJV/vmlgk6uFiah8gyHvAG/yP6QimU
# 4piLGu1Wr5pDAB7MjTAEV0UV47I0IjKdNDDPfjfPkhZVnT/tw5dPUgOT18iwjnWR
# kodrhI9/2sWYf1e0fX8/UTG54AayQEX8C8jU6XZW/Zb0QOR7xyzFw+BdOQM0b0jm
# WMSMz2llTN/2SDDw+jwJWkPX84VvjryNxpamyL/J2puhrcomc+jJSWer5yaCnp+S
# mpiY8zcSECvVoCpsyeSJSsPhDXkNO/Rehk6LXONdGEXnHFcouvWbmTnFmUenuac+
# KaIbrtPv97kO4UW3tdsCw4Jbw3VmrmN014uswu0G+RHIqWRNKynqclBdHhF/Z7zt
# Ou95CImMuxb5lDjopd1wMjVahrEjQnPKmJw5AFtxT3zzben9MCth1Wkhi5iVerT3
# bdx/36KbrYFUUb15eGb7rTVGxd1aUftBQxnNsPbfdoA/wuIHSkOuQr/JtSlizoOi
# QAn2vRqbg0Ve7ssL4N8gW95Ehk4IFoca3hIncbZWCQUigAsVxOGP6ujuhf4FPeyv
# QvnsvOL9CZTZSRMLBXWoozr5qpvOFXgHGzFGN9B162rMW/Ejggd/QgG4+hhgyIng
# BdNraajKZ+56MrY1mAvvmZbCKwIDAQABo4IByzCCAccwHQYDVR0OBBYEFBd01om2
# LhZ7joStT9M2cg55YZV6MB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7ZPdsh
# MGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUy
# MENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFB1
# YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# ZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgG
# BmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMCnNMNdZvKP+vzm/oDPX2wk+3Ap0
# Tm6QDQWs/El98gNDRYktbUbvNchcgljdLl0Idu9evlsOuYvrsyWdTQzREhqmbnGl
# Lx6O5Z1GmUeqRGLCEHmGb7ucR3Gb5h0oJygg/FsaojW3wTRLRm3u7DX/0vNFRqt2
# 5MdDQ8rJlCe5iQcsbHzf/5FHjTDWB6aIgW0L9R+81j1REcJ8Hptan3SqLdONYsw7
# TcXBym69nXlG5sxUf94fdZq8mMsHisNZ3s3N5ICSJOoIRQAU2qsYVueM6+IExRsq
# QBr+YWP2bUOTpnHhJte1PnAKh1feTfSbRxIHacKVQttHhjJY7n8yhKVPCcw+8Vcw
# 5ZSTN39IBFvDtdUXpYu2BkdUEoDJngwUrCsoI/yFd2jN2R45fdG7Xb7B7BGTwCej
# 9/3Oubgb8H/A7q7uyYHd5Hw56uqKg+3ve58UxaxILBeFIbPzGmOroMqIbf2wNE8X
# YIeewEgma/t08yBgIrGyRvsaIiQduprv28gCpCz2djizteFHw0pEApUhiP3/xeR5
# jlLUbRhCELBCVFS28dkxjSliY5cF9amNAb5lojB93Tu0HSGmskGHnMksi6yx+wg/
# e0avijri2pFrz44i0/eYtYJ2yUpwFjkcjMcLZvQ2dqwBjVurN9N+i2x+WGtX6ldL
# I3cCzfp0oxOqkYYxggPUMIID0AIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASv24VcdiqsmJAAAAAABK
# MA0GCWCGSAFlAwQCAQUAoIIBLTAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQw
# LwYJKoZIhvcNAQkEMSIEIBr1OVWA80Wke8hisc0ZYJkaverVrvtEo40MvOdiDBZO
# MIHdBgsqhkiG9w0BCRACLzGBzTCByjCBxzCBoAQgZnsptaXNjQBCR0t1b+ADGLKX
# s8R/1amy/7F17y7D4QowfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABK/bhVx2KqyYkAAAAAAEowIgQg
# PdlxntTh80+WP5EuRDNu6NmYxxqAfT1pg6m/wTHBJFYwDQYJKoZIhvcNAQELBQAE
# ggIAWNs+f7BSr7tjSVXQUMXB58XR3YjC9jTc7mR+X+q9qeTQ2Tcg1vaSTh3G8Tod
# N/WH8gYy8+oiubijnRP2khuGNeTB5p9cOm/rxNC7v9pusjxBXGC5ueFB/VZnqv/4
# rTrFlPqegFCByc9jkONrBiYAqzlkg3IdIBKqdhkswvHt0oi/guhZQaH7HZbNld/1
# hl3/stUQ/U9QRhEztoZrUiWVEIriBHkm2pYJiGKbnOKik6lQKcIhVHYWCoCCWVjj
# JfnqRSxsgtFROYPfm3Np1XRn7gZ7MvFGX1oprwhJrCpEbhWR3Dd3XHva7h22rXsS
# Z6pBDI1jyEavq6iOwZLKofb/O0MsIzpi7UDZ2+IS5EZ4+KBQ36wD4473ODr1or1x
# cX0xDTPxlXg18mQM0GTXzz48y7ZDU5HJ0bvk6PMEtuNrznuzX0mfRfAkdOu0KHK1
# zWrcI+5ukGqX0QIRNcnRRvUnhQC+apeGDW1eFwOSlnr6oMKw9ikMq7F30tM+Kcgi
# 0IddLmfFTHY5XAWS60tII4qGgNaWE8O7bTBibTheTr7h8GW9cXFTwFNbzj3hZtus
# 5hDjtEVizlWM0JXTvUjPR2wP6/wS9cFSlwYwgGhF3n8CexsdcMKrgLn8AlYhMssc
# ok3PfdkiD9zTZSAuWmivXma5eX0EArdmgP8rkw1n5oXcuE0=
# SIG # End signature block

