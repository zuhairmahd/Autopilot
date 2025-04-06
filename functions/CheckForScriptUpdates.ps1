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
function CheckForScriptUpdates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$RemoteManifestPath,
        [Parameter(Mandatory = $True)]
        [System.Object[]]$LocalManifestContent
    )

    $updatedManifestContent = @{'Functions' = @(); 'Scripts' = @(); 'Cmds' = @() }
    Write-Verbose "Retrieving remote manifest from $RemoteManifestPath"
    $remoteManifestContent = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get
    Write-Verbose "Read $($LocalManifestContent.functions.count) functions, $($LocalManifestContent.scripts.count) scripts, and $($LocalManifestContent.cmds.count) cmds from the local manifest."
    Write-Verbose "Read $($remoteManifestContent.functions.count) functions, $($remoteManifestContent.scripts.count) scripts, and $($remoteManifestContent.cmds.count) cmds from the remote manifest."

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
            Write-Verbose "Remote item name: $($remoteItem.name)$fileExtension"
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
                Write-Verbose "Script $($remoteItem.name) not found in local manifest. Adding to updated manifest."
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
    if ($updatedManifestContent.functions.count -eq 0 -and $updatedManifestContent.scripts.count -eq 0 -and $updatedManifestContent.cmds.count -eq 0)
    {
        Write-Verbose "No updates found. Returning empty array."
        $updatedManifestContent = @()
    }
    else
    {
        Write-Verbose "Updated manifest content: $($updatedManifestContent.functions.count) functions, $($updatedManifestContent.scripts.count) scripts, and $($updatedManifestContent.cmds.count) cmds."
        #write the remote manifest to a file caled remotemanifest.json.
        $remoteManifestContent | ConvertTo-Json -Depth 10 | Set-Content -Path remoteManifest.json
    }
    return $updatedManifestContent
}


# SIG # Begin signature block
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbx1LWHKVmUZK1
# 9ZLDxzrn3b8ZdYw0562Zg5rHt22ar6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# A2NremqS9vgmvambJYB4wW2ynPzm
