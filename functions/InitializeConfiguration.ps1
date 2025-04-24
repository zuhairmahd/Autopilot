function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    #print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    Write-Verbose "Overwrite: $overwrite"
    
    $initVars = @(
        [ordered] @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; type = 'string'},
        [ordered] @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; type = 'string'},
        [ordered] @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; type = 'string'},
        [ordered] @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; type = 'string'},
        [ordered] @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; type = 'string'},
        [ordered] @{name = 'NoUpdateCheck'; value = @('true', 'false'); description = 'skip checking for updates.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoAdminCheck'; value = ('true', 'false'); description = 'skip checking for admin rights.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoSignatureVerify'; value = @('true', 'false'); description = 'skip verifying the signature of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoHashVerify'; value = @('true', 'false'); description = 'skip verifying the hash of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'NoIntuneCheck'; value = @('true', 'false'); description = 'skip checking whether the device is present in Intune.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'GetDeviceHash'; value = @('true', 'false'); description = 'Gets the hash of the device and exit.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        [ordered] @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; type = 'array'}, 
        [ordered] @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; type = 'string'}
    )
    $vars = @()
    $success = $false
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "Creating configuration file at $InitFile."
        foreach ($var in $initVars)
        {
            $vars += [ordered] @{
                name        = $var.name
                value       = $var.value
                description = $var.description
                devdefault  = $var.devdefault
                reldefault  = $var.reldefault
                type        = $var.type
            }
        }
        $Vars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "Overwriting configuration file at $InitFile."
            $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
        }
        else
        {
            Write-Host "Initialization file already exists at $InitFile."
            Write-Host "Would you like to overwrite the file?"
            $choice = Read-Host "Overwrite? (y/n)"
            while ($choice -notin ('y', 'n'))
            {
                Write-Host "Invalid input. Please enter 'y' or 'n'."
                [console]::beep(1000, 500)
                $choice = Read-Host "Overwrite? (y/n)"
            }
            if ($choice -eq 'y')
            {
                Write-Verbose "Overwriting initialization file at $InitFile."
                $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
            }
            else
            {
                Write-Host "Initialization file not overwritten."
                return $success
            }
        }
    }
    if (Test-Path $InitFile)
    {
        Write-Host "Initialization file created successfully at $InitFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create initialization file at $InitFile."
    }
    return $success
}

# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB+FUBke7Pm2wt6
# f9qS/OIvMBkHOLu7FFI7J9xT6dnCbaCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACmS1y3QvPn1BnGgAAAAKZLTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCG4wVAts84+NaNLtYDmMZ/68QF
# pVTCRHPd0SPECTLahDANBgkqhkiG9w0BAQEFAASCAYAzhwI+6TeE+anemytQWAcT
# 7x7PzVcO9trC/rtt2p096G1R6zMJyKI7THGdU36qd9SA6hUJuyj1VoriLr1tpCX/
# pM+RTFizU4Z491LLd3avibyrwTiACKpjCbd9pTNUm2TRiAIwiv+r2y2liOvZ3MyO
# jwBJERN2kUDUCcXMKelnoFP2cUhxsiEVnzb+Xx2XnfcAF+YU0ORz88n2uzrdU9Gs
# A07hLABgVteK0mrXErMEIx0fvenM7TjIc8c8l/ikvU0H8hpw8kZyL7+1kPQOafHV
# mVJODawVh4LzNcI9SWv2AzcCD/0bA5ryW1aTM2njLmyDdSAaovtxz0xOE7Oy5uhK
# iHqB8hY5Uk2l9s1PthS0uNiBF+4RtnClj0z4x+I7yh0pgKh7KOXJDB5qzsoqSUJZ
# sn3z2/xgoxpJNOa8s9qBnQnQmsSnieXsKa9Sa7t110pyajv1AHoIvAIRnMCu5Crf
# j45vaNF8bpUhrthOaiXliSkMbr6f+klUDrt2ELJpaxqhghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgsgZLmab0xHfdQ4YDgj0pQs3Qj8etDsQCfQ9pN6sx
# Q30CBmgHqYp/2hgTMjAyNTA0MjQwODAyNDYuMzQyWjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046M0RBNS05NjNCLUUxRjQxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
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
# EzMAAABGF+R1esr92uUAAAAAAEYwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODQ5WhcNMjUxMTE5MTg0ODQ5WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046M0RBNS05NjNCLUUxRjQxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsJV86I/zDS9QX51f
# oIOHdH2bptR3VCYnUjU3A86Ryb5iAah+euswWHFdE8je/t6jpyY6aE8eiQTIDWJy
# +QZk1/R65l9FnTTC3++LuzbQUrgA9rH+p9qlFK8+4vH+69CYmYsSiZ5LwP9WpCx6
# aUDAwroNaAtAGI3e+d2+b8tb1nax1xPYS+9QWXuQwquf+CwZ8vGjkGZc743sIDjZ
# ImZvkn3LZCY4fS8XZA5auRLxhOmFNLgt+1xe6pB7yJLA9vl4AT9JRDH5jyaNnyPR
# cCAPWDF+yiCDRDOTmOp5Lyq8jPbOWyui1eM+PDWKYiNcbx9eWA6bPtfZxwrSjFU2
# XQeHGIQNHVaie3QLuFXMVMA9QBHDMVmyDkdc+jhZFWPRl+aB/JNe3fbd+T1n59F7
# sVuEhv64poLRYKRP7IUbMuZzAmx8ngnVtB3taZa2EKk7Ehz9p/5c9gwoCJZ8frrz
# y1X+fiRv9XdYvy3cGwtlh+lBBCcmSJd2tGMDOK3c6Efj+HTvSP9qFjsVwmKhcrWH
# QsvZYxC1MG8i4640XXbXkfEE8awn2nSqSnxWOgJPxzWT1B2gD2pN22jiL1e0PGsa
# Nw1kMtom9811eoTDzbdb/dKb/qvXWkHcFM1K4HG8E4Xa0YVh8JUSFYNrEeuvBz5+
# P/JfYpBqJKy+oAJlcTbMBGfWsAsCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQRNtDU
# r3awumenJukTxj/GG6iK8TAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBABSFuS/oBs1+IMh6K0t92Cl7ivYg
# vdYmU6Zt9MfxHRxulPDQLtqorcsY2VaujA6t9NILKRtJ7cy2KlYY35Lu4jcxO/JO
# rTYBQq/cLxpCB3ivkNkQDvf7OUfK4TQvpcsDgfuiuWYtJHztGoFV3+zZNjuheg/Q
# BMzS4oxvnDnuRH9heZeGbFUpCxQiOYxCwvq+CpzWY7p3Pqr40s9g5DbF364xYcpP
# iu7+1O/iRWfJGefMhbsRF9HMQyqSS8YjYfzgwji9lMWJIcnyNwEdBIX8V/UGR1YM
# cmcJ2r0d+Rcai0ohk3gCbCu2Dd2yMcrj+ngnJ5F/EzHabvZDw/e7B5zO6aNFEA64
# 2je3rb4iw8Z2sdp3pnbyVtwXsDixaw9Z0p3e2R3Txjwd6Fkwmivf918EBES4t14/
# h2XPPUT+dDbe4e/txuqKtpF2DYnSPYlnfoC/pb5EGR/WEyHwQi1o77l71FFFPgLx
# SNNFLaq73ayHaghWqhPRx0IEn13kOd8S1nTAs7VD/2JzF4icTQZHOlBNqcf6Ovvy
# 1yQyKcCF0eB0qHS35H7DUJehRaydcbDmBkh73BZB/N/PUZlL6469TQW3XrHOAbuJ
# KMft3GmzmXNc5vPRvtUUS9rUXhc0jJWEhjt4ip9xhl5kIkZhZQW9wqW1FUM/n4MV
# TH3i9I+C5ikH09YyMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEYX5HV6yv3a5QAAAAAA
# RjANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCBnMqw9V7dpvyhXieChsjsFJNjzBW6SyWO1k0gG9K4S
# fjCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIBIndkiaVD4+cUJu9zOL6g5l
# YdUEek4rk1FZC9z/ForOMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABGMCIE
# IJYmzsKWPso8Pu8hSSqggD9H+bw12tar5LtyYq3TcuznMA0GCSqGSIb3DQEBCwUA
# BIICAFGRtiL4hh0iGCPABKE9VuU54pGMuEmt2aHSKVPhF6/wVGOTpNCPDGgSR4sh
# 4C0OBks5bXUx6fkF+2trvhGLqBqWduhhzuSCG7ep6DdR+OCP7xJ6LeImYBbHkkGI
# Zu1jW5WHxjyV1nq/KxUwM80EJ0kQWmG2Y8j6Igia2qXo45oEDRavac1awZ+5vmZa
# onYbstxKIrotd+1OyUwZ6KOUDrXmp5QNlwCqu01ZgC9avz0zumhNAja5t/RFtTRg
# wkXIN/sJrDBb6b1y8oCcOjoglkiUgObSiUbnAcHGaysoSwlntUxxs+TABklICj14
# F3XYekHJGRyi2oiySrI7HYAYBUA+6+wMFHJYcppWdoqTQlpTPO357QHmmWpAcMcQ
# uGpEcP5+Pms1ylz9BDEYBA8sw/64O9XadSV+1mfwk3czkUnyNXX+ICPPakqdeLWp
# 9puuiVBe/NoaVcihBR9Bp9K6kCWoJky0XDb+VK7270CmNw85W6sirrubwhF2cw7D
# 4KVlKGcqhqmI1kNsfP5miy8N6RFQM1PMq9+PBoN+7rv7oUP2n2959UDCgWwr8db2
# 6ss8UfUXK3pIwc/Jf0jFbQYS5gt9uAeZVw3+SBigQCe1qbAMmt0WiSABVTLs40nD
# JGIMYiwS1bmyMhO24sSX4o3NynCudSZ8qQgYRTINjne/T9RS
# SIG # End signature block
