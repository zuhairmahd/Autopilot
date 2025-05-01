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
        [int]$waitTimeInSeconds = $waitTimeInSeconds,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$maxWaitTime = $maxWaitTime
    )
    
    #region variables and logs
    Write-Verbose "Received parameters: serialNumber=$serialNumber."
    if ($AccessToken)
    {
        Write-Verbose "Access token provided."
    }
    Write-Verbose "WaitForAssignment switch: $WaitForAssignment."
    if ($WaitForAssignment)
    {
        Write-Verbose "Wait time in seconds: $waitTimeInSeconds."
        Write-Verbose "Max wait time: $maxWaitTime."
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $assignment = $null
    #endregion
    
    Write-Verbose "Checking whether the device with serial number $serialNumber is already in Intune."
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "VMware device detected."
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -ne '' -and $null -ne $autoPilotVMDevice)
        {
            Write-Verbose "Got an Autopilot Device with device id $($autoPilotVMDevice)"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUriWithId).value
        }
        else
        {
            Write-Verbose "No match for device with serial number $serialNumber found in Autopilot."
            Write-Host "Treating as a regular device..."
            $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
        }
    }
    else
    {
        Write-Verbose "Not a VMWare device. Continuing"
        $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
    }
    Write-Verbose "Found $($assignment.count) Autopilot devices."
    Write-Verbose "Assignment: $($assignment | ConvertTo-Json -Depth 10)"
    if ($null -ne $assignment -and $assignment -ne '')
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
                Write-Host "Pass $index of $maxWaitTime"
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
# MII94wYJKoZIhvcNAQcCoII91DCCPdACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCrmwkKeChmlhj/
# Raq/SD4ZfVMz5f1AgzVDoQ5kX9165KCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAKui2AU
# rM0VqBZ/AAAAAq6LMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwNTAxMDQwNjUxWhcNMjUwNTA0
# MDQwNjUxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# jyaICLI9BqDMk/l9QxgoJCRj/CBTla7ZHRfYlZOu9EMU7znqu/DtlhUwIhD2R24t
# gn6YJe4gMdJ+U/oAgXq07EHJvRWqtorzi3vv1G9p6Nv6uwPeZH/lJ9LjDThCp6VJ
# 5c+MnVrNGKSbsFVZWKnhn9S5JHh5hoWtVeTO0YfyBQb4wWQbHXrKm6a+cMMV4LjQ
# Y6+Orxojeuer6sqSpilOMZLJwRo3dAWU7ntmqW/XBI4Z44PDctw8uAV7/1TRP/6I
# TIdZpJbaM4EHAK1/N4BFu911CBgfuEiNbXYVFULxdciEG0RVbrGCMMD17DqZYrXx
# fNjg9/dwaS6WKv1E1DlLMr2B8I6it+kjWo2Ki0DCc3RcvifOztctF+JSvCWK7fPV
# 4vmH981lq7tclIyn8w/RVPVUJ2OQutqVUusmOWKZEq4wI8qpzZJYjsLALkhFvOoa
# MEWadOCLhttrHcq4RDNpc1q01FGRK3uMCSad/UcI+GydyyTacOOXe+qqrHCzX3zF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFGh2SUupHiUlJGlCyXw5l1YS+MJ1MB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAHTHgapcBsF07MeD
# z2VBsQ8CkdrDo1A47+jAO9bpp/L2vcamTzHyOlVv+i9Sv4p8rPDjfLpRPRM5/2zd
# tHjD8ZWFFNOPMcmK9V2RLUWgkpXI8t12QlBVYEZZR5vbwLTrVC3HQcBrJNb0lN9B
# j492zCI7vklcCbkeLMIHKleDfoewWnzib3UDNoYy8l+6uk0ytB0idKmzjzMN8GIs
# pcuNgJU9ZtgYa36/dGatLUlaa1RQQBUQGlHCsoB7jh45B3qnHdrAhav6u1H62ut7
# YzGkBESe0qM1YMblb6zhe1gfor3e1nRVqaa4mo4J7f9LiEyLEvkw41IMWXUbRxUE
# JIeLOxgeUwXY6tiose3Az5grExQfP7Ny1f72AAbYLT9HpVWAV0JytdksTAZaBjAX
# cQb060G6z4vNlb7nG3y/trDI49jd+Z6d6j2XTVGGZBRhlgDRfWDG1tk7wj/nlz+L
# 05pUTGp+HrxXIpmB6ewIlh1di6Rb5T0JyksoZDXeZ00DQv1e+glujOSuodjv/m1e
# eQWC4eY+jtv8CDT9pI/vezJWEm7g07hqMz0rCBm3L725xfq+D1OEcUWzP9tCCv61
# kboZbqaLVXinzws19yBm1s3lSIxf0nIzqfQqHfJPUnbtlDxOlTVX2GQfjLs6B3jc
# YQEo+cDYX0lzrVMtYd05DcE0xvPNMIIG5zCCBM+gAwIBAgITMwACrotgFKzNFagW
# fwAAAAKuizANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDUwMTA0MDY1MVoXDTI1MDUwNDA0MDY1
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAI8miAiy
# PQagzJP5fUMYKCQkY/wgU5Wu2R0X2JWTrvRDFO856rvw7ZYVMCIQ9kduLYJ+mCXu
# IDHSflP6AIF6tOxByb0VqraK84t779Rvaejb+rsD3mR/5SfS4w04QqelSeXPjJ1a
# zRikm7BVWVip4Z/UuSR4eYaFrVXkztGH8gUG+MFkGx16ypumvnDDFeC40GOvjq8a
# I3rnq+rKkqYpTjGSycEaN3QFlO57Zqlv1wSOGeODw3LcPLgFe/9U0T/+iEyHWaSW
# 2jOBBwCtfzeARbvddQgYH7hIjW12FRVC8XXIhBtEVW6xgjDA9ew6mWK18XzY4Pf3
# cGkulir9RNQ5SzK9gfCOorfpI1qNiotAwnN0XL4nzs7XLRfiUrwliu3z1eL5h/fN
# Zau7XJSMp/MP0VT1VCdjkLralVLrJjlimRKuMCPKqc2SWI7CwC5IRbzqGjBFmnTg
# i4bbax3KuEQzaXNatNRRkSt7jAkmnf1HCPhsncsk2nDjl3vqqqxws198xQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRodklLqR4lJSRpQsl8OZdWEvjCdTAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQB0x4GqXAbBdOzHg89lQbEP
# ApHaw6NQOO/owDvW6afy9r3Gpk8x8jpVb/ovUr+KfKzw43y6UT0TOf9s3bR4w/GV
# hRTTjzHJivVdkS1FoJKVyPLddkJQVWBGWUeb28C061Qtx0HAayTW9JTfQY+Pdswi
# O75JXAm5HizCBypXg36HsFp84m91AzaGMvJfurpNMrQdInSps48zDfBiLKXLjYCV
# PWbYGGt+v3RmrS1JWmtUUEAVEBpRwrKAe44eOQd6px3awIWr+rtR+trre2MxpARE
# ntKjNWDG5W+s4XtYH6K93tZ0VammuJqOCe3/S4hMixL5MONSDFl1G0cVBCSHizsY
# HlMF2OrYqLHtwM+YKxMUHz+zctX+9gAG2C0/R6VVgFdCcrXZLEwGWgYwF3EG9OtB
# us+LzZW+5xt8v7awyOPY3fmeneo9l01RhmQUYZYA0X1gxtbZO8I/55c/i9OaVExq
# fh68VyKZgensCJYdXYukW+U9CcpLKGQ13mdNA0L9XvoJbozkrqHY7/5tXnkFguHm
# Po7b/Ag0/aSP73syVhJu4NO4ajM9KwgZty+9ucX6vg9ThHFFsz/bQgr+tZG6GW6m
# i1V4p88LNfcgZtbN5UiMX9JyM6n0Kh3yT1J27ZQ8TpU1V9hkH4y7Ogd43GEBKPnA
# 2F9Jc61TLWHdOQ3BNMbzzTCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpMwghqPAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACrotgFKzNFagWfwAAAAKuizAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCOueTwPX90TxaiB1PWUOaIaCQG
# 5EwHb7GBIlF54tkDQTANBgkqhkiG9w0BAQEFAASCAYBFFd2FXjjBCChOhSMU/C71
# BA0AxV7thAp0UKx78brjNyeh/X158qUFDeH/pyanFux/KCBVmCllQs7+wwI3+m/7
# GcZCg28ljztaZh2wxsqErxx/i2D44t3XqMEm5xDws7cngBite4htLGyDirKj7wYm
# ym79105khyqoVw5kplLjFP/Fv6I4ypN0IsciBikUc9MC1eq516DMG4vsWyd9R3sh
# iAir48pqPrhAigFSfalV2xAHH/TOADrKdzjfHgAjI9AyNtZvlmETezBYclju0VuP
# xAo7+lIKLaMqVkgEF+fMFRU3jlKa/Lp+pwbuPedWc3WOTcwdI3ZOJweQOanGSEpj
# JOTfCOMvcg3oERjWkqtbEq6QD4Hpv0nqtlM1ejpHIEK11vgiBG3z29NLynLtnCIc
# f60FTvJoHcckDWa2nAFfdc/gyA5KAOVkk1daTgYxC+mBmSFB9ocdGbNSLNfie/+7
# ob/nH098Sm8sX4IxV57EC0MEMC2EvZBQaFkYpyeYqRShghgTMIIYDwYKKwYBBAGC
# NwMDATGCF/8wghf7BgkqhkiG9w0BBwKgghfsMIIX6AIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg+164j7R00ZfKXUoD+TqlDNHzbGy+3fXI5ic0DCsC
# RFACBmgSvDMP0hgSMjAyNTA1MDExNzU0MzMuNzZaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046N0EwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
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
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABH45ULN6Fg3ccAAAAAAEcwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODUwWhcNMjUxMTE5MTg0ODUwWjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOhwum733P/414hm
# ZHfYYmDZVP+N33qlguy82eB4fipfArWpWYVpdeSRVvFvV85Aky6RiRtrdYRzr1b9
# ngGzMC7GC5OENWVj2yThliQYyDGirVnmKdQ++PhCHzFW+WGIBLo5/+4vAOxuwqWD
# Z8ama/O2I9I4v0/XmTTQjhuyXW+WZFK63a03AlDmxemhPsYj/ZPYDQadZsUQIpEL
# IZb2uyfL2jQs0hSXg1gB3hrAZKzo4jMo+kgrUl8r3TBce9pfAYlw30/xA9Ekgcq4
# WhUbMhQb8LSNALitDrbJMa9zaxngDFNDB+V9UEFqIeryCf9gMelmKV4aQHYhBrNk
# SIRzk6vld6v2ZQNT7YUR7rrDx7ZaQtdqerFoPn5lyj4T5B3BxNgajvyMXE8O82tp
# OvlACAhNzh1j88ELdxgXNyAPJTHbE5UIG+BpuonGPuteuPgGF3ZL9lNg5UeGLxwN
# YFp58zwmCI7wYIghG+U1aeDwUoW3T1l83GaxJ0ImVbDes0DCwFjXGnymaa/2vYz2
# s0hGRn6yHTF3ca4BJazZs6uoGLRpPOBj1vcLFj7+b5FT5ROKbkmSakkz8Ag/rz9L
# 7U3AWpcrnLFMkEgieGgSB0QeL5rYlHZKVXcCSklrT8HqxlqgRr7OCyEh8VrrpcGa
# eezJ1Xi4btbUg2ho1XDEEoN2ao1HAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQU5FR2
# WCA6Pu9PubZe8WFIRbyG3WgwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQANIlRD1dqYOHSCQLVe+uFXPoAz
# AZUq4okD62SUnMFrhRVg/dj2vVEtTTxFgkiM8SSnCLANaK0rnyCxnHA2Hg1zh8WJ
# CtlQln0Eid+eh2/xY47zfNjxhB0kxymAHN5hVeI0J526aoUpePSYwy5ZoHKe/vDC
# fsWccnDMuu7iO3hUt55/4HJydjA+gxrvksX/3Fmj/RMnfvWq0Fh1uxx4qY2FBRMP
# a8i+8+QdM8f80DYiQuxDUCbnWfOHnZYQPNEKhd6V3r78oKWd+wQHX+99Hqlg/HBl
# O9Nnu6HvLwPqDiEOkRyMix6zvnhbZpGnFM+u7qf7PYTOS8cXvQH+DmgCh2ZVNQFv
# 6nGm7vtQebROtpWh2N9ckk2z6HVGOcK70yKS7YqE+akGuxKd7fXLeBey2bm9y2nW
# 0WjH1qZNa+EhXzyXUQgLfJf4E31wYq0vrlESX/LzKprY8hbaLXwkxEivhPuWId9f
# QDqx0+yXsa50vIRUcBaxbw0VXO3+93JGHMxSmzGE8vWoZCAPjlD7duBOV6XkxaVa
# Bgb5v4stRdHm6LJtsizCc5FNT+MPJw0DHy7hzn7Xix6fn9+apytBrfXqXtapxDqs
# 5yjEMXKbuTZFW4SFk1Dhc1cIojuRvw8ytG0xuhtXSavJ3RSVtBRs+wm432dQTYAO
# aCc7dtAbIRG+ml50ITGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAA
# AEcwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDUwMTE3NTQz
# M1owLwYJKoZIhvcNAQkEMSIEIJ8MwZVTpk8WxoedTypUCnO2FsFW7sYMfFepHVvD
# t3wvMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQgk2bzlnKFAAYZ71A+F3f7
# G+YwoK9+MeF/y2XqZEgKzKcwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAAAEcw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# IAXT2b4gvIw3J1lPs/eU4s1UXN2gZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# veN3MCIYDzIwMjUwNTAxMTIxMTM1WhgPMjAyNTA1MDIxMjExMzVaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOu943cCAQAwCgIBAAICErkCAf8wBwIBAAICErMwCgIF
# AOu/NPcCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAz+yTHGsO+SbqiUTB
# 4nmmjfv0ZG0xLRDQgaMxYWXgRJMIw6+2GM1JE1WCUp9LiszmnzM85rurlF+vW9nf
# NC1aOywXX6vZGy12T91rRCUHVnfqfxp0hwU6HmdZ6DkiqSv9MVgMGnDXi2j8Gatx
# 0GYRfAnsM0rdU0zRqMG2Wq1AOPEKF/dMoEGcatlGluILxf9AwrcQQ7i2WWSwxVeW
# dbPCJjaY7HxG9kMQIWl/21B6g4WiDKzl3aLmsywqrrrQ/00SZRStRyjxsOeJQveK
# 7o0EcdlbeeLiLV3bQN0Z9SUw+fIU+alG1vIEFUNe7N/JwK+EjP4OwwCgDjW99nDP
# pJN2fjANBgkqhkiG9w0BAQEFAASCAgB0y1bvXQFyNaAWBM8zCdl5GlgNBufFFJl3
# 0XnSaUFbrDLleUzepE+e97X27ekNOaVoM8ukmsfz4oc5GtmEGzemgFwkM0Q1Zhxq
# y4+PTAGqwamrs8AtmwzUK5MtlrB6mQC74D2G2+9tlfuk+XdBbyesdIFNcVX8YcO/
# yi0zVX9VvZze9MP6I7bUe0vUitTfm+Y/Fc5b1hp0zhQq4xDEEwUBNdHJq1WRc0YX
# JpljneOSbqNrbOhhUi7EEYoODgb1xZZXY9+1NCWixP8zwTbcEM/ocTvl4uYrFduP
# MkZyEsfeL6Kt88kys1VPBJOY2fTmSNwuBcukg15nX41nm8evVg4H0z92rHt4OcPF
# s3StoJzkV7FvaYM0buwVtaW/+cph2tdssb94dlzjN05V0jUfW7azPKQLF7VM+S9o
# hq5OtyQXhjetFOqmOxpfYhSVf/q6dAPzew0+2ZYRnHSkeSEh7yH47PLl/LsurygR
# Q60Ef3yoCVGqENh61ASvALIxmtgJ3/uVsC7DluLoMPjcgwmf/U7PslX6yZAG8tDj
# 8UOCNbvkvk1JGDoneQMn6Z8UewxMuUrvFD8y8sZNe95jSM1Iq7emT3fLOT4ouzI2
# EXZ/8J+ti1c3Zk5q4ifUGfpYCcvZD6C8k+z+mqhXm3hr9Z7wKx49Poab3Ktnze5n
# 1sqafAuosQ==
# SIG # End signature block
