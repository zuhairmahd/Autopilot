function DisplayReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$report,
        [string[]]$PrefixList,
        [parameter(ParameterSetName = 'export')]
        [switch]$Export,
        [parameter(ParameterSetName = 'export')]
        [string]$OutputFile = "$pwd\DeviceReport.csv",
        [parameter(ParameterSetName = 'export')]
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportFormat = "HTML"
    )
    
    #region write verbose log of received parameters
    Write-Verbose "Export: $Export"
    Write-Verbose "ExportFormat: $ExportFormat"
    Write-Verbose "OutputFile: $OutputFile"
    Write-Verbose "Prefix list: $PrefixList"
    #endregion write verbose log of received parameters
    
    #region Format property names and display report
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($key in $output.Keys)
    {
        # Format the property name to be more readable
        $readableKey = $key
        # Handle common prefixes separately
        $matchedPrefix = $null
        foreach ($prefix in $PrefixList)
        {
            if ($key -match "^($prefix)(.+)$")
            {
                $matchedPrefix = $prefix
                break
            }
        }
        if ($matchedPrefix) 
        {
            $prefix = $matches[1]
            $remainder = $matches[2]
            # Insert spaces before capital letters in the remainder
            $formattedRemainder = [regex]::Replace($remainder, '(?<=[a-z])(?=[A-Z])', ' ')
            $readableKey = "$prefix $formattedRemainder"
        }
        else
        {
            # Insert spaces before capital letters
            $readableKey = [regex]::Replace($key, '(?<=[a-z])(?=[A-Z])', ' ')
        }
        #if the value is a date, pipe it to the FormatDateWithTimeZone function.
        if ($output[$key] -is [DateTime])
        {
            $formattedOutput[$readableKey] = FormatDateWithTimeZone -DateTime $output[$key]
        }
        else
        {
            $formattedOutput[$readableKey] = $output[$key]
        }
        # Print each property and value
        Write-Host "$readableKey`: $($output[$key])"
    }
    #endregion Format property names and display report
    
    #region export
    if (-not $Export)    
    {
        $choice = DisplayNumericMenu -Choices ('Export to HTML', 'Export to CSV') -Banner "Would you like to export the report?" -Prompt "Please select an option" -ErrorMessage "Invalid selection. Please try again."
        if ($choice -eq 'Export to HTML')
        {
            $Export = $true
            $ExportFormat = "HTML"
        }
        elseif ($choice -eq 'Export to CSV')
        {
            $Export = $true
            $ExportFormat = "CSV"
        }
        else
        {
            Write-Host "No export selected."
            return $null
        }
    }
    # Export the report if requested
    if ($Export)
    {
        $deviceName = $enrollmentState.managedDevice.device.deviceName
        if (-not $deviceName)
        {
            $deviceName = "Device"
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$deviceName`_Report_$timestamp"
        if ($ExportFormat -eq "HTML")
        {
            $htmlPath = "$pwd\$fileName.html"
            $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Report: $deviceName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Device Report: $deviceName</h1>
    <p>Generated on $(Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")</p>
    <table>
        <tr>
            <th>Property</th>
            <th>Value</th>
        </tr>
"@

            $htmlRows = ""
            foreach ($key in $formattedOutput.Keys)
            {
                $value = $formattedOutput[$key]
                $htmlRows += "<tr><td>$key</td><td>$value</td></tr>`n"
            }

            $htmlFooter = @"
    </table>
</body>
</html>
"@

            $htmlHeader + $htmlRows + $htmlFooter | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "HTML report exported to: $htmlPath"
        }
        elseif ($ExportFormat -eq "CSV")
        {
            $csvPath = "$pwd\$fileName.csv"
            
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "CSV report exported to: $csvPath"
        }
    }
    #endregion export
}

