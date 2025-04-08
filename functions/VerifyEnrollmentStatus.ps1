#region help
<#PSScriptInfo
.VERSION 2.2.0
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Verifies the enrollment status of a device in Intune and Autopilot.
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, WindowsAutoPilotIntune
.SYNOPSIS
Checks if a device is enrolled in Intune and imported into Autopilot.
.DESCRIPTION
    This function verifies the enrollment status of a device in Intune and Autopilot. It checks if the device is imported into Autopilot and if it is enrolled in Intune. The function retrieves the device's details, including its serial number, user information, and enrollment status. If the device is not found in Intune, it returns a null state for the user and device ID.
.PARAMETER serialNumber
    The serial number of the device to verify. This parameter is required.
.EXAMPLE
    VerifyEnrollmentStatus -serialNumber "12345"
    Verifies the enrollment status of the device with serial number "12345".
.NOTES
  1. Retrieves device information from Autopilot and Intune.
  2. Checks if the device is imported into Autopilot.
  3. Checks if the device is enrolled in Intune and retrieves user information if available.
  4. Returns the device state, including enrollment and import status.
#>
#endregion help

function VerifyEnrollmentStatus()
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
    )

    #region Define variables
    Write-Verbose "Serial Number: $serialNumber"
    if ($accessToken)
    {
        Write-Verbose 'Received Access Token'
    }
    $imported = $false
    $enrolled = $false
    $registered = $false
    $deviceState = @{}
    $loggedOnUsers = @()
    $autoPilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
    $importedAutopilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities'
    $deviceManagementUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
    $userUri = 'https://graph.microsoft.com/beta/users'
    #endregion

    #region Get the autopilot device info
    $importedAutopilotDevices = CallGraphAPI -AccessToken $accessToken -Uri $importedAutopilotDeviceURI
    Write-Verbose "Found $($importedAutopilotDevices.value.count) Imported Autopilot devices."
    $importedAutopilotDevice = $importedAutopilotDevices.value | Where-Object { $_.serialNumber -match $serialNumber }
    Write-Verbose "Imported Autopilot Device serial number: $($autopilotDevice.serialNumber)"
    if ($importedAutopilotDevice)
    {
        Write-Verbose "Device found in Imported Autopilot with serial number $($autopilotDevice.serialNumber)"
        $imported = $true
    }
    else
    {
        Write-Verbose 'Device not found in the list of imported Autopilot devices'
        Write-Verbose "This means the device may have already been registered."
        $imported = $false
    }
    $autopilotDevices = CallGraphAPI -AccessToken $accessToken -Uri $autoPilotDeviceURI
    Write-Verbose "Found $($autopilotDevices.value.count) Autopilot devices."
    $autopilotRawDevice = $autopilotDevices.value | Where-Object { $_.serialNumber -match $serialNumber }
    Write-Verbose "Autopilot Device serial number: $($autopilotDevice.serialNumber)"
    if ($autopilotRawDevice)
    {
        Write-Verbose "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        $expandedDeviceURI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotRawDevice.id)?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -Uri $expandedDeviceURI
        $registered = $true
    }
    else
    {
        Write-Verbose 'Device is not an autopilot device.'
    }
    if ($serialNumber -like 'vmware*')
    {
        Write-Verbose 'Device Serial Number begins with vmware. Removing spaces from the serial number.'
        $serialNumber = $serialNumber -replace ' ', ''
        Write-Verbose "New Device Serial Number: $serialNumber"
    }
    #endregion

    #region Get the managed device info
    $device = (CallGraphAPI -AccessToken $accessToken -Uri $deviceManagementUri -Filter "contains(serialNumber,'$serialNumber')").value
    Write-Verbose "Device serial number: $($device.serialNumber)"
    if ($device)
    {
        Write-Verbose "Device found in Intune with serial number $($device.serialNumber)"
        $enrolled = $true
        $users = $device.usersLoggedOn
        Write-Verbose "Users logged on: $($users | ConvertTo-Json)"
        if ($users.count -gt 0)
        {
            for ($i = 0; $i -lt $users.count; $i++)
            {
                Write-Verbose "Retrieving the user object for user with id $($users[$i].userId)"
                $user = CallGraphAPI -AccessToken $accessToken -Uri "$userUri/$($users[$i].userId)"
                if ($user.userPrincipalName -like '*@*' -or $user.userName -like '*@*')
                {
                    Write-Verbose 'User is an Azure AD user'
                    Write-Verbose "User Display Name: $($user.displayName)"
                    Write-Verbose "userPrincipalName: $($user.userPrincipalName)"
                    $loggedOnUsers += @{
                        userId            = $users[$i].userId
                        userPrincipalName = $user.userPrincipalName
                        displayName       = $user.displayName
                        lastLogOnDateTime = $users[$i].lastLogonDateTime
                    }
                    Write-Verbose "LoggedOn Users: $($loggedOnUsers |ConvertTo-Json)"
                    $enrolled = $true
                }
                else
                {
                    Write-Verbose 'User is not an Azure AD user'
                    $loggedOnUsers += @{
                        userId            = $users[$i].userId
                        displayName       = $user.displayName
                        lastLogOnDateTime = $users[$i].lastLogonDateTime
                    }
                }
            }                
        }
        else
        {
            Write-Verbose 'Device has no users logged on'
        }
    }
    else 
    {
        Write-Verbose 'Device not found in Intune'
    }
    #endregion
    
    if ($registered)
    {
        Write-Verbose "Device registered in Autopilot with serial number $($autopilotDevice.serialNumber)"
        $deviceState.add('registered', $registered)
        Write-Verbose "Device registered: $registered"
        $deviceState.add('autopilotSerialNumber', $autopilotDevice.serialNumber) 
        Write-Verbose "Device Autopilot Serial Number: $($autopilotDevice.serialNumber)"
        $deviceState.add('autopilotDeviceId', $autopilotDevice.id)
        Write-Verbose "Device Autopilot ID: $($autopilotDevice.id)"
        $deviceState.add('deploymentProfileAssignmentStatus', $autopilotDevice.deploymentProfileAssignmentStatus)
        Write-Verbose "Device Deployment Profile Assignment Status: $($autopilotDevice.deploymentProfileAssignmentStatus)"
        $deviceState.add('enrollmentState', $autopilotDevice.enrollmentState)
        Write-Verbose "Device Enrollment State: $($autopilotDevice.enrollmentState)"
        $deviceState.add('groupTag', $autopilotDevice.groupTag)
        Write-Verbose "Device Group Tag: $($autopilotDevice.groupTag)"
        $deviceState.add('deploymentProfileAssignedDateTime', $autopilotDevice.deploymentProfileAssignedDateTime)
        Write-Verbose "Device Deployment Profile Assigned Date Time: $($autopilotDevice.deploymentProfileAssignedDateTime)"
        if ($null -ne $autopilotDevice.deploymentProfile.displayName)
        {
            $deviceState.add('deploymentProfileDisplayName', $autopilotDevice.deploymentProfile.displayName)
            Write-Verbose "Device Deployment Profile Display Name: $($autopilotDevice.deploymentProfile.displayName)"
        }
    }
    if ($enrolled)
    {
        $deviceState.add('enrolled', $enrolled)
        Write-Verbose "Enrollment State: $enrolled"
        $deviceState.add('deviceId', $device.id)
        Write-Verbose "Device ID: $($device.id)"
        $deviceState.add('serialNumber', $device.serialNumber)
        Write-Verbose "Device Serial Number: $($device.serialNumber)"
        $deviceState.add('usersLoggedOnCount', $($users.count))
        Write-Verbose "Number of users logged on: $($users.count)"
        $deviceState.add('usersLoggedOn', $loggedOnUsers)
    }
    if ($imported)
    {
        $deviceState.add('imported', $imported)
        Write-Verbose "Device Imported: $imported"
        $deviceState.add('importedAutopilotSerialNumber', $importedAutopilotDevice.serialNumber) 
        Write-Verbose "Device Imported Autopilot Serial Number: $($importedAutopilotDevice.serialNumber)"
        $deviceState.add('importedAutopilotId', $importedAutopilotDevice.id)
        Write-Verbose "Device Imported Autopilot ID: $($importedAutopilotDevice.id)"
        $deviceState.Add('groupTag', $importedAutopilotDevice.groupTag)
        Write-Verbose "Device Imported Group Tag: $($importedAutopilotDevice.groupTag)"
        $deviceState.Add('importId', $importedAutopilotDevice.importId)
        Write-Verbose "Device Imported ID: $($importedAutopilotDevice.importId)"
        $deviceState.Add('ImportState', $importedAutopilotDevice.state.deviceImportStatus)
        Write-Verbose "Device Import State: $($importedAutopilotDevice.state.deviceImportStatus)"
        $deviceState.Add('importStateRegistrationId', $importedAutopilotDevice.state.deviceRegistrationId)
        Write-Verbose "Device Import State Registration ID: $($importedAutopilotDevice.state.deviceRegistrationId)"
        $deviceState.add('importStateErrorCode', $importedAutopilotDevice.state.deviceErrorCode)
        Write-Verbose "Device Import State Error Code: $($importedAutopilotDevice.state.deviceErrorCode)"
        $deviceState.add('importStateErrorName', $importedAutopilotDevice.state.deviceErrorName)
    }
    else
    {
        Write-Verbose 'Device not imported into Autopilot'
    }
    Write-Verbose "Device State: $($deviceState | ConvertTo-Json)"
    return $deviceState
}

