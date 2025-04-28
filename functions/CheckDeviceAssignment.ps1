<#
.SYNOPSIS
Checks if a device with a given serial number is already in Intune and verifies its profile assignment status.

.DESCRIPTION
The CheckDeviceAssignment function takes a serial number as input and checks if the device is already imported into Intune. If the device is found, it further checks the deployment profile assignment status. If the device is assigned to a deployment profile, it outputs the profile name and indicates readiness for enrollment. Otherwise, it provides guidance for further action.

.PARAMETER serial
The serial number of the device to check.

.EXAMPLE
CheckDeviceAssignment -serial "123456789"
Checks if the device with serial number 123456789 is in Intune and verifies its profile assignment status.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 3f2504e0-4f89-11d3-9a0c-0305e82c3301
Date: April 5, 2025
#>
function CheckDeviceAssignment()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [switch]$WaitForAssignment,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$waitTimeInSeconds = 60,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$maxWaitTime = 30
    )
    
    #region variables and logs
    Write-Verbose "Received parameters: serialNumber=$serialNumber."
    if ($AccessToken)
    {
        Write-Verbose "Access token provided."
    }
    if ($WaitForAssignment)
    {
        Write-Verbose "WaitForAssignment switch: $WaitForAssignment."
        Write-Verbose "Wait time in seconds: $waitTimeInSeconds."
        Write-Verbose "Max wait time: $maxWaitTime."
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $assignment = $null
    #endregion
    
    Write-Verbose "Calling Graph API at $autoPilotDeviceURI."
    Write-Verbose "Checking whether the device with serial number $serialNumber is already in Intune."
    # $autopilotDevices = CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI
    $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
    Write-Verbose "Found $($autopilotDevice.count) Autopilot devices."
    if ($assignment)
    {
        Write-Verbose "Found the device matching serial number $serialNumber."
        Write-Verbose 'The device is registered in Intune.'
        Write-Verbose 'Checking profile assignment'
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($assignment.id)?`$expand=deploymentProfile"
        $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI
        Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
        if ($WaitForAssignment -and ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync')))
        {
            Write-Host "Waiting for up to $maxWaitTime minutes for the device to be assigned to a deployment profile."
            $index = 0
            while ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -lt $maxWaitTime)
            {
                Write-Host "Waiting for $waitTimeInSeconds  seconds before checking again..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitTimeInSeconds
                $index++
                Write-Host "Checking again..."
                write-h "Pass $index of $maxWaitTime"
                $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI
                Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
            }
            Write-Verbose "Gop final device assignment status: $($assignment.deploymentProfileAssignmentStatus)."
            if ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -gt $maxWaitTime)
            {
                Write-Host "The device assignment is taking too long (over $maxWaitTime minutes)."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose 'Congratulations!!! ' 
                Write-Verbose "The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
            }
        }
        else
        {
            if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI
                Write-Verbose "Graph response: $($assignment)."
                Write-Verbose "Device details: $($assignment | ConvertTo-Json -Depth 10)"
                Write-Verbose "The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($autopilotDevice.deploymentProfileAssignedDateTime)."
                Write-Verbose 'The device is ready for enrollment.'
            }
            else
            {
                Write-Host "The device is not assigned to a deployment profile."
                Write-Host "Please check the Intune portal or contact an Intune administrator."
                Write-Verbose 'The device is not ready for enrollment.'
            }
        }
    }
    else
    {
        Write-Verbose 'The device is not found in Intune.'
    }
    Write-Verbose "Returning $assignment."
    return $assignment
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD3pPQ5/JU4Djcp
# zHqbUCCu4MuxyRNeh/6stxkjSYIcKqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOBkSbr
# 6+lwVlNvAAAAA4GRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI4MDQxOTQxWhcNMjUwNTAx
# MDQxOTQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mf7+tbRuD3PX1o3SA5VcMyu24VWwwXFUAKuJ2oHdop3XXh7bGz5l0hJFpYa4AV53
# drxAPr+yqkrMkM7TGBUpHoh5GR72SDwxqL8vct8vk/RvPzGh00mADuoe6nZEmlhM
# b3hd1jSBshAAOp6YriYs5Ya4vczHUzGC2J0/v3grIM1Szrb1W192P9H/wrnvonL1
# 8RpqWqMBSTkmm+poFuQg8L4IOGFjNIwZbFtCoohbaAb8Le87voODb3PTZhSr6pY9
# PHE2z78757rwj9dBuCPDlJJ4p9IF8GcH9x+vtmESbzPr/oi38GOKlYH3d/oL86oJ
# 8otscnjWUswDBjFa3gzS3TsEDZZTVk3X065Nd4Z8ztaN1c21L1D1pgSH7DZpjK37
# WohRZ3EqLj7tdqBDXIBfXft3hKP9hqdTpQJscHlY3nroJO972+76ZUmx6gdFHPG9
# 8d6FXU0iP+VddIxaS80/lJLPp8/N07dvTXUD8CnJGkx7VpDDN0j5KH94qGcfWqxT
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFH/Gq1LSAubj5J7trvB4xaAA4rAxMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGpzME+ppSK7DG6k
# npXQw635cDKMdzVSx3mUysY/F872vnb5WTj+DoM/hUdH1oKsH6j6Vor3dshcU6IR
# GPGL0Mp8HPoqHbDoq1LR75T1IJA5SYB+yZH6TYkcjxDT4yhJ01rf74/x6JWtUi4Q
# Jjg22WFWxcD/UT5NmivRgQSMhQsLUKI9XaGBgYJuNSIJWkwYWaPBwoKpQz75IZDI
# sdl6311rU5IwkbUeXLvu7oInIBhv3hthwAzqho3u90KewmUZyP9Tma3pS8bXJXXg
# zeBLTk7vRYJzeDa+Wy0YD3gsAJqwnrTZ0VArs7eyFcK7G1go01B7ACd+YYi/FBt3
# EN59yRmn3vvJLLeFnfH8+7KOKr2JDiCnKnc4TdmiZOaZq1HV8s6ILDgfaWhrH7ve
# nKieancFYDNXomvmT7J1sOvZjMG/nBuhBfGTV8CoNXVOpNuW5et8biQuDu7ypPT8
# NDgcKpaz2Oj0AtOGgZYxY7jZF5diDx6vwF/aBwOKWTOunRnWo78z0vSsmUKPPkwm
# 1EhbhvpVWY7aSLqtQBAN8W5mle3fcw9mZt8Jk2BLlVIRJuDM2cUEuAUYXDr2Gl1Z
# lexNQUhLHDjcWCV8QidoXa6iq3pNnuphkbzUj2/t3i0vmKMnbMUniqjO0Gwl/rIf
# NJ7T5tGwLTVNY4jq1uPPD+ZqAhLYMIIG5zCCBM+gAwIBAgITMwADgZEm6+vpcFZT
# bwAAAAOBkTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyODA0MTk0MVoXDTI1MDUwMTA0MTk0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJn+/rW0
# bg9z19aN0gOVXDMrtuFVsMFxVACridqB3aKd114e2xs+ZdISRaWGuAFed3a8QD6/
# sqpKzJDO0xgVKR6IeRke9kg8Mai/L3LfL5P0bz8xodNJgA7qHup2RJpYTG94XdY0
# gbIQADqemK4mLOWGuL3Mx1MxgtidP794KyDNUs629Vtfdj/R/8K576Jy9fEaalqj
# AUk5JpvqaBbkIPC+CDhhYzSMGWxbQqKIW2gG/C3vO76Dg29z02YUq+qWPTxxNs+/
# O+e68I/XQbgjw5SSeKfSBfBnB/cfr7ZhEm8z6/6It/BjipWB93f6C/OqCfKLbHJ4
# 1lLMAwYxWt4M0t07BA2WU1ZN19OuTXeGfM7WjdXNtS9Q9aYEh+w2aYyt+1qIUWdx
# Ki4+7XagQ1yAX137d4Sj/YanU6UCbHB5WN566CTve9vu+mVJseoHRRzxvfHehV1N
# Ij/lXXSMWkvNP5SSz6fPzdO3b011A/ApyRpMe1aQwzdI+Sh/eKhnH1qsUwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBR/xqtS0gLm4+Se7a7weMWgAOKwMTAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBqczBPqaUiuwxupJ6V0MOt
# +XAyjHc1Usd5lMrGPxfO9r52+Vk4/g6DP4VHR9aCrB+o+laK93bIXFOiERjxi9DK
# fBz6Kh2w6KtS0e+U9SCQOUmAfsmR+k2JHI8Q0+MoSdNa3++P8eiVrVIuECY4Ntlh
# VsXA/1E+TZor0YEEjIULC1CiPV2hgYGCbjUiCVpMGFmjwcKCqUM++SGQyLHZet9d
# a1OSMJG1Hly77u6CJyAYb94bYcAM6oaN7vdCnsJlGcj/U5mt6UvG1yV14M3gS05O
# 70WCc3g2vlstGA94LACasJ602dFQK7O3shXCuxtYKNNQewAnfmGIvxQbdxDefckZ
# p977ySy3hZ3x/Puyjiq9iQ4gpyp3OE3ZomTmmatR1fLOiCw4H2loax+73pyonmp3
# BWAzV6Jr5k+ydbDr2YzBv5wboQXxk1fAqDV1TqTbluXrfG4kLg7u8qT0/DQ4HCqW
# s9jo9ALThoGWMWO42ReXYg8er8Bf2gcDilkzrp0Z1qO/M9L0rJlCjz5MJtRIW4b6
# VVmO2ki6rUAQDfFuZpXt33MPZmbfCZNgS5VSESbgzNnFBLgFGFw69hpdWZXsTUFI
# Sxw43FglfEInaF2uoqt6TZ7qYZG81I9v7d4tL5ijJ2zFJ4qoztBsJf6yHzSe0+bR
# sC01TWOI6tbjzw/magIS2DCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADgZEm6+vpcFZTbwAAAAOBkTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCi+MP2x70P9BE6DUX1jzP17HE1
# EHQrmO/d8VrRnoz63DANBgkqhkiG9w0BAQEFAASCAYAaP53On86kyXvA7JxuJTH0
# G9vnWbDNn8PDcTOKT8GajZxW0esiJ2bAv1Ix9B3DQYlN7uE5OZoRGXnT9ybOlpxD
# wk+0HPRqwgkfUYN4dmxe7894f0OGgqghXHaBRZkrr28SnBohCGqAYz66YvnbRM+q
# 2UVo1BVSXEVSqia4H07oGqQEGv3AZJ6mFIEoNqlk8xVwH3RgnzNBNp3GoyQAnDew
# hsW+vwkBspan0sihWRHBhVVA3BToVFB851bw18k/eFwlQ6qPlUZjOPirRZGRsUdo
# Ep1GAWc8Vz8x2MqhWUmROSG3FuC+R9AWelYQb2fld+ML/o+TyzJvFG6PALSuBvHY
# 6UWTZDztYoV15MBZgOzd6hkHFsWYtwNH82014y4fP+2vet5WmIKNOSiDK3i2sJfN
# 53xJQO+9M6mcCKMbsdZTV0COjDv/ebdXbb2h9IYflQj/kIqVFFt/7ZpMsYdfuqWy
# KAk6i7+6eOz4xBjvxL/Utqo7vGvTY2ywfXXCPhchXHehghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQguddsgdPi4jLpqDm8H43htlPTeBNHWEImtW6kkgVz
# vAYCBmgL4ht98BgTMjAyNTA0MjgxMDAzNTEuMTk5WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjc4MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAATBtLnGPC5NN6AAAAAABMMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1OVoXDTI1MTExOTE4NDg1OVowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3ODAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDcde8XEX4HjETY
# u6YHtWiP7+6Vf2abeUo/si4NcaeiKrRMTF8F7mpCoPJyo/h5VHbhyKDZazOm1cLu
# zKeVEMzDN4vuf3fZb5hSlpVlCXBSJ3YBLwLnRJtWNk+XkUMcAc96RdalToVYWltO
# IwbCCkjE42fnCafwjZajw1UGaxl4tRQNHwVk5gwC2wlVVSJREJqCSsB9TXXHIKxP
# HnnFJqJ/LI1goJ+Ve0Bar4PiKiMfnvnZ8LR3ktW24X6FDQJRKLjnJQ0JVebQEvI+
# q8Y/frheUldXeLVD4SfQNl1fLKN58o+NJsWI0ET6C8wYZc+eu+EqrzubIPXB7mKI
# 9cbtmGHvztslz1K/NmRvGGQkeKEKdOWfpfRuYxmhmeVmR1QMLe5pBccJiXw7PUIW
# +3MB0pM5SBF5FH6INtT1gf5vHwBA9vbeiiggbijJMuK0qu63sIbbE/YN4iYrCURv
# jZampsTtxmlEtN921N0qXNtNgU0vavdc/vJl/rDef6fMeQuJAinIHxcJzPDTsOXZ
# legwcCr/J52eij6T9szMlPSCQVAt5u/agNcJ212t6qdwZ4hYYF4LkCmXQgDPZpR1
# lGDCaojAB6zy/H7nME+nnTvTgTMtR4d4lHVBQxpJDnvYNvGPurrnP7FZT3ue8Yzf
# FEiE5chmJia8THexs46F8tCr8T5UxQIDAQABo4IByzCCAccwHQYDVR0OBBYEFGrq
# I3Sxu357rKTylpgwcVAF1Nw/MB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAAFYcd7rrNVHRZWofhE4ft9YN
# ZPVEzaQ90iE/5kCDoQlCKTE7jFYnFcfxETrL4ed8JSj0JxCZSJQVUwEp6haUSPki
# Sg4mf7rq+m3qbCjHB8Dj82rsFSxAs8NqI/08Dq1Ci/rxVhryPOSZmtXRgNeJzxwD
# qSch50pNBGQMU8APLSnwpqzhwRN76MK5PXYCVqm/u/v579+fFJh0bIsw49/wTcTC
# Xh3s0C9y0iAmSvsJKnTfEvtfe+eS9qw2wyf2LdJ5n8klFJ6OtDg8YB9n+E+0vX1E
# JIDPxN2yX7+2sJiABcUSc55jIHxPTArDdzR0YUwQIjZO0j9hIjyMbRYjgjJ4UK9Z
# LrvN2nUyc0upLqKKvhAqKP1jX0FL5M0wuneZ9/SGy2ZFn/Bg8ISBOp34ri+412tO
# lzqR9ZU+CU9Xn1MqcWXvvDhTqjexxKZMVRMqGjRECQWSA62WdCGYjEOWnH5lQJqL
# YRhYpeAwvjszdEAjSFtFXFLGTRw4bSKoad5TjUEvsKFO8DVPCjrbMEzGdku4znme
# FddbqXR41HlunpyOLuSoC1II/Bh+aX0nU19JU79T10OFRKZDFKUI3LWB9jTdT+3E
# OJr/pQ5T0fFeei0A7UdmTgXbmP4IaCbTc41NG7KMmsmV6Xyank4qB5aSL30uegrr
# vnHPjQBLLYjerGCNtQMxggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAATBtLnGPC5NN6AAAA
# AABMMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjgxMDAz
# NTFaMC8GCSqGSIb3DQEJBDEiBCDCO/gkQOMP/4V2QRbZT+6g/tXOkmvry+RO8VZu
# Ma9f2zCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIN46bOoVmqp2Rt/G6TI8
# VIZkg7qJ8OddiPDqk6jY+midMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAATBtLnGPC5NN6AAAAAABM
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3ODAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# AJueWs/5vWNYP+JGxmOfpj88ZvzBoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67msWDAiGA8yMDI1MDQyODA3MjcyMFoYDzIwMjUwNDI5MDcyNzIwWjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDruaxYAgEAMAcCAQACAh15MAcCAQACAhN0MAoCBQDr
# uv3YAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAHo3y0aGlhFzF9qIyZ6q
# A5R6HVVF4pdYOQePXBwx/XMFXjFsiZcM3pn88nmYun+UEn/EUYyrCMRL1elVsyjO
# a5V5CpX24NV40usytsY7Co9rkidCUXjsF3pGBV1HBIDLyEYXxMciKhlx6WMhs16M
# DZGaSHXi0QK+cqRp7AR/C1zSaRrkVV94CWPJu1yVb1zkyO0p4YQLvlMgVZWhofat
# svq8udMFcgKA1MgJeibznghBGTBM3J3voqbY3TtsoIywhtOIj0CmalWFz2aySti8
# Y6YdwTU3ZC3YAEugWigAMq5+A9tIGo9yPotmlincOzY//CT4PQa3hkh+D++ax8b5
# pLgwDQYJKoZIhvcNAQEBBQAEggIAa4gb6lSNF5XBwAxjrGVmz9wJDWAC5Lw/NwBt
# AcZ/X9QMiaJMKLPqa2+y6RkRVu8rXlolOvf+Dcom4EVdfH4gvR5jnLba7FXkn9gs
# v85AgodtKCAWtEydDzesJjLW0q0ax6zyX2Hd5Np6fN7TDBamZNYUnqXq5q00movn
# a7romwX9bURZqe8Qm6fObC+jSec4y+c7uWlOdTigLRo2GqOzUzstDvaGf6X4flwm
# RBnDVm3b2nNkk6aYzNj993ZtN/5fUJOVgsmuYRg25TejyzWqMayZjgel3S3aG/Qj
# 2I6K9i4U6T6bx8FHqUd0Y1ISZSVcjnW358ITGrb6T9ePVNTInPRCylbt8S6FjunC
# 6oTlsyLYpVc5fA+whs6yy59KWDsrh5zAiWm3Wqz9cHpaQrss3xlwAYJ14lGAv5L4
# RWsH3gdTQsZeBBal1H4+LIF7JMmyZQC2gkbcrZ8YUAxTFLQGu+zcV55iL0CR0TwH
# u7Vwt4pKbskYfar9X3LhYesNRYSdsQ4w3eg4Q1xXMTkRpTA2MPo90ZtnB+k51YhW
# k061ckioyIQIl2gH8EYRwIhoj6UQGtCj7UXj/GLCFT3uDJXCl47jbRF5nLwg9zfY
# o/3NmXxYLVbpVi96ZJcw2QeHDy0Y10PG7l1jHI0xtDBnY509qambwjFfYyyE9ame
# 1X92ypk=
# SIG # End signature block
