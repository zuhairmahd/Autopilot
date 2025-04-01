function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [ValidateSet('Dev', 'Release')]
        [string]$ConfigurationType = 'Release'
    )

    #region Variables and logs
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    Write-Verbose "RootFolder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    Write-Verbose "ConfigurationType: $ConfigurationType"
    # $valuesToEdit = @(
    #     @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; type = 'string'},
    #     @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; type = 'string'},
    #     @{name = 'Name'; value = 'localhost'; description = "The name of the device to configure."; type = 'string'},
    #     @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; type = 'string'},
    #     @{name = 'AssignedUser'; value = ''; description = "the user to assign the autopilot device to."; type = 'string'},
    #     @{name = 'check'; value = @('true','false'); description = "Check the status of the device."; type = 'array'},
    #     @{name = 'NoModuleCheck'; value = @('true','false'); description = 'skip checking for installed powershell modules.'; type = 'array'},
    #     @{name = 'NoUpdateCheck'; value = @('true','false'); description = 'skip checking for updates.'; type = 'array'},
    #     @{name = 'UpdateOnly'; value = @('true','false'); description = 'Only check for updates and exit.'; type = 'static'},
    #     @{name = @('true','false'); value = 'false'; description = 'skip checking for admin rights.'; type = 'array'},
    #     @{name = 'NoSignatureVerify'; value = @('true','false'); description = 'skip verifying the signature of the script.'; type = 'array'},
    #     @{name = 'NoHashVerify'; value = @('true','false'); description = 'skip verifying the hash of the script.'; type = 'array'},
    #     @{name = 'GetDeviceHash'; value = @('true','false'); description = 'Gets the hash of the device and exit.'; type = 'array'},
    #     @{name = 'Redeploy'; value = @('true','false'); description = 'Check the deployment status of the device.'; type = 'array'},
    #     @{name = 'SerialNumber'; value = ''; description = 'The serial number of the device to check.'; type = 'string'},
    #     @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; type = 'array'}, 
    #     @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; type = 'array'}
    # )
    $valuesToEdit = Get-Content -Path $InitFile -Raw | ConvertFrom-Json
    $success = $false
    $configData = @()
    #endregion
    
    # Load parameters from the configuration file if it exists
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Host " Loading configuration values from $ConfigurationFile."
        $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
        Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    }
    else
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating new $ConfigurationType configuration file."
        foreach ($config in $valuesToEdit.PSObject.Properties)
        {
            if ($ConfigurationType -eq 'Release')            
            {
                Write-Verbose "Creating release configuration: $($config.Name) = $($config.relValue)"
                $config.name += $config.relValue
            }   
            elseif ($ConfigurationType -eq 'Dev')
            {
                Write-Verbose "Creating dev configuration: $($config.Name) = $($config.devValue)"
                $config.name += $config.devValue
            }
            else
            {
                Write-Host "Invalid configuration type. Please use 'Release' or 'Dev'."
                return $success
            }
        }
        Write-Host "Processed $($configData.PSObject.Properties.Name.count) configurations."
        Write-Host "Writing configuration file to $ConfigurationFile."
        $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
        Write-Host "Configuration file written to $ConfigurationFile."
        $success = $true
        return $success
    }
    
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            $configType = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).type
            $configDescription = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).description
            $configValue = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).value
            if ($configValue -eq '')
            {
                Write-Verbose "Config value is empty."
                Write-Verbose "Setting config value to 'none'."
                $configValue = 'none'
            }
            Write-Verbose "Key name: $($config.Name)"
            Write-Verbose "Key value: $($config.Value)"
            Write-Verbose "Found Key value: $configValue"
            Write-Verbose "Key description: $configDescription"
            Write-Verbose "Key type: $configType"
            switch ($configType)
            {
                'string'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Description: $($configDescription)"
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($configValue)"
                    if ($value -eq '' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "New value: $value"
                    Write-Verbose "Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                # 'bool'
                # {
                # Write-Host "Please enter a new value for $($config.Name)."
                # Write-Host "Press enter to keep the current value: $($config.Value)"
                # Write-Host "Description: $($configDescription)"
                # $choices = @(
                # @{number = 1; choice ='true' },
                # @{number = 2; choice = 'false' }
                # )
                # ForEach ($choice in $choices) 
                # { 
                # Write-Host "[$($choice.number)] $($choice.choice)"
                # if ($choice.choice -eq $config.Value)
                # {
                # Write-Verbose "There is a match"
                # $currentlySelected = $choice.number
                # }
                # }                        
                # $value =  Read-Host -Prompt "Choice: [$currentlySelected])"
                # while ($value -ne '1' -and $value -ne '2' -and $value -ne '')
                # {
                # Write-Host "Invalid choice."
                # [console]::beep(500,300)
                # $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                # }
                # if ($value -eq '')
                # {
                # $value = [bool]$config.Value
                # }
                # else 
                # {
                # $value = $choices | Where-Object { $_.number -eq [int]$value } | Select-Object -ExpandProperty choice
                # }
                # Write-Host "Value: $value"
                # Write-Verbose "Changing the value of $($config.Name) from $($config.Value) to $value"
                # $config.Value = [bool]$value
                # }
                'array'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $config.Value"
                    Write-Host "Description: $($configDescription)"
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item) + 1
                            Write-Verbose "The currently selected value is $currentlySelected"
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500, 300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else
                    {
                        $value = $configValue[$value - 1]
                    }
                    Write-Host "Value: $value"
                    Write-Verbose "Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'static'
                {
                    Write-Verbose "This is a static value and cannot be changed."
                    Write-Host "Value: $($config.Value)"
                }
            }
        }
    } # Closing brace for foreach loop
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "$($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    Write-Verbose "Configuration saved to $ConfigurationFile."
    Write-Verbose "Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "Failed to save configuration to $ConfigurationFile."
    }
    return $success
}


