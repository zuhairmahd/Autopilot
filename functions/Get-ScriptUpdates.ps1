Function Get-ScriptUpdates()
{
    [cmdletbinding()]
    param
    (
        [PSCustomObject]$scriptsToUpdate,
        [string]$scriptURI,
        [string]$ScriptRoot,
        [string]$scriptVersionURL,
        [string]$scriptHashURL
    )
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURL: $scriptURI"
    Write-Verbose "Received ScriptVersionURL: $scriptVersionURL"
    Write-Verbose "Received ScriptHashURL: $scriptHashURL"
    $functionsList = @(
        'ConnectToTenant',
        'Get-decryptedObject',
        'Get-DeviceHash',
        'Get-DeviceInfo',
        'Get-requiredModules',
        'Get-ScriptIntegrity',
        'Get-SignatureStatus',
        'Test-ScriptUpdates',
        'Get-ScriptUpdates',
        'Get-USBDriveLetter',
        'Restart-Device'
    )
    $success = $false
    Write-Verbose "The script URI is $scriptURI"
    Write-Verbose "The scripts to update are $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host 'Updating scripts ...'
    $index = 0
    foreach ($key in $scriptsToUpdate.Keys)
    {
        $index++
        Write-Verbose "Processing script $index of $($scriptsToUpdate.Count)"
        if ($key -in $functionsList)
        {
            Write-Verbose "The script $key is a function"
            $scriptPath = $ScriptRoot + '\functions\' + $key + '.ps1'
            $updateURL = $scriptURI + '/functions/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        else 
        {
            Write-Verbose "The script $key is a script"
            $scriptPath = $ScriptRoot + '\' + $key + '.ps1'
            $updateURL = $scriptURI + '/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        Write-Host "Updating $key to version $($scriptsToUpdate[$key])." 
        Write-Host "Fetching from $updateURL and copying to $scriptPath"
        try
        {
            $response = Invoke-WebRequest -Uri $updateURL -OutFile $scriptPath -Method Get -PassThru
            $StatusCode = $Response.StatusCode
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                $success = $true
                Write-Host "Successfully updated $key to version $($scriptsToUpdate[$key])."
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
        Write-Verbose "The status code is $StatusCode"
    }
    if ($success)
    {
        Write-Host "Refreshing updated script version from $scriptVersionURL"
        try
        {
            $response = Invoke-WebRequest -Uri $scriptVersionURL -OutFile $ScriptRoot\version.json -Method Get -PassThru
            $StatusCode = $Response.StatusCode  
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                Write-Host "The script version file in $ScriptRoot\version.json has been refreshed successfully."
            }
            else
            {
                Write-Host 'Could not refresh the script version file.'
                Write-Host "The server returned Status code: $StatusCode"
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }   
        Write-Host "Refreshing updated hashes from $scriptHashURL"
        try
        {
            $response = Invoke-WebRequest -Uri $scriptHashURL -OutFile $ScriptRoot\hashes.json -Method Get -PassThru
            $StatusCode = $Response.StatusCode
            Write-Verbose "The status code is $StatusCode"
            if ($StatusCode -eq 200)
            {
                Write-Host "The script hashes file in $ScriptRoot\hashes.json has been refreshed successfully."
            }
            else
            {
                Write-Host 'Could not refresh the script hashes file.'
                Write-Host "The server returned Status code: $StatusCode"
            }
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
    return $success
}
# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB97ngjgRrxcD6R
# hN5wwa0SMtx3/EZwr9Sotx2fzVeGWKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAG3TBId
# dYfjBp1eAAAAAbdMMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwMjE3MDkyNzE3WhcNMjUwMjIw
# MDkyNzE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# ieTkALH6JH9smRuHSJNMSBs83oHdTz2q9i2jh3lA5HKEfGnU045qIswN5wrhuFaY
# PgAhIYFle4C1kGih1TSTY2vmSdsuA9zjjjfaNUCw7e6mo/DG/q7pp/S7NXqCdtvl
# u/voszMbi+4NanDPAGZXsZNqvAAPGXHsaHPYamKDH/mTvz7Ati9K3Zp4DufbOhb7
# 6JQWua7nEAtfVIM1cKrg7KvHStBEe+4vRDxDqKPaGApIa1dG4BoKtV9UAbtGKS0h
# H0Taaa+4u01jpzv+VXT1aHcY0ZTf+sijPyIRYtkV49qPH+1f3jh43+SWMqoGN7lz
# Vvgu1EB1fXcVfFchWYB21ORvLRQWWRpbRoa14EWhxCgM1IWfj+k3ko3MNcEWaj7a
# XYhomi8fGXkA+3g8YC1+1ty4rVKZfeL6d+6hebsx2rbzw8skMU0E5HPzMhrsQs7M
# 3JB9HbROLu83TU1X9gplI5SNmjCMVNptDr2FHAkRSzJU6zyt7IYxdzyD/1KKUghR
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCnwBg0W15N7CNiCaytuOv9Tuvq5MB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAEoJkddxwuXD3Vrt
# pnxf45cKYjTJKWgWcL34ziN0DltHMJhkymeSOTr3ePxuSoo4OwNjlb7Fprve9P3q
# flroqzleivlwOQAxCpG9aVmJjwjcBrVQ5Hlj2I3MvAqwsC+Ws0bEJ4KIKimb8Vws
# q2CUl3M/l59iM8ybDKsEln/wgwCa+Z2xQ53hF16WXal8KNtV/AIwhiKSK38vKfeb
# a1l7xMn6PkWDWTqGLU/r9KI1CqfGgLCnZ/wI0aW7S5lLaPwQ9or85w1NGdjgQ8Zi
# npIN/ef6BWGJQtZX1kDR1qhnRtqRXdhjkBRT934bxNs7J+muPUaAOwBNz+GO2A13
# fwT1UfcPeTGYAijT+F24H1uqDmTcqzXCUXbWID00vcQyYsC3VPnGvSpMnatxVcR8
# Ir/1cs/a36+lwag4EPS8H6WvGUevYzyy6UqBPjFL5EOErvXl30mamenn0WRiPFD1
# gexYHQFnCUcP4rXbk72ErrCdSXYMRyku2eiCSHTFBgisISIeHRkzpaVwqIaCciLs
# 7Utd5Dec32cdAB5Ge2qAHXT6Ja3ckyyPr2BZgt4ZPwXsu/rl0jDwtmzT8tsbBTV5
# o2xF35XfUxvsP4/S2uaK6VP4DGqSDERJdaVXzJ2hBVwy8F9r7/LKmxYiDpbdUL6J
# lZ/MPpWFA6I17SPnTaMwIfl0z1iRMIIG5zCCBM+gAwIBAgITMwABt0wSHXWH4wad
# XgAAAAG3TDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDIxNzA5MjcxN1oXDTI1MDIyMDA5Mjcx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAInk5ACx
# +iR/bJkbh0iTTEgbPN6B3U89qvYto4d5QORyhHxp1NOOaiLMDecK4bhWmD4AISGB
# ZXuAtZBoodU0k2Nr5knbLgPc44432jVAsO3upqPwxv6u6af0uzV6gnbb5bv76LMz
# G4vuDWpwzwBmV7GTarwADxlx7Ghz2Gpigx/5k78+wLYvSt2aeA7n2zoW++iUFrmu
# 5xALX1SDNXCq4Oyrx0rQRHvuL0Q8Q6ij2hgKSGtXRuAaCrVfVAG7RiktIR9E2mmv
# uLtNY6c7/lV09Wh3GNGU3/rIoz8iEWLZFePajx/tX944eN/kljKqBje5c1b4LtRA
# dX13FXxXIVmAdtTkby0UFlkaW0aGteBFocQoDNSFn4/pN5KNzDXBFmo+2l2IaJov
# Hxl5APt4PGAtftbcuK1SmX3i+nfuoXm7Mdq288PLJDFNBORz8zIa7ELOzNyQfR20
# Ti7vN01NV/YKZSOUjZowjFTabQ69hRwJEUsyVOs8reyGMXc8g/9SilIIUQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQp8AYNFteTewjYgmsrbjr/U7r6uTAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBKCZHXccLlw91a7aZ8X+OX
# CmI0ySloFnC9+M4jdA5bRzCYZMpnkjk693j8bkqKODsDY5W+xaa73vT96n5a6Ks5
# Xor5cDkAMQqRvWlZiY8I3Aa1UOR5Y9iNzLwKsLAvlrNGxCeCiCopm/FcLKtglJdz
# P5efYjPMmwyrBJZ/8IMAmvmdsUOd4Rdell2pfCjbVfwCMIYikit/Lyn3m2tZe8TJ
# +j5Fg1k6hi1P6/SiNQqnxoCwp2f8CNGlu0uZS2j8EPaK/OcNTRnY4EPGYp6SDf3n
# +gVhiULWV9ZA0daoZ0bakV3YY5AUU/d+G8TbOyfprj1GgDsATc/hjtgNd38E9VH3
# D3kxmAIo0/hduB9bqg5k3Ks1wlF21iA9NL3EMmLAt1T5xr0qTJ2rcVXEfCK/9XLP
# 2t+vpcGoOBD0vB+lrxlHr2M8sulKgT4xS+RDhK715d9Jmpnp59FkYjxQ9YHsWB0B
# ZwlHD+K125O9hK6wnUl2DEcpLtnogkh0xQYIrCEiHh0ZM6WlcKiGgnIi7O1LXeQ3
# nN9nHQAeRntqgB10+iWt3JMsj69gWYLeGT8F7Lv65dIw8LZs0/LbGwU1eaNsRd+V
# 31Mb7D+P0trmiulT+AxqkgxESXWlV8ydoQVcMvBfa+/yypsWIg6W3VC+iZWfzD6V
# hQOiNe0j502jMCH5dM9YkTCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwABt0wSHXWH4wadXgAAAAG3TDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDnMN5Qs4GACWzkJn2SowbK0ukO
# XW3lExlOqP/D04uw8TANBgkqhkiG9w0BAQEFAASCAYBUJC5TQvcRpZ12vGgeMnUU
# QlcQlM+atdHxaEDTdeRtccek8Qs/SwLNqIc8USSFBokewUtZ5T8Cm0snzDcQ5Hg0
# USEg93ptQ94Em/fQ+ad8fVtrIC5gMKF84KacmytuLo8VIZ7cnR9ZQF0Amxnk4rsE
# cTO3GpWO20JYrNfSnQKjR5KI1R/CuxHS7DC2uoO9Gk+/pfogoDCVPy3T3I+9ifK0
# BwneHU433s+ihgXL4prN/NP7WgSHeRjjOfMqjQnlgw0QtVKkFVwmOsHbqL/5TL+E
# kwSzd5mRNg9I4D2Fo8TcnXJnRWFxc8foibkPOHa3/3inXOwYVJ4tgbBDgQXdv7E9
# pDW43jbtepR1IUqEhP8Qu3VvrLosfgQIreqricqV7KPlMqX7jCBtITFRVXEjaMyj
# hox2oPdur1Uyz3DPErGxJXEvEdQh5b6GuSWJjFZiK3SxYMH75JnrQYrFH0+gCv5+
# 1InD1cAMTlRZ5LlXuqUHWwvVwuLU29QMdEJLtwpRuK+hghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg1SRLLBiNP2X31NF+wu5l/yNNKFowXpi6KGNL2F9e
# oJQCBmesFpXuOxgTMjAyNTAyMTgwNzIxMDMuMDI2WjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046QkI3My05NkZELTc3RUYxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
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
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABF33vn5wwJFp4AAAAAAEUwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODQ3WhcNMjUxMTE5MTg0ODQ3WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046QkI3My05NkZELTc3RUYxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwI7T9DdCYDUnYfj4
# va+Mk9tdPmx23cLwlHHIA8ZEIuTEgrFV8F5gIAHDzvgdrLpaAfNYt5y+Vtpx5RHb
# FVJnRgnwWE3FrDKGO1r+kFXcXRCxzajb7rv7n+pBSwhwwKmQeiTA8UZNujosLQ1W
# 0ojOEL7xMc4l5mzLugA6CL618wL7gaZWwaOGq6RROC7Yv1r18+y1O2mSoEMzM3lV
# r3PvIj3UTmtbovReZOc7NlPuGPTAwjXtqpS16GU7Df4CrBvC9a5n9M15oqCtWjZE
# ZlsgfMzA28KvSKqqS/UyRBUwbLEC0kP6d/rOzyy0uxCgP259ntzUF6c+N7XmC5X0
# 4PFo7OSnKcsJ004j9W4gki6MtRHBlPW1hB3EUlPzMfx7vPVk+/0erh3DKe5UUiZ5
# 4aC6hclk3qc74OoRcXkRiqheE7fDLMmkGzGziMfii8o1K0fcDUhL1Etff2GL6G0N
# 3qs/2stJrtm4oyoURJawlTN5yJ85zzcF1XSaM7P595jhFz8gB4QBTvs67wQa5nrM
# JRHNWTlvqYbImoYYX7yhzmAULFO3essnrvIriGpi1pv4NvoPSsvgoQ70DjVUrDbi
# f8gwOlIefpcunbGYzCKNZC3rOexU6JGeU0NlZLA9UPaF3pxenjEFqsZWVr3JKf6/
# sbstAIFsyM2ZOMivlI8pfaWS4W8CAwEAAaOCAcswggHHMB0GA1UdDgQWBBQl0Nvq
# 9SXQRMmn8B3Grz2HYyuV8jAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAGy9tedaeCT4seFHGLKgQteRiPy0
# twNtoLqOU80gWazoi0L5DHQGhXiVDMVJb9zu1IU3J5unNxwad9hA6/4jeu/kHgZF
# z3EEszczT480nzwx69zWtVPuCH//b7h1qNZ0p7YKpamUDu1ZjBWuSmgPhK/GgVLX
# LO1TQ6ntrjbz8bMJf35HsUFWvCRrbPpX4hhNepUbL0jU3l1YECHoleDhtrnqV5v+
# rz/lXQxhGyVSjPh+NTg80Xwk8Of/7saYnvMdW28xoelULIYnFqTxPn+1vKJX1Qnl
# HzBBUtWKVDPU/fMERcU2UF052chin0TCQayP8cABd1jYYILQMatiYJzSLAAdNiPM
# x/clpoD0w13egpMD9B3bx0qyruz2MQK31KR4ZwoKGLfCwuuayzB2aEDcp3Q+SVGg
# ngYn8SaTjneUZLohh/Wk9A4LOkZhDBYjFQ1BotbTc9KYUV05JXNaheMSwRiFQuCe
# ZnTtqwhN+UpTO+lZGzBjxPYTXObQYrY6vsB4jzmgzV2+UkE6J2nczJP6LdijGr2P
# KPpQ3bVG8dpqnOaY8ahKtQouoTfJPHG25BrrX2whPch8xZBYSWn0NYj/yZKje/cr
# qJYvUoEALhomQbuBU5+Fv4U/R8xzMUGJgoeHIh8n9OoNN2JEtMOeypI6oTrGVRtK
# YtHyZmb4a5gUM8TXMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEXfe+fnDAkWngAAAAAA
# RTANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCC9tjCoV3lblF22/EYLHFtzMx9E3DNrN6e4+7nNTCsW
# WTCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEILgEVTrIyIo/ceMv5rhPHM70
# iM9F0uvKQRUOfiHf0m5xMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARd975+cMCRaeAAAAAABFMCIE
# IGthxYqJXvr3pbVIoYbQm4A7wdAIYeB3/+/WHR07TbIXMA0GCSqGSIb3DQEBCwUA
# BIICACdTagJVNx2yrJ5gzS6wIYXs/Ddf9IpiY/5201iyVwZOFCdVg353wvhbRFVr
# ci6GSYx4tI1V6MmpUz1mpnThLHORFLjsORT6yBK2t/xt4L8RjQdG7bEhwGRf5mmN
# gGRt9LjNraJVvr9GMMTEEjXULOtRB+sk3cx1OWMScl8A/gNnxsxYDC2OP2LWlc/U
# ALgFhgScXW1IaB+tVeXZjCHug1+SJv7FqflgCQfWAtvpdHu0Quy78lINrb9xlqLp
# bfAqfbR8CCC3yjGMN4Gjn+ua1XIbffVSICQ/WeyD8F8xyAOfjsdDML28Ur3uWpE+
# taUou49uepGv4vbYlBlXjlUeKT8oX7XbBEqHiXtWr2Mu6rDMvUjtuDylgvLAfn6W
# BgWN06+pabW8R1kyQv6pD0arF1H3fKEFx2PZf4m9aWRptfsByu06dQcJvD7zVj4U
# whkYP6QRYhMQapvaEXbMI1FCQKufmH4h3vuAKuK4WypPxqDXR9uKzNPbcrPDZ0u8
# 1WbhzEXxc04xYD2MHSRmEiU/lT3YhwU5tOXJPPstYbBULCk/OCp799ypCLd+NcUw
# vvc24on1wC4mWX+EiXM5QklGtMratd3UVlEbniEVsZFThfvjcaUgjUZl8hEf9150
# WnzLFOc5xepfkHeiTnTHD2wH1ndAtU2n2AQLIfSNOzf6Ga4v
# SIG # End signature block