# SIG # Begin signature block
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+dVv/BLGqXGPA
# +lOMaLj346FT3aCYUDqFb9D+Kmr1B6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAJTLw6Q
# AbyxO+trAAAAAlMvMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNDA1MDYwNDE3WhcNMjUwNDA4
# MDYwNDE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# pDL9ztepCuGvrQ+Az3uc39Dg/xRxogU5K4uFHTyEsHpkYagTj3v9DMlra4cxPS5N
# tifxD9lU64xOdcm3cDYyXsQVF7Upj3HoIcQk7vCms3wrTFuoa3RA+HyD9OfQduaE
# kAJ6YsqDGbg2ugwy2mcNjDFYUeAXyuwUp7RtE6ebwrF0CCLuB2GUUVCbuxXJ+NI4
# D+nWKImxvmQ9ox+gEn8tzFuTLjKFqohO6qz/ZGsHbv4yG02uNzwkS3Ed1p5JpiKk
# g8B+qxZ5VKsiyN/6YRGRqLk9q+OYxaz+vR7B+6IAw+GVNMtGJ4j1hC0xJ9ZSUM2w
# bBjha7rgsjqG3iMZkLLRxeaqZMDAhBLwXXn6Xao4wJ0yA1W9F3O2FLXfjEOyaW6j
# YkzRctspNO1Lhwg6vyXlRpVByHQcpIkeIpi6MPzJ1PKrBFPn0L+qu1xog3KIbTQ5
# 47kJmxrfLTG5huoFSCTERBY1V9Cd7mUq8rHiweLuuqEjorbGTsnyNq2ITaLezrT5
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFAJlnZta3B1lqFS+1XvKFjbfJEbAMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAABThEUkCudwAUfJ
# vSWcK6gVjV4rszARFHl+2xl4e0QOwAVgm8rKZ2uP6ulsDQ3/XA1k/9vV980zluoz
# 2RoVD1e0q8nYZvUCUFVyZyKESPGKqoY5fiBmJ4FpVNUj1+8Na1SLLuNPe3/Ir6yY
# XtuRnIO27kRmOTolF/kMoWZshyQJ/ybUH+gbFgTtcmsKL5TN4teEAKQkSaG+oUzh
# RsPKf3cqwE4R5wzD5Ws7D5CJZW0Bzju7pcdm1yLin68Mj1TgDoGE+WUAdAolJxUl
# e8MvhvqbzL0Rln3TBMvVV1yYet/b+mMvmx5vRX/ncfgOI+wxUD5z+S8hx2p+HlYs
# yqNO99t4w3qKSVta7MJi9Ybcg4+Z4X9WrN1Gh5xPeuiz3leZixi1R3zNjEaR9Rie
# V/oRgPFfbqQ6rrkLD39Me/bW+n7hT4ap8Rmko6wVDyhbX2WTGjY4Un1Sf8fuDkCF
# nizuavx+8qP8mhqw6WLHdgV1XF5AoKXkX6j63KiWXirsBbMaxxl61FujW24+AkCt
# eWnxjCFdF8ZxC4OjLXvIvdaCIGK4VzD6bEPP2yzyAqWbPbTC1y6sJTPAx/MZysI6
# qivU7kvdsiQsju69gTNdohYdEx3N2wwt6SDsQvh8+1yp1NuaDGnPhkRSFDRy4642
# MDc3EsT9r8vkn6YS5hapslnEVmZJMIIG5zCCBM+gAwIBAgITMwACUy8OkAG8sTvr
# awAAAAJTLzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDQwNTA2MDQxN1oXDTI1MDQwODA2MDQx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAMTDlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0B
# AQEFAAOCAY8AMIIBigKCAYEApDL9ztepCuGvrQ+Az3uc39Dg/xRxogU5K4uFHTyE
# sHpkYagTj3v9DMlra4cxPS5NtifxD9lU64xOdcm3cDYyXsQVF7Upj3HoIcQk7vCm
# s3wrTFuoa3RA+HyD9OfQduaEkAJ6YsqDGbg2ugwy2mcNjDFYUeAXyuwUp7RtE6eb
# wrF0CCLuB2GUUVCbuxXJ+NI4D+nWKImxvmQ9ox+gEn8tzFuTLjKFqohO6qz/ZGsH
# bv4yG02uNzwkS3Ed1p5JpiKkg8B+qxZ5VKsiyN/6YRGRqLk9q+OYxaz+vR7B+6IA
# w+GVNMtGJ4j1hC0xJ9ZSUM2wbBjha7rgsjqG3iMZkLLRxeaqZMDAhBLwXXn6Xao4
# wJ0yA1W9F3O2FLXfjEOyaW6jYkzRctspNO1Lhwg6vyXlRpVByHQcpIkeIpi6MPzJ
# 1PKrBFPn0L+qu1xog3KIbTQ547kJmxrfLTG5huoFSCTERBY1V9Cd7mUq8rHiweLu
# uqEjorbGTsnyNq2ITaLezrT5AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4G
# A1UdDwEB/wQEAwIHgDA7BgNVHSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYa
# KwYBBAGCN2GBmtGaFtje9WuBvfqFXPmA7xswHQYDVR0OBBYEFAJlnZta3B1lqFS+
# 1XvKFjbfJEbAMB8GA1UdIwQYMBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1Ud
# HwRgMF4wXKBaoFiGVmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEu
# Y3JsMIGlBggrBgEFBQcBAQSBmDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDov
# L29uZW9jc3AubWljcm9zb2Z0LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGC
# N0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEM
# BQADggIBAABThEUkCudwAUfJvSWcK6gVjV4rszARFHl+2xl4e0QOwAVgm8rKZ2uP
# 6ulsDQ3/XA1k/9vV980zluoz2RoVD1e0q8nYZvUCUFVyZyKESPGKqoY5fiBmJ4Fp
# VNUj1+8Na1SLLuNPe3/Ir6yYXtuRnIO27kRmOTolF/kMoWZshyQJ/ybUH+gbFgTt
# cmsKL5TN4teEAKQkSaG+oUzhRsPKf3cqwE4R5wzD5Ws7D5CJZW0Bzju7pcdm1yLi
# n68Mj1TgDoGE+WUAdAolJxUle8MvhvqbzL0Rln3TBMvVV1yYet/b+mMvmx5vRX/n
# cfgOI+wxUD5z+S8hx2p+HlYsyqNO99t4w3qKSVta7MJi9Ybcg4+Z4X9WrN1Gh5xP
# euiz3leZixi1R3zNjEaR9RieV/oRgPFfbqQ6rrkLD39Me/bW+n7hT4ap8Rmko6wV
# DyhbX2WTGjY4Un1Sf8fuDkCFnizuavx+8qP8mhqw6WLHdgV1XF5AoKXkX6j63KiW
# XirsBbMaxxl61FujW24+AkCteWnxjCFdF8ZxC4OjLXvIvdaCIGK4VzD6bEPP2yzy
# AqWbPbTC1y6sJTPAx/MZysI6qivU7kvdsiQsju69gTNdohYdEx3N2wwt6SDsQvh8
# +1yp1NuaDGnPhkRSFDRy4642MDc3EsT9r8vkn6YS5hapslnEVmZJ