# SIG # Begin signature block
# MII6bwYJKoZIhvcNAQcCoII6YDCCOlwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB52o9K6TWpXmzh
# g6O0xfwANugb2iRnraWRJ/csvf2zU6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOGUbwd
# mZB6vjd7AAAAA4ZRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwNDMwMDQxMTA3WhcNMjUwNTAz
# MDQxMTA3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# oqLQPWOvKsrhbSB6OsrCd685g+O+B+bXMF3JIHd5yq9Dwuq0s6EDFgBKDsvRxVUC
# Vv1Y+aDj/UxPHH5hED2wSO1b5VbypD4lvzjbNaZyia6rhrp9jJDPWEjHfzkjEkKY
# +JDXCxzwrDi3OkmX9CFzv91BY/ibAC8cz+iW8h43d+rD6R+0qaUofXQCME2bPdzP
# /VYZwzJsSvLKRkJkCIfgblxHELz7NevNBDfNp8e8pPl8EkHWZgU5SkiHwlzTlAfa
# oyiy9gPPDzXNkZfxJlfh7mXn0lHeGSnMtRkhYx44GhNpmNY8k7t6z2vIKZQw6PSp
# Sswsq9O6hcZsQhv3xDiIjIsz60ZP8f3MigKMxc1KxMjkTr8oa8WaqUpY5AvqIUb4
# RRLJdM6AtQWJCOoLUKTNxljYPNcfywYVZ0I5tJ5KslffZ55fd2yJo8LqcByZUA0m
# CAbERHw0qMfb/zgeUFtQ/RXFpyX80KO2DAGs7oRzAPAZ8Z/MWY6JKkwO1aZxAajd
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFIEuxGH+aqlCsKkNOe0NM8LUj0oFMB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGy3Mnp2iO6X2QJc
# 6xbd07O60z9HgTOiJK4znPsMsDp8Ahn/3txtsRx75+feCdOGWdoxbdtr1al4ggZU
# NKIxj9nnrGuWVdofz/PaCCMfN0UZF713CF3j+IptuhMA/PmRsPoEkHhe9grx/6P8
# bN6BK4/0DyouTKoay4YEuaCkoL5MDjuADIHjGQE2MQLifj9SDzTuEgirpGu8Q9Vk
# /af2dPBkajxJq5FB5977OKl6zkoxcsdFCOU3McDEyoLoFENTkMoE/Br6hJ37QEVX
# JGkUxJZ5Cyex7VPGpDdiPIl2iN8d86DZ8U4hVR8YF72B82iDqPk+fq2KyUxMGrDB
# ZbgsPFUlPLru6DhyHk/Ian3/GhnatSco47J9Sq+hv88jYurFukuCpZ8P8K+RG6eq
# 4gGp42T1fj2VLIiaB1obrL9lMDTIsmw9CdyWi+wEpl144vfKMg8H1K6PxJrMmOv6
# 9kU79OAyEHtG4agXptaGGDI4MMC0ivUqlV5e3rwofaQ/9EVrJtyy8mTGtjIsPwP3
# ySfeIL6+ZCFuuzI6KjetsGsZ3NJFzk9H5hGtCg0Q1btaSmyeFyXskJV65YpCDtlw
# BwqXTFsLkAsP9+Wljr8jOfunVZje2BECU88g/x15Pk6JeXfkZUJvmvjgIzQfUX+9
# SAHM0NBbCVAZEwKfHPVg3yfb4mQjMIIG5zCCBM+gAwIBAgITMwADhlG8HZmQer43
# ewAAAAOGUTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDQzMDA0MTEwN1oXDTI1MDUwMzA0MTEw
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKKi0D1j
# ryrK4W0gejrKwnevOYPjvgfm1zBdySB3ecqvQ8LqtLOhAxYASg7L0cVVAlb9WPmg
# 4/1MTxx+YRA9sEjtW+VW8qQ+Jb842zWmcomuq4a6fYyQz1hIx385IxJCmPiQ1wsc
# 8Kw4tzpJl/Qhc7/dQWP4mwAvHM/olvIeN3fqw+kftKmlKH10AjBNmz3cz/1WGcMy
# bEryykZCZAiH4G5cRxC8+zXrzQQ3zafHvKT5fBJB1mYFOUpIh8Jc05QH2qMosvYD
# zw81zZGX8SZX4e5l59JR3hkpzLUZIWMeOBoTaZjWPJO7es9ryCmUMOj0qUrMLKvT
# uoXGbEIb98Q4iIyLM+tGT/H9zIoCjMXNSsTI5E6/KGvFmqlKWOQL6iFG+EUSyXTO
# gLUFiQjqC1CkzcZY2DzXH8sGFWdCObSeSrJX32eeX3dsiaPC6nAcmVANJggGxER8
# NKjH2/84HlBbUP0Vxacl/NCjtgwBrO6EcwDwGfGfzFmOiSpMDtWmcQGo3QIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBSBLsRh/mqpQrCpDTntDTPC1I9KBTAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBstzJ6dojul9kCXOsW3dOz
# utM/R4EzoiSuM5z7DLA6fAIZ/97cbbEce+fn3gnThlnaMW3ba9WpeIIGVDSiMY/Z
# 56xrllXaH8/z2ggjHzdFGRe9dwhd4/iKbboTAPz5kbD6BJB4XvYK8f+j/GzegSuP
# 9A8qLkyqGsuGBLmgpKC+TA47gAyB4xkBNjEC4n4/Ug807hIIq6RrvEPVZP2n9nTw
# ZGo8SauRQefe+zipes5KMXLHRQjlNzHAxMqC6BRDU5DKBPwa+oSd+0BFVyRpFMSW
# eQsnse1TxqQ3YjyJdojfHfOg2fFOIVUfGBe9gfNog6j5Pn6tislMTBqwwWW4LDxV
# JTy67ug4ch5PyGp9/xoZ2rUnKOOyfUqvob/PI2LqxbpLgqWfD/CvkRunquIBqeNk
# 9X49lSyImgdaG6y/ZTA0yLJsPQnclovsBKZdeOL3yjIPB9Suj8SazJjr+vZFO/Tg
# MhB7RuGoF6bWhhgyODDAtIr1KpVeXt68KH2kP/RFaybcsvJkxrYyLD8D98kn3iC+
# vmQhbrsyOio3rbBrGdzSRc5PR+YRrQoNENW7Wkpsnhcl7JCVeuWKQg7ZcAcKl0xb
# C5ALD/flpY6/Izn7p1WY3tgRAlPPIP8deT5OiXl35GVCb5r44CM0H1F/vUgBzNDQ
# WwlQGRMCnxz1YN8n2+JkIzCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
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
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADhlG8HZmQer43ewAAAAOGUTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCBdb1TFwucSKMIXshjZm+d53Tk
# AZLqndmnlrtZGErkzDANBgkqhkiG9w0BAQEFAASCAYAFuVqF+KIf+l71BsxOe8sB
# oOyRTEYVuYR8lux9phdkDo5jJ97gzJDsd1O2+1cEc8DTiFwvcKS0OYqxviL9eTk2
# f+5zu3sp3irw9sXRF/yEAz78LbJtiT7/yLAX1poAL/wJ2rL3YrjJtowkuhXTkW+f
# aTdXJGhNXBYYsj8MMYcMn11GUhGmsnTl6r3x1rEC41LecmFevATN9yum/5VjH3U4
# JQz7KLcfpdGFGosoWRTVxeIZNWC9rkH9fV9AII11zaSnH9mHmJgtzukRqETL5scy
# O1lC6UWh0HjeoM5IfNMCS/DT3B79yih1MisXh9TOVyT1tLuG+8/reu/55MBcInmW
# zPaIFMmeU5DlgddUP+qafMcsRGr357rg583FEH97I8rOCjl6pDG1nUO2Kc0zbQ+W
# JILIEn1d8o1sORTO+MwTbGjYifL3wFv/mnzeehACS3sIml3VG52hinLA+apu/ArA
# cUXbo8chI6r3SHy8qwPSFl36SNJLQkRk0Lb+1XhSpQahghSfMIIUmwYKKwYBBAGC
# NwMDATGCFIswghSHBgkqhkiG9w0BBwKgghR4MIIUdAIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYAYLKoZIhvcNAQkQAQSgggFPBIIBSzCCAUcCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgbTPP7dpd6ODvf0xLoRzq3hGyPOyuf+417MF8Xmz6
# 1o8CBmgHqaMvJxgSMjAyNTA0MzAwNzA3NDUuODlaMASAAgH0oIHgpIHdMIHaMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVT
# TjozREE1LTk2M0ItRTFGNDE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0Eg
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
# MwAAAEYX5HV6yv3a5QAAAAAARjANBgkqhkiG9w0BAQwFADBhMQswCQYDVQQGEwJV
# UzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDAeFw0yNDExMjYx
# ODQ4NDlaFw0yNTExMTkxODQ4NDlaMIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRp
# b25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjozREE1LTk2M0ItRTFGNDE1MDMG
# A1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3Jp
# dHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCwlXzoj/MNL1BfnV+g
# g4d0fZum1HdUJidSNTcDzpHJvmIBqH566zBYcV0TyN7+3qOnJjpoTx6JBMgNYnL5
# BmTX9HrmX0WdNMLf74u7NtBSuAD2sf6n2qUUrz7i8f7r0JiZixKJnkvA/1akLHpp
# QMDCug1oC0AYjd753b5vy1vWdrHXE9hL71BZe5DCq5/4LBny8aOQZlzvjewgONki
# Zm+SfctkJjh9LxdkDlq5EvGE6YU0uC37XF7qkHvIksD2+XgBP0lEMfmPJo2fI9Fw
# IA9YMX7KIINEM5OY6nkvKryM9s5bK6LV4z48NYpiI1xvH15YDps+19nHCtKMVTZd
# B4cYhA0dVqJ7dAu4VcxUwD1AEcMxWbIOR1z6OFkVY9GX5oH8k17d9t35PWfn0Xux
# W4SG/rimgtFgpE/shRsy5nMCbHyeCdW0He1plrYQqTsSHP2n/lz2DCgIlnx+uvPL
# Vf5+JG/1d1i/LdwbC2WH6UEEJyZIl3a0YwM4rdzoR+P4dO9I/2oWOxXCYqFytYdC
# y9ljELUwbyLjrjRddteR8QTxrCfadKpKfFY6Ak/HNZPUHaAPak3baOIvV7Q8axo3
# DWQy2ib3zXV6hMPNt1v90pv+q9daQdwUzUrgcbwThdrRhWHwlRIVg2sR668HPn4/
# 8l9ikGokrL6gAmVxNswEZ9awCwIDAQABo4IByzCCAccwHQYDVR0OBBYEFBE20NSv
# drC6Z6cm6RPGP8YbqIrxMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7ZPdsh
# MGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUy
# MENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFB1
# YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# ZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgG
# BmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAFIW5L+gGzX4gyHorS33YKXuK9iC9
# 1iZTpm30x/EdHG6U8NAu2qityxjZVq6MDq300gspG0ntzLYqVhjfku7iNzE78k6t
# NgFCr9wvGkIHeK+Q2RAO9/s5R8rhNC+lywOB+6K5Zi0kfO0agVXf7Nk2O6F6D9AE
# zNLijG+cOe5Ef2F5l4ZsVSkLFCI5jELC+r4KnNZjunc+qvjSz2DkNsXfrjFhyk+K
# 7v7U7+JFZ8kZ58yFuxEX0cxDKpJLxiNh/ODCOL2UxYkhyfI3AR0EhfxX9QZHVgxy
# ZwnavR35FxqLSiGTeAJsK7YN3bIxyuP6eCcnkX8TMdpu9kPD97sHnM7po0UQDrja
# N7etviLDxnax2nemdvJW3BewOLFrD1nSnd7ZHdPGPB3oWTCaK9/3XwQERLi3Xj+H
# Zc89RP50Nt7h7+3G6oq2kXYNidI9iWd+gL+lvkQZH9YTIfBCLWjvuXvUUUU+AvFI
# 00UtqrvdrIdqCFaqE9HHQgSfXeQ53xLWdMCztUP/YnMXiJxNBkc6UE2px/o6+/LX
# JDIpwIXR4HSodLfkfsNQl6FFrJ1xsOYGSHvcFkH8389RmUvrjr1NBbdesc4Bu4ko
# x+3cabOZc1zm89G+1RRL2tReFzSMlYSGO3iKn3GGXmQiRmFlBb3CpbUVQz+fgxVM
# feL0j4LmKQfT1jIxggPUMIID0AIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABG
# MA0GCWCGSAFlAwQCAQUAoIIBLTAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQw
# LwYJKoZIhvcNAQkEMSIEIFA12rvPH8I+CZEy5e7syxMTAltXwrcCfrOsECR3rB8c
# MIHdBgsqhkiG9w0BCRACLzGBzTCByjCBxzCBoAQgEid2SJpUPj5xQm73M4vqDmVh
# 1QR6TiuTUVkL3P8Wis4wfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABGF+R1esr92uUAAAAAAEYwIgQg
# e3iAgX0dO52YpQ+Pr0DFLqlAV2fYwaes/XYd3hCB0IIwDQYJKoZIhvcNAQELBQAE
# ggIAShI2rs316dE/0ye89p5RDbJZbBpP6kctIomkPtCYy0opNNoct8RNKNmTAdp7
# hdpsAr0ncFjVvYyoDw1zqTqDMwvwS3d7+m2HUSt4xoHVUco2NpfA4KzWoOHYGSqO
# hSJQdoSyoW5Qc1UBhmla38SCUJd/kDetWkD8QNdpkJ9x/CD8PViJD4xATl0YEdce
# 18gFQokYCfFHzfvmWmwh852Kgagx7SNfl+itZ8SLxvbClRtKw5T/mv4hjZ4S3Mtr
# UfDiVMfKfdf8vZaX3y8EL/QuI0uHwoAL6w5AbZTsvukJhvhf3q0Mnpj/q5JiXM7X
# diDOhawYLYSjSsOpp7i8Joq4qCE+rldaNqqf7NJen5c4lhEdkR+TnNPUxMYVs7Ot
# 77rFeQ3lkLwElvF7GdNj+gRXoeGc73JeLG0zS8MZAKjNkCznGEHOG6CkQu4Ap1bc
# iSseOz73Ra0JdlTScedgzDdSSSecD0ciywUa9eH348uyA+u33Z0M9zYy0y9rj6NA
# VOn5rx/VMC7UtCGwkZNPBfWlTDaXXM90X5/wcvZrTPmPaxCjUm0+IFN14Ya030Rw
# sfsm8rFyxoykOIfw1T4A0Zyft7hJIqE3mXrFyajB3YzMJ7BjAB82HMfmhXga6+LQ
# sPNLUYlS16/PLpcLgxB1EU2wwJhfuGBLO8oF0vfEjRrXTcw=
# SIG # End signature block
