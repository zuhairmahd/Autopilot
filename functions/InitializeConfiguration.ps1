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
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; type = 'string'},
        @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; type = 'string'},
        @{name = 'Name'; value = 'localhost'; description = "The name of the device to configure."; devdefault = 'localhost'; reldefault = 'localhost'; type = 'string'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; type = 'string'},
        @{name = 'AssignedUser'; value = ''; description = "the user to assign the autopilot device to."; devdefault = ''; reldefault = ''; type = 'string'},
        @{name = 'check'; value = @('true', 'false'); description = "Check the status of the device."; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoModuleCheck'; value = @('true', 'false'); description = 'skip checking for installed powershell modules.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoUpdateCheck'; value = @('true', 'false'); description = 'skip checking for updates.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'UpdateOnly'; value = @('true', 'false'); description = 'Only check for updates and exit.'; type = 'static'},
        @{name = 'NoAdminCheck'; value = ('true', 'false'); description = 'skip checking for admin rights.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoSignatureVerify'; value = @('true', 'false'); description = 'skip verifying the signature of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        @{name = 'NoHashVerify'; value = @('true', 'false'); description = 'skip verifying the hash of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        @{name = 'GetDeviceHash'; value = @('true', 'false'); description = 'Gets the hash of the device and exit.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'Redeploy'; value = @('true', 'false'); description = 'Check the deployment status of the device.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'SerialNumber'; value = ''; description = 'The serial number of the device to check.'; devdefault = ''; reldefault = ''; type = 'static'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Gitlab'; type = 'array'}, 
        @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; devdefault = 'main'; reldefault = 'main'; type = 'array'}
    )
    $vars = @()
    $success = $false
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "Creating configuration file at $InitFile."
        foreach ($var in $initVars)
        {
            $vars += [ordered] @{
                name = $var.name
                value = $var.value
                description = $var.description
                devdefault = $var.devdefault
                reldefault = $var.reldefault
                type = $var.type
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
            while ($choice -notin ('y','n'))
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
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCALYlaYfP/xu8WQ
# taq+xdRkzsjJaIJrbdjDJOlFJ+l+U6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAJHC/VV
# aeoBuDkjAAAAAkcLMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNDAxMDYyMTQ1WhcNMjUwNDA0
# MDYyMTQ1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# m+dVUR9S8R009mcG+eYqql+fZK06n4+vQebMp65vtYIT9jSJEoygqchMJL4zpPRr
# F2HJ0Li0bAUnE7YZnQkXO+JhKoU3nwpnFmJn3+7BYOP1r4MkDUt2Cvx8nVVCHiQl
# 6CVmoCNy0l2+PUbQlkl9qpA3GcTH706WGIHHTrXFPTPBgU2iz/2Gg5BBusmdBw/I
# nNHip8+G9ZpAIofm5fp7coKFiMBS4TkZs7UmQWGf4QRRiom1LsV0tLhuBewLZET/
# hw6/8aCpfYs5F7hPvqFEbzguxHU525M4efvPQCwrRHTkV4+OSoVltAwoZgoVsKCk
# 8FJOaOpBXq7W3bxxBD9ypxQirr/j6eAaCNTEpfvE+fOiNxy4QG9jAsHMFUPASYZa
# pHEw7wCD5Y5on7wCPcLCuPzEsD+BOi6X/cpGnYbe8mOTIY+8ZNUSwrogLi4Ejeic
# R13/BYtG5xlb9hGsLpweyuYlXGS+tVxe4y5PuqwUbFjos5kq8cM+HcpoX3l3cKMj
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFDojFzkqS17GkSMX4zL+neGVfTQUMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGN+9kg+hXJZbedk
# fD1WQ7IPuODEYzni3W6DUIRU2C58QlBnV1veZ4thhK6KUDoLmUOB4cA1Z1T+u/Qq
# 3yebLQprRSPZkEbRoZFmBMSdUcXeN9H2lbSvn5sHGNyxJq7eFjwWOqkCDXhja1wq
# jeA3jVV3HJVjEw0b9gAuNOSnBE03JtS7uy5686tUSE816iO/FUS1RdIL8UGZFe1R
# /7TEX7Yh/QEocFXugzCXW0a0+ec1wf7LBtWeYU0m6dVb83anaSrhPTbRGgtAtzUE
# VWWX/snKYoZf0tK/eN126ykgjbL+EIrfkva5Gml++xUMVUUL7IvQMJ0xaa3U5a+Z
# Xh8D4VQnMqOwv/29f/WyON1MaDMPFgA3jA7iJ6kez9e8t6UiPNpY+r3LPjJArFYL
# JFQQU23HCKhkBChUtZnVdaWctfGjiimP7PttxW5VslvxUs3Eas5Z0oaGRXJ1CBKq
# gVPFml7yOJaytyJXb46djU3+KN6mtUwl1QccSJgulOUxi5RuDjNbayAKCCDLmVA0
# JpqfADZpEMjvJJfFtf3rRyCXyWJfHmugYig87Dovcl+DbykMCQDwf6RmYu6FwvGM
# My4e0gKfycKNPd8e/o15MxwvDfuCnocs8oVeB5/FThk9chG/fCQnzEzIpe78cQMH
# NbtPq8/Hs/oA3Kv3Tlw4TRmov/q8MIIG5zCCBM+gAwIBAgITMwACRwv1VWnqAbg5
# IwAAAAJHCzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDQwMTA2MjE0NVoXDTI1MDQwNDA2MjE0
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJvnVVEf
# UvEdNPZnBvnmKqpfn2StOp+Pr0HmzKeub7WCE/Y0iRKMoKnITCS+M6T0axdhydC4
# tGwFJxO2GZ0JFzviYSqFN58KZxZiZ9/uwWDj9a+DJA1Ldgr8fJ1VQh4kJeglZqAj
# ctJdvj1G0JZJfaqQNxnEx+9OlhiBx061xT0zwYFNos/9hoOQQbrJnQcPyJzR4qfP
# hvWaQCKH5uX6e3KChYjAUuE5GbO1JkFhn+EEUYqJtS7FdLS4bgXsC2RE/4cOv/Gg
# qX2LORe4T76hRG84LsR1OduTOHn7z0AsK0R05FePjkqFZbQMKGYKFbCgpPBSTmjq
# QV6u1t28cQQ/cqcUIq6/4+ngGgjUxKX7xPnzojccuEBvYwLBzBVDwEmGWqRxMO8A
# g+WOaJ+8Aj3Cwrj8xLA/gToul/3KRp2G3vJjkyGPvGTVEsK6IC4uBI3onEdd/wWL
# RucZW/YRrC6cHsrmJVxkvrVcXuMuT7qsFGxY6LOZKvHDPh3KaF95d3CjIwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQ6Ixc5KktexpEjF+My/p3hlX00FDAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBjfvZIPoVyWW3nZHw9VkOy
# D7jgxGM54t1ug1CEVNgufEJQZ1db3meLYYSuilA6C5lDgeHANWdU/rv0Kt8nmy0K
# a0Uj2ZBG0aGRZgTEnVHF3jfR9pW0r5+bBxjcsSau3hY8FjqpAg14Y2tcKo3gN41V
# dxyVYxMNG/YALjTkpwRNNybUu7suevOrVEhPNeojvxVEtUXSC/FBmRXtUf+0xF+2
# If0BKHBV7oMwl1tGtPnnNcH+ywbVnmFNJunVW/N2p2kq4T020RoLQLc1BFVll/7J
# ymKGX9LSv3jdduspII2y/hCK35L2uRppfvsVDFVFC+yL0DCdMWmt1OWvmV4fA+FU
# JzKjsL/9vX/1sjjdTGgzDxYAN4wO4iepHs/XvLelIjzaWPq9yz4yQKxWCyRUEFNt
# xwioZAQoVLWZ1XWlnLXxo4opj+z7bcVuVbJb8VLNxGrOWdKGhkVydQgSqoFTxZpe
# 8jiWsrciV2+OnY1N/ijeprVMJdUHHEiYLpTlMYuUbg4zW2sgCgggy5lQNCaanwA2
# aRDI7ySXxbX960cgl8liXx5roGIoPOw6L3Jfg28pDAkA8H+kZmLuhcLxjDMuHtIC
# n8nCjT3fHv6NeTMcLw37gp6HLPKFXgefxU4ZPXIRv3wkJ8xMyKXu/HEDBzW7T6vP
# x7P6ANyr905cOE0ZqL/6vDCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACRwv1VWnqAbg5IwAAAAJHCzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCpwGWFvSV+q+L2Oj2bjcjKsut4
# gqFMWYcDEFuvvb/5GTANBgkqhkiG9w0BAQEFAASCAYBsP1PdLZa1gFtYxj8axs05
# /AHR2h0QcO2njbq5sUK39c4GpZ4lhPswsClbPJmIY1YdP5PvJJTh+nYIN5SryIfy
# TPWNq1mt7HL7N5UphSgLo44zqU7jq48YzXPUFp+fU0ELAyVL5bfsnjc/nlpHOvMS
# n325ZgPtTJ5c4UJufIlut2ynrCza2i0rRW5wJfa/+fFA68Vk7WXfxWLY2SJXrYs9
# 7F88z8Tp7id9J5fkYlWgdR3ZogKKo5RNhncTaHyXGzKyMPq8OsmA2tUHoBPiePRt
# 1xc+0YZdwEx+T961HnMBKRquKzgplwgQQVPUEutzS7g51NgfvqL1fPCnXpd4T/pd
# wE4BWcgoh5ZZIJF5y+fszWpiuSG1eNnC6On2OkEdydYjJBrmOlwYAoNU/yr35j9k
# FdN7bmj73ptDr9ptmxcqpfsDUbKNhS1dfTAZjL1k2KmpP9JHAnqwaLYx4x9T2Cun
# pH620gksqPJaalxW1XVerwkRk/XPpf/wmNb5kxUU07ahghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgNKZJiBEgmchZsoiJZGFM/CxpwwDC4y3RQkcp1qiI
# 9pgCBmfnvfndtxgTMjAyNTA0MDIwMjQzMzcuOTM5WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAAR+OVCzehYN3HAAAAAABHMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MFoXDTI1MTExOTE4NDg1MFowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDocLpu99z/+NeI
# ZmR32GJg2VT/jd96pYLsvNngeH4qXwK1qVmFaXXkkVbxb1fOQJMukYkba3WEc69W
# /Z4BszAuxguThDVlY9sk4ZYkGMgxoq1Z5inUPvj4Qh8xVvlhiAS6Of/uLwDsbsKl
# g2fGpmvztiPSOL9P15k00I4bsl1vlmRSut2tNwJQ5sXpoT7GI/2T2A0GnWbFECKR
# CyGW9rsny9o0LNIUl4NYAd4awGSs6OIzKPpIK1JfK90wXHvaXwGJcN9P8QPRJIHK
# uFoVGzIUG/C0jQC4rQ62yTGvc2sZ4AxTQwflfVBBaiHq8gn/YDHpZileGkB2IQaz
# ZEiEc5Or5Xer9mUDU+2FEe66w8e2WkLXanqxaD5+Zco+E+QdwcTYGo78jFxPDvNr
# aTr5QAgITc4dY/PBC3cYFzcgDyUx2xOVCBvgabqJxj7rXrj4Bhd2S/ZTYOVHhi8c
# DWBaefM8JgiO8GCIIRvlNWng8FKFt09ZfNxmsSdCJlWw3rNAwsBY1xp8pmmv9r2M
# 9rNIRkZ+sh0xd3GuASWs2bOrqBi0aTzgY9b3CxY+/m+RU+UTim5JkmpJM/AIP68/
# S+1NwFqXK5yxTJBIInhoEgdEHi+a2JR2SlV3AkpJa0/B6sZaoEa+zgshIfFa66XB
# mnnsydV4uG7W1INoaNVwxBKDdmqNRwIDAQABo4IByzCCAccwHQYDVR0OBBYEFORU
# dlggOj7vT7m2XvFhSEW8ht1oMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEADSJUQ9XamDh0gkC1XvrhVz6A
# MwGVKuKJA+tklJzBa4UVYP3Y9r1RLU08RYJIjPEkpwiwDWitK58gsZxwNh4Nc4fF
# iQrZUJZ9BInfnodv8WOO83zY8YQdJMcpgBzeYVXiNCedumqFKXj0mMMuWaBynv7w
# wn7FnHJwzLru4jt4VLeef+BycnYwPoMa75LF/9xZo/0TJ371qtBYdbsceKmNhQUT
# D2vIvvPkHTPH/NA2IkLsQ1Am51nzh52WEDzRCoXeld6+/KClnfsEB1/vfR6pYPxw
# ZTvTZ7uh7y8D6g4hDpEcjIses754W2aRpxTPru6n+z2EzkvHF70B/g5oAodmVTUB
# b+pxpu77UHm0TraVodjfXJJNs+h1RjnCu9Miku2KhPmpBrsSne31y3gXstm5vctp
# 1tFox9amTWvhIV88l1EIC3yX+BN9cGKtL65REl/y8yqa2PIW2i18JMRIr4T7liHf
# X0A6sdPsl7GudLyEVHAWsW8NFVzt/vdyRhzMUpsxhPL1qGQgD45Q+3bgTlel5MWl
# WgYG+b+LLUXR5uiybbIswnORTU/jDycNAx8u4c5+14sen5/fmqcrQa316l7WqcQ6
# rOcoxDFym7k2RVuEhZNQ4XNXCKI7kb8PMrRtMbobV0mryd0UlbQUbPsJuN9nUE2A
# DmgnO3bQGyERvppedCExggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAA
# AABHMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MDIwMjQz
# MzdaMC8GCSqGSIb3DQEJBDEiBCBcZ7xHUeyA3Lmk29+t8F97tLxMRzUKAnKJDDib
# gPdGSzCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIJNm85ZyhQAGGe9QPhd3
# +xvmMKCvfjHhf8tl6mRICsynMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAAAABH
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# ACAF09m+ILyMNydZT7P3lOLNVFzdoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 65bZsTAiGA8yMDI1MDQwMTIxMzEyOVoYDzIwMjUwNDAyMjEzMTI5WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrltmxAgEAMAoCAQACAga3AgH/MAcCAQACAhMsMAoC
# BQDrmCsxAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBADMOIua2lonhWYMT
# 9hNT3f5aIlDvptFt/cWcczDEjDbc+EL04LTxuR1474rlKFtUFFgNFitL1M8W7GDZ
# 9GoJI16spN3jKRwYfxZQsfUkml54Meh0VApOA3u8vAFC5JP+V8hBBA9rLq7aCqJX
# Kr8RhX/MsXCp4UXbHpfGdZs29BkV46wftxM5BOZbjIOuHCgfSTq7ChnILSvyr762
# 1+9nuiZlPfO324B8XLoqGslosEsOqh+URERpRAgwAHp9HdMAkx6SGehxhxHy2U7x
# col1CrhtZU0StWDPrfE3LoNVCIALSdclwAGPWJiLlvmKtpXUqlK6Dla/Vkeay+EN
# mBKMQ4EwDQYJKoZIhvcNAQEBBQAEggIAu4ak3VzQ5eWLbtIr+NpAlyIgye9biXw4
# Shyu6d9JfR+/NPV9c2brF0ke6F9JDyg5M+hHMA7PDUoEjB9aB2O7fiLhWhGT4wTc
# 8esOZCf27T2tjXtPRkZCkuvn+nibFWd4YwKOtZrCPhlFeQP4n93GauIHvShH8B0y
# Fuw2IcSkHNOK4u3ResqX0ZleG2fLDIymejECJWq2GQzIrwKPJEB1SuEKOh0hdyOs
# imd/ignT5A4zvEj65gJYpa8STdQWC4+i5b8x0JzefeGPjiOyZu3frK57VM/yuQGW
# KFDJbVr/maDAeJ7JBqVL/LWn8pToWiji7mnUCvmBaW9zghBG7jIdifCSNxiuCmln
# YaOvVACDJLlgKUaNWd8pJuUG3hIt2de60Y9BKcGb1bWuH3yeBWRZ9r57xTM2wR/K
# s0LDHAKlmg0tsq5u94mfXmcvF0xvNTqx4ItNF6cKCpIaqtz7pckV3LNsh2e3iz5q
# OV6nDEbKEJYjTjdZs4vX2Yzdn0Vq+Az1v2eJIfRENuFOXf6nGrQVmAPOGzv/lpca
# SxV9euD4SyqSjR9nCz9ltjKkIOPShwHKEhJvqfl0SHjUCB0NB5FftR+7rBkpSkIE
# UaJXgWMHetmcP/kU08kU2xOVNQRc7VWoebDCC1lojIPRBT2e8Sbg7d10QRWQbyP6
# dhZYI+nLA+0=
# SIG # End signature block