# SIG # Begin signature block
# MII94wYJKoZIhvcNAQcCoII91DCCPdACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD9+i6aR9CN4SUO
# q1ZA5kdJ3uMjGj0TEekEIc/RJbsPCKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAMwiSm5
# JQcTXGjPAAAAAzCJMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwMzMxMDYyNjA3WhcNMjUwNDAz
# MDYyNjA3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# i14gNZy/sT3fYJJzMCN7C9/TX3YHQxU7dSwnaPS2CWmMkybauhjPTjDuMpBcPdm4
# g4mPYQFMbjC5uaq1ANrzag23w/+WNGkBQRafE6XRRJN+yOYMKEmyP9sgp+OgUiaG
# u/BsouRNdfEEVlTCnwUxJVYd3JuEvReGSJigG8xmeQ6uuE4od7tK8Z0yHQFIaMxC
# PXgo81UNDa0J3G7z078nKNo1OGnhv4WeZ0zsiglup6wrHbLYyBchXX3r9E6JC5CT
# lpfgUhUV/nYee/By8tr6jWIPxYAFCfyyqGnD6PPMLxBrxHqx1mVM29oApS6W8OMA
# ohi/1Y2pBoHj5OaDxbzP7UBSskhl3sgRz58MR+d1KPHq8IGaHBPmXP9EZ11OFNj8
# CsqUd8WHXlShI7DpIKjH6OVstPFQ8dA+IhPZSRmP6vaexI3TOLhr6IXYF3bn92fQ
# +teENcuU+EH9Oh5HeMF/xDm6f73NNy1G5LKJlLdMwEmhc15T1z/5e2+YlSM/cA4X
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFBmZUMrU4kFYDzj6Kep0z44PEsh2MB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAM/9sY8evLOZVg8v
# pr2VdRz5SdcURd6SPz1zf5hcfF8h6VOn3buIbUWs8J+qLh+27MfGk9558Lisye2C
# h6+iS/Y76MeLXg9RBCV2zEEiWzRI9ac2yhC6gBaRkqXXr3/Kbt1hMPw2t+O5R96o
# 8BoFlaLlsrZjKPwoedTRQMO7b5zMw7BqUzUDLxNCgAipqQMH3feXb/VrTKA8N2Wn
# bkSlYe1s08U+Z8xpFlzsCdBcViijkPwK+A3VzO8Nk4GSlF5d441oCviaZra0YcfT
# e7G1zfdCAtPHBfXRwGx5gf9C7lV6G+czGFPjZgwcT4NCPWPbwEkdCZ5TDTNneqep
# UFsofMVldNxEzAR8/3vLs8GahoLYsrM0+ulwcifa+7UiziJWs+4WuwGoS7PNlJhZ
# P21IUFEG4cl+H2S+CVzhIV8l477HzrvFXpiIwsx/kGHKNcnWMhU6iFhfnxwBudB1
# IQvvAAv2CTABhEE9Tu/8q8myulAlqdkHjthqYKzNZGpouA3YWRtw9dmxmJcX/Aeu
# pRZ7gGIAKQZlY+hbb41um2vjUriI2mQLBS/vcu71B7Dl976EXO5Xw9GNHkdw7ZrN
# RyrnNdKJqjVUyB3aPXbDAu8Xiewaif5JB2hVN8dx6ozzj7JEXjd2RzM3g1lnEF+A
# nwkdaUsob7n1frAzwgvmmafMoNcfMIIG5zCCBM+gAwIBAgITMwADMIkpuSUHE1xo
# zwAAAAMwiTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDMzMTA2MjYwN1oXDTI1MDQwMzA2MjYw
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIteIDWc
# v7E932CSczAjewvf0192B0MVO3UsJ2j0tglpjJMm2roYz04w7jKQXD3ZuIOJj2EB
# TG4wubmqtQDa82oNt8P/ljRpAUEWnxOl0USTfsjmDChJsj/bIKfjoFImhrvwbKLk
# TXXxBFZUwp8FMSVWHdybhL0XhkiYoBvMZnkOrrhOKHe7SvGdMh0BSGjMQj14KPNV
# DQ2tCdxu89O/JyjaNThp4b+FnmdM7IoJbqesKx2y2MgXIV196/ROiQuQk5aX4FIV
# Ff52HnvwcvLa+o1iD8WABQn8sqhpw+jzzC8Qa8R6sdZlTNvaAKUulvDjAKIYv9WN
# qQaB4+Tmg8W8z+1AUrJIZd7IEc+fDEfndSjx6vCBmhwT5lz/RGddThTY/ArKlHfF
# h15UoSOw6SCox+jlbLTxUPHQPiIT2UkZj+r2nsSN0zi4a+iF2Bd25/dn0PrXhDXL
# lPhB/ToeR3jBf8Q5un+9zTctRuSyiZS3TMBJoXNeU9c/+XtvmJUjP3AOFwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQZmVDK1OJBWA84+inqdM+ODxLIdjAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQDP/bGPHryzmVYPL6a9lXUc
# +UnXFEXekj89c3+YXHxfIelTp927iG1FrPCfqi4ftuzHxpPeefC4rMntgoevokv2
# O+jHi14PUQQldsxBIls0SPWnNsoQuoAWkZKl169/ym7dYTD8NrfjuUfeqPAaBZWi
# 5bK2Yyj8KHnU0UDDu2+czMOwalM1Ay8TQoAIqakDB933l2/1a0ygPDdlp25EpWHt
# bNPFPmfMaRZc7AnQXFYoo5D8CvgN1czvDZOBkpReXeONaAr4mma2tGHH03uxtc33
# QgLTxwX10cBseYH/Qu5VehvnMxhT42YMHE+DQj1j28BJHQmeUw0zZ3qnqVBbKHzF
# ZXTcRMwEfP97y7PBmoaC2LKzNPrpcHIn2vu1Is4iVrPuFrsBqEuzzZSYWT9tSFBR
# BuHJfh9kvglc4SFfJeO+x867xV6YiMLMf5BhyjXJ1jIVOohYX58cAbnQdSEL7wAL
# 9gkwAYRBPU7v/KvJsrpQJanZB47YamCszWRqaLgN2FkbcPXZsZiXF/wHrqUWe4Bi
# ACkGZWPoW2+Nbptr41K4iNpkCwUv73Lu9Qew5fe+hFzuV8PRjR5HcO2azUcq5zXS
# iao1VMgd2j12wwLvF4nsGon+SQdoVTfHceqM84+yRF43dkczN4NZZxBfgJ8JHWlL
# KG+59X6wM8IL5pmnzKDXHzCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpMwghqPAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADMIkpuSUHE1xozwAAAAMwiTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBMqVdVlNtjHMBVlCKslfOOsqi3
# 7LQ8JPa9rHrEwQ7QoDANBgkqhkiG9w0BAQEFAASCAYAPJqI3rn++LSTD5pxHzEoM
# 12YoXcW8tG//r+zy/aDKz46gDAD4eGqGYAEop+w8O5tKXxn6PnXXUM3HaF20TlEE
# AfsWsS5u9j9N5nZlRCyBWEtuBjtL9gjctDbXBfdSAyu3HI+WYOfeQkJ5il05xSHX
# TGKqgGL6Yuqe158hrUI15909k5ubdeulSBR3vUXGpMIuVt/w+C8cnWNbLmffUJBv
# EzhcoNvtqU4hgN8RUx4A7EeML9iUrUa21F+8lGjnaJEEjN01vvdHxh5ohg6n2Ex4
# rXMFS4SSR6+RwiUAxpX9riXDviW/3bbge9oq/fAIKVrDPQxgOPAVYd9lxDOZa6/6
# f7toYK4z6h/SMYOdgvhWJieDwM9AW2Ow+NkfmSz3PfJrP7i9aHpSR+UKQz5e6Dpg
# uMDMvZ8NbK65Lcgnl6zJyzinwqkxPzJcQcN3rZe/zZISzHOS5JACGUo1Ru/eDxBz
# h+HNiV7o4a0dFhp3Y3LkTEUWBEbg/UUdI01i7aQUdfehghgTMIIYDwYKKwYBBAGC
# NwMDATGCF/8wghf7BgkqhkiG9w0BBwKgghfsMIIX6AIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgnsmPHsGv4ilu8Ob/xgPCy/H+gUHqW2VzT5/c6zce
# FX0CBmfnoI8GiBgSMjAyNTAzMzExNzM5MjYuMzNaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046QTUwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
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
# EzMAAABIVXdyHnSSt/cAAAAAAEgwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODUyWhcNMjUxMTE5MTg0ODUyWjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkE1MDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMt+gPdn75JVMhgk
# WcWc+tWUy9oliU9OuicMd7RW6IcA2cIpMiryomTjB5n5x/X68gntx2X7+DDcBpGA
# BBP+INTq8s3pB8WDVgA7pxHu+ijbLhAMk+C4aMqka043EaP185q8CQNMfiBpMme4
# r2aG8jNSojtMQNXsmgrpLLSRixVxZunaYXhEngWWKoSbvRg1LAuOcqfmpghkmhBg
# qD1lZjNhpuCv1yUeyOVm0V6mxNifaGuKby9p4713KZ+TumZetBfY7zlRCXyToArY
# HwopBW402cFrfsQBZ/HGqU73tY6+TNug1lhYdYU6VLdqSW9Jr7vjY9JUjISCtoKC
# SogxmRW7MX7lCe7JV6Rdpn+HP7e6ObKvGyddRdtdiZCLp6dPtyiZYalN9GjZZm36
# 0TO+GXjpiZD0gZER+f5lEFavwIcD7HarW6qD0ZN81S+RDgfEtJ67h6oMUqP1WIiF
# C75if8gaK1aO5+Z8EqnaeKALgUVptF7i9KGsDvEm2ts4WYneMAhG2+7Z25+IjtW4
# ZAI83ZtdGOJp9sFd68S6EDf33wQLPi7CcZ9IUXW74tLvINktvw3PFee6I3hs/9fD
# cCMoEIav+WeZImILCgwRGFcLItvwpSEA7NcXToRk3TGfC53YD3g5NDujrqhduKLb
# VnorGOdIZXVeLMk0Jr4/XIUQGpUpAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUpr13
# 9LrrfUoZ97y6Zho7Nzwc90cwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQBNrYvgHjRMA0wxiAI1dPL5y4pO
# MPM1nd0An5Lg9sAp/vwUHBDv2FiKGpn+oiDoZa3+NDkYCwFKkFgo1k4y1QwCs1B8
# iVnjbLa3KUA//EEZDrDCa7S4GZfODpbdOiZNnnpuH3SWLtk7gFuKIKDYICSm+1O+
# uBi7sVu+9OpMi/8u9dBoInH6zG8k+xsgDJZRJ8hhN0BaVWjrewnwCQfmnOmJ++Qv
# JeYvGraNPLBp4P+kprMQnBcBvLz67TigIZUJkNsP6wM4nvneFuXpfJY5eYKldW+P
# bA+hcl0j5PoM+1z0Za0zFINQpm1UlXZRWAAJrPHyA4OJ2PqHdobA6vxS38Ww79fz
# ndDUJil8dZ9bckSQtzcWyUp/YqXbMfXgQGgt5SlPKSGfw1lR5eEey64qM/HyZQAt
# b8uCVSNlfInfIFDU+I56+nFOi3xp9dzquWr0UnaSC0zqKPa5bt/1q3nIhx3AUz1V
# SbRoKCJe+O9GRB5JQggCbjQtfaq97aR0+A179m3zJvnMNywmMeFk+1eJbdOcFRgu
# oKwucPp9WHpflC8Vu2MuUEgy3deW8BCe5UTOGjK3eKzDD3Dy36gYKDho2H3gh0q9
# Q1LV9/EL5D5euxPfAOVKWo1It+ijGGwK7mBcq3Ol+HHz7iX2tUcnGBkT2fAYqIBv
# A1fEoUHdtWCbCh0ltTGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABIVXdyHnSSt/cAAAAA
# AEgwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDMzMTE3Mzky
# NlowLwYJKoZIhvcNAQkEMSIEIP8pCZztQ1OPWkLwbdKwgEw5Ee7XHlJLN5l3hZN9
# 1YfjMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg6ioBV5tPCNafQ/SAvBnT
# dh+NfdC8O0dkSXfybyLzHUEwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABIVXdyHnSSt/cAAAAAAEgw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOkE1MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# 5hJ9QZRXOOnEOHn3+omINFlowyegZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# lMIJMCIYDzIwMjUwMzMxMDcyNjAxWhgPMjAyNTA0MDEwNzI2MDFaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOuUwgkCAQAwCgIBAAICAr8CAf8wBwIBAAICEoswCgIF
# AOuWE4kCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAnTyqCz3IrtPh3eHJ
# yV9Hs1rNIGwin/yxu2NDg9igbbIsmH3Sa1xchdn6BVTRCtoEDx0LONO9rcqp3m7X
# aJuE7K7IaOeo9g0rUZ2Oi47sx7NGI72zj+2wVurFK09TrQvbRlOeKFxOI+N4sK6t
# PQZOWvvEX9A1/3iR6gZ4p6fIM46jIblLLU5ZNd5AO3m9PUYEBjj5209dShY/xRdV
# BDUJo/4oDBu+oDwfiZAKCxPrSJZ0o3XjbYZuGtTfIX3pemnH/SeH/WYStJK9gjl4
# pbfAYm/RWwitSR789Wd0392ABYrfKQm2xbdn3woEs8D+abOCKequ0dLgo3sEWIUn
# cGEQEjANBgkqhkiG9w0BAQEFAASCAgAcVIY1HS+pOYwtyL/uBSC2GdSHCs3t1pDC
# Fl/jJDd/LvM3tELhKd3EqJa15N9IJzCqrT5xathituV1YflaNGscwn9niBpIQYZS
# cCecFpACQfTnLgYgsJuWLlm1H1j+AC2l08nu2sJ3cxneLAGvjzXB1L/r6NM7ZIvV
# C9Q4AJzmP75IUKgci1K2GwEBttwnT1qpuLLQPJ2EFIQ6CTEi2bY8q+Y06wOL5M1/
# /1ZUV/qk8zZNh4R8NI2YhFP2IcsrpTvMmVY8VOFAQU+UiyvuJCSXvVcpfTuYM5T5
# 5qKNtTZD2TJJPikRucCJcztb2RXj8V5VUnS0acJFgRMxzxtOyvKcYrZnpMWeq/3s
# QOpEjSTaqUhQBZvY/F6z4kdXW/QYC4UOtmnVqPqzFM50E6VSCBTuplWW71VZwK0S
# 39dOzIm15YA8/FpsqwATZ07xKqaOwbe/AS1Yn1gikPKAZTSGG3cjZL8VWqWIkgpQ
# X+S5Ux0Hp6TEoccfZ3ABjFNIhCJdPw5qozWuJsvW2VNW0NJqm30EzdS7Ih7Hkfjm
# m1+657sIGvwrFEwInS1BFmvQKsdThDrBVgGebvPwyWfYmlA1uQo5zQgHymjlAFyc
# u3MfJuQLFR6HLz8EGNikuQVA/1NQEwoWQ30udzMlQRvsyYoDsJO2Ts1tqCs+HGB1
# 47IL1JYZYw==
# SIG # End signature block
