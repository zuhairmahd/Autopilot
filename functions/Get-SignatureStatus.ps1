function Get-SignatureStatus()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$scriptFolders
    )
    Write-Verbose "Received $scriptFolders to check"
    Write-Verbose "Checking $($scriptFolders.Count) folders for scripts."
    $unsignedScripts = @{}
    foreach ($folder in $scriptFolders)
    {
        Write-Verbose "Checking folder $folder for scripts."
        $scripts = Get-ChildItem -Path "$folder\*.ps1"
        Write-Verbose "Checking scripts in $folder for signatures."
        Write-Verbose "Found $($scripts.Count) scripts in $folder."
        foreach ($script in $scripts)
        {
            Write-Verbose "Checking $($script.Name) for a valid signature."
            $signature = Get-AuthenticodeSignature -FilePath $script.FullName
            if ($signature.Status -ne 'Valid')
            {
                Write-Verbose "Script $($script.Name) failed the signature check."
                Write-Verbose "Adding $($script.Name) with the status of $($signature.status) to the list of unsigned scripts."
                $unsignedScripts[$script.Name] = @{
                    Status = $signature.Status
                    Reason = $signature.StatusMessage
                }
            }
        }
    }
    if ($unsignedScripts.Count -gt 0)
    {
        Write-Verbose "The following $($unsignedScripts.count) scripts are not signed:"
        Write-Verbose "$unsignedScripts"
    }
    else
    {
        Write-Verbose 'All scripts are signed.'
    }
    Write-Verbose "Returning $($unsignedScripts.count) scripts."
    return $unsignedScripts
}
# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBrQxpdIiq+ar3D
# EgYLBooVzL9plrTV5v8EvEG08hVqNqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwABt0wSHXWH4wadXgAAAAG3TDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCH365KaNyAH70edRI6kEpUxxGX
# RpX6J2ATTMgQlu0xhzANBgkqhkiG9w0BAQEFAASCAYAEXiqLS/LC+zpQxlwV0HP/
# yjsaBk4xczMW/xhcxcZc8JVL6DJIAyyMZ7ne72hoS8S4yliMzvGs8FQ6WRLzWG4x
# JX3cJJpV5wk9sAIiA1MEvgUMINO+W26Cl6eU3J4yYmWcFXNUZWdJtPiz/wNl2ilS
# qZwKwfexUqFgtLBjzPAGdWzc6yOYFukZoHirjhZUKvlUFpqPsU1r6FeaDXLo1nrU
# SWS2AVZK4SsUIej5Qtp4tivbflbN3z2Q9W/Oul02EfrS/HeMZbxCLICL6tkzrhiI
# jNb97uCnuZwYeVNFyA43jsBUUrF050aQpbko1hogRarYtyIbPrwpEKjCSa30wh1F
# aEoikq6o6whlG5DsThiescLiWtw1PF3hlL5riKI9fvZq0Mp5P6vgAhaoIfm6u020
# Asgpms5bvkAn4VZG8UzS3YK1v/loJcrXPFNAZBbe16L3mKi9rbN/nnWs93kmNUbm
# Xc56YhYhwTKmJae8OMClGdHz5X4tNxD0pWaR2JvXe2ChghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg/WYbDhtmHC9NtP7l3UeZHo30gbu6wA8TazS7v+4F
# nTwCBmesFbWBihgTMjAyNTAyMTgwNTUyMjMuNTA0WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkE1MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAASFV3ch50krf3AAAAAABIMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MloXDTI1MTExOTE4NDg1MlowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDLfoD3Z++SVTIY
# JFnFnPrVlMvaJYlPTronDHe0VuiHANnCKTIq8qJk4weZ+cf1+vIJ7cdl+/gw3AaR
# gAQT/iDU6vLN6QfFg1YAO6cR7voo2y4QDJPguGjKpGtONxGj9fOavAkDTH4gaTJn
# uK9mhvIzUqI7TEDV7JoK6Sy0kYsVcWbp2mF4RJ4FliqEm70YNSwLjnKn5qYIZJoQ
# YKg9ZWYzYabgr9clHsjlZtFepsTYn2hrim8vaeO9dymfk7pmXrQX2O85UQl8k6AK
# 2B8KKQVuNNnBa37EAWfxxqlO97WOvkzboNZYWHWFOlS3aklvSa+742PSVIyEgraC
# gkqIMZkVuzF+5QnuyVekXaZ/hz+3ujmyrxsnXUXbXYmQi6enT7comWGpTfRo2WZt
# +tEzvhl46YmQ9IGREfn+ZRBWr8CHA+x2q1uqg9GTfNUvkQ4HxLSeu4eqDFKj9ViI
# hQu+Yn/IGitWjufmfBKp2nigC4FFabRe4vShrA7xJtrbOFmJ3jAIRtvu2dufiI7V
# uGQCPN2bXRjiafbBXevEuhA3998ECz4uwnGfSFF1u+LS7yDZLb8NzxXnuiN4bP/X
# w3AjKBCGr/lnmSJiCwoMERhXCyLb8KUhAOzXF06EZN0xnwud2A94OTQ7o66oXbii
# 21Z6KxjnSGV1XizJNCa+P1yFEBqVKQIDAQABo4IByzCCAccwHQYDVR0OBBYEFKa9
# d/S6631KGfe8umYaOzc8HPdHMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEATa2L4B40TANMMYgCNXTy+cuK
# TjDzNZ3dAJ+S4PbAKf78FBwQ79hYihqZ/qIg6GWt/jQ5GAsBSpBYKNZOMtUMArNQ
# fIlZ42y2tylAP/xBGQ6wwmu0uBmXzg6W3TomTZ56bh90li7ZO4BbiiCg2CAkpvtT
# vrgYu7FbvvTqTIv/LvXQaCJx+sxvJPsbIAyWUSfIYTdAWlVo63sJ8AkH5pzpifvk
# LyXmLxq2jTywaeD/pKazEJwXAby8+u04oCGVCZDbD+sDOJ753hbl6XyWOXmCpXVv
# j2wPoXJdI+T6DPtc9GWtMxSDUKZtVJV2UVgACazx8gODidj6h3aGwOr8Ut/FsO/X
# 853Q1CYpfHWfW3JEkLc3FslKf2Kl2zH14EBoLeUpTykhn8NZUeXhHsuuKjPx8mUA
# LW/LglUjZXyJ3yBQ1PiOevpxTot8afXc6rlq9FJ2kgtM6ij2uW7f9at5yIcdwFM9
# VUm0aCgiXvjvRkQeSUIIAm40LX2qve2kdPgNe/Zt8yb5zDcsJjHhZPtXiW3TnBUY
# LqCsLnD6fVh6X5QvFbtjLlBIMt3XlvAQnuVEzhoyt3isww9w8t+oGCg4aNh94IdK
# vUNS1ffxC+Q+XrsT3wDlSlqNSLfooxhsCu5gXKtzpfhx8+4l9rVHJxgZE9nwGKiA
# bwNXxKFB3bVgmwodJbUxggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAA
# AABIMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAyMTgwNTUy
# MjNaMC8GCSqGSIb3DQEJBDEiBCBNdJtxcfTOX0Z66zIWMnYTFOJV6puZqxhr9HUG
# l19EYjCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIOoqAVebTwjWn0P0gLwZ
# 03YfjX3QvDtHZEl38m8i8x1BMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAAAABI
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# AOYSfUGUVzjpxDh59/qJiDRZaMMnoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 6159IzAiGA8yMDI1MDIxODAzMjkzOVoYDzIwMjUwMjE5MDMyOTM5WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrXn0jAgEAMAoCAQACAgTwAgH/MAcCAQACAhKXMAoC
# BQDrX86jAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAHMdxvh+AKKO6I2R
# MhxDcAYIx+ydQBRRKbqIzux0XvzRhzVwuIrfBXgTx1QtfpMFnv18ESHrWpwxJNYl
# r+4GXYw988HxYFnMROQ8WpNMw1IS7t+EfbAwchXbSVKREkxLbP8o4I0+YjyIUJDz
# rH76wsMT4ZtGAT5a99U+FT7ya/Rs1RHwmPXG4DNi6RSkvFsIZ6Qn+HNcponhZY6a
# zunuUa5M6f+vz/SifRmTDnZ0Zgs9/1fVJYEMkovMr6PS9VL+YZQ8j4RVS7RNMDPV
# n7EHE2sjAIo+Rxvx+KC9/+w5ChTvL4xQYSwWE4sKKwEvNclRxvg9jr3FD7aiIj6N
# e4NxW0UwDQYJKoZIhvcNAQEBBQAEggIAAszV4bOTgbgjbfqFr4bBS3++6ZRWykj5
# 6+qdkV8uHyNLC2WYblDXEYw/GFfdZygfeQLdkOxYso+v0eo4eiwEQpQ0s7LeWFef
# ywia7xHG4wHXS1AiZN40t4eyxniXYcjjYJDWza0YCiu6hqRURWOQef1RQCaMKANc
# z2fhIJS0bamKsH44y6DoYZKoSL+gM26YbelcWkaLcXB0wxYd8lMvidsBOYvJdBxM
# P3ReVKyGK48yRRbwanP952KbWzzxYwfK1cKfvT6jNZUl1wMF7FUpF+kwWYn3OHkO
# GOdpa4Rl1xhIaf1mNOPYOepjHFHXAZEa+ydiCepg9GF+845+zlmio0slFZm1edvo
# sGZQazqUR36/mlQv9NLWPBfRBfamKKSJ7TZEAoRHmKxu9Z97fLtCQe3cQ20grg8N
# 43vD+KxiVouocyfjeiPGfYJT1Q27q9w7pygA+28+HHVLH0jkpJ0MXwJ7IS0j85HV
# BX916U7e7fP80pg/bAB50Tv7Scgq2zYJmvaYrIc4jbtzVIkZ/qQi7OkQTpuuSGAi
# NfAlRICl+HE+1h896KT4tIXXQYOLazNWfxFMGsqmnhW8+rdoOVU6LVP4d9M7AXPF
# nRwEWhl89kUl4e9jrEAh8wThRbV2MmLFazn5O4lcpB+EpNVPvNkA84e0JbSQGqFp
# p6FAPQYCPFs=
# SIG # End signature block
