# Helper function to process a single filter condition
function ProcessFilterCondition
{
    [CmdletBinding()]
    param(
        [string]$condition
    )

    Write-Verbose "Processing filter condition: $condition"
    # Check if this is a function-based filter (contains, startswith, endswith)
    Write-Verbose "Checking for function-based filter..."
    if ($condition -match '(startswith|contains|endswith)\s*\(([^,]+),\s*([^)]+)\)')
    {
        Write-Verbose "Found function-based filter: $($Matches[1])"
        $filterOperator = $Matches[1]
        Write-Verbose "Filter Operator: $filterOperator"
        $filterKey = $Matches[2].Trim()
        Write-Verbose "Filter Key: $filterKey"
        $filterValue = $Matches[3].Trim()
        Write-Verbose "Filter Value: $filterValue"
        # Remove quotes if present in the value
        Write-Verbose "Removing quotes from filter value..."
        $filterValue = $filterValue -replace "^'|'$", ""
        Write-Verbose "Filter Value after removing double quotes: $filterValue"
        $filterValue = $filterValue -replace '^"|"$', ""
        Write-Verbose "Filter Value after removing single quotes: $filterValue"
        Write-Verbose "Filter Key after removing quotes: $FilterKey"
        Write-Verbose "Filter Value: $FilterValue"
        Write-Verbose "Filter Operator: $FilterOperator"
        $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
        Write-Verbose "Encoded Filter Value: $encodedFilterValue"
        # Rebuild the function call with encoded value
        $returnFilter = "$filterOperator($filterKey,'$encodedFilterValue')"
        Write-Verbose "Returning filter: $returnFilter"
        return $returnFilter
    }
    # Check for standard comparison operators
    elseif ($condition -match '([^\s]+)\s+(eq|ne|gt|lt|ge|le)\s+(.+)')
    {
        Write-Verbose "Not a function based filter. Checking for standard comparison operators..."
        $filterKey = $Matches[1].Trim()
        $filterOperator = $Matches[2].Trim()
        $filterValue = $Matches[3].Trim()
        Write-Verbose "Filter Key: $FilterKey"
        Write-Verbose "Filter Operator: $FilterOperator"
        Write-Verbose "Filter Value: $FilterValue"
        # Special handling for null and empty string
        Write-Verbose "Checking for null or empty string..."
        if ($filterValue -eq "null" -or $filterValue -eq "''" -or $filterValue -eq '""')
        {
            Write-Verbose "Filter value is null or empty string."
            Write-Verbose "Returning filter without encoding: $filterKey $filterOperator $filterValue"
            # Don't encode null or empty string values
            return "$filterKey $filterOperator $filterValue"
        }
        else
        {
            # Remove quotes if present
            Write-Verbose "Checking for quotes and removing from value if present..."
            Write-Verbose "Value before processing: $filterValue"
            $filterValue = $filterValue -replace "^'|'$", ""
            Write-Verbose "Value after removing double quotes: $filterValue"
            $filterValue = $filterValue -replace '^"|"$', ""
            Write-Verbose "Value after removing single quotes: $filterValue"
            Write-Verbose "Filter Key: $FilterKey"
            Write-Verbose "Filter Value: $FilterValue"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "Encoded Filter Value: $encodedFilterValue"
            # Add quotes back for the encoded value
            $returnFilter = "$filterKey $filterOperator '$encodedFilterValue'"
            Write-Verbose "Returning filter: $returnFilter"
            return $returnFilter
        }
    }
    else
    {
        Write-Verbose "Unrecognized filter condition format: $condition"
        return $condition
    }
}

function CallGraphAPI()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        [string]$APIVersion = 'beta',
        [string]$method = 'get',
        [string]$Filter = $null,
        [string]$ExtraParameters = $null,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    if ($accessToken)
    {
        Write-Verbose "Access token provided."
    }
    else
    {
        Write-Host 'Access token not provided. Please provide a valid access token.' -ForegroundColor Red
        return
    }
    Write-Verbose "Resource Path: $ResourcePath"
    Write-Verbose "Method: $method"
    Write-Verbose "Filter: $filter"
    Write-Verbose "Extra Parameters: $ExtraParameters"
    Write-Verbose "Version: $APIVersion"
    Write-Verbose "Consistency Level: $consistencyLevel"
    Write-Verbose "Body: $body"
    Write-Verbose "SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Verbose "Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "Processing filter string: $Filter"
        Write-Verbose "Splitting filter by logical operators while preserving operators."
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Verbose "Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Verbose "No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Verbose "Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Verbose "Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Verbose "Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Verbose "Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Verbose "Condition to process: $condition"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "Processed filter condition: $($filterParts[$filterParts.Count - 1])"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Verbose "Logical operators so far: $($logicalOperators -join ', ')"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Verbose "Processing filter condition after the last logical operator."
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "Processed filter condition: $($filterParts[$filterParts.Count - 1])"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Verbose "Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Verbose "Adding logical operator: $($logicalOperators[$i])"
            }
            Write-Verbose "Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Verbose "Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose 'No filter provided.'
        $encodedUri = $uri
    }
    
    if ($extraParameters)
    {
        Write-Verbose "Extra parameters provided."
        Write-Verbose "Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Verbose "Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Verbose "Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Verbose "Key: $key"
                Write-Verbose "Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Verbose "Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Verbose "Final parameter list:"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Verbose "Final query string: $queryString"
        if ($filter) 
        {
            Write-Verbose "Adding extra parameters to the uri along with the filter."
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Verbose "No filter provided. Adding extra parameters to the uri."
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Verbose 'No extra parameters provided.'
    }
    if ($consistencyLevel)
    {
        Write-Verbose 'Adding consistency level to the headers.'
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Verbose 'No consistency level provided.'
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Verbose "Making the following call to Microsoft Graph:" 
    Write-Verbose "URI: $encodedUri." 
    Write-Verbose "Method: $method."
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        $response | ForEach-Object {
            if ($_.'@odata.nextLink')
            {
                $nextLink = $_.'@odata.nextLink'
                # $nextGroups = CallGraphAPI -accessToken $accessToken -ResourcePath $nextLink -Method GET
                $nextGroups = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing 
                $response.value += $nextGroups.value
            }
        }
        Write-Verbose 'The call was successful.'
        if ($response.count)
        {
            Write-Verbose "Number of objects returned: $($response.count)."
        }
        if ($response.value.Count)
        {
            Write-Verbose "Number of items returned: $($response.value.Count)."
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Verbose "Status code: $statusCode"
            Write-Verbose "Status code message: $statusCodeMessage"
        }
    }
    catch
    {
        if ($null -eq $_.Exception.statusCode)
        {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "Status code message: $statusCodeMessage"
            $statusMessage = $statusCodeMessage
        }
        else
        {
            $statusCode = $_.Exception.statuscode.value__
            $statusCodeMessage = $_.Exception.statuscode
            $statusMessage = $_.Exception.Message
        }
        switch ($statusCode)
        {
            400
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
                Write-Host "Error: $statusMessage" -ForegroundColor Red
                Write-Host "The status code is $statusCode"
                Write-Host "$statusCode indicates $statusCodeMessage"
                Write-Host "Status message: $statusMessage"
                Write-Host 'The full error message follows below:'
                Write-Host '----------------------------------------------------------'
                Write-Host "$_"
                if ($_.Exception.Response)
                {
                    $errorResponse = $_.Exception.Response.GetResponseStream()
                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                    $errorMessage = $streamReader.ReadToEnd()
                    $streamReader.Close()
                    Write-Error "Server Response: $errorMessage"
                }   
            }
        }
        Write-Verbose "Failed to call the Graph API: $_"
        Write-Verbose "Error: $statusMessage"
        Write-Verbose "The status code is $statusCode"
        Write-Verbose "$statusCode indicates $statusCodeMessage"
        Write-Verbose "Status message: $statusMessage"
        Write-Verbose 'The full error message follows below:'
        Write-Verbose '----------------------------------------------------------'
        Write-Verbose "$_"
        if ($_.Exception.Response -and $psversionTable.PSVersion.Major -ge 7)
        {
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Verbose "Server Response: $errorMessage"
            }   
        }
        # return $statusCode
        return $null
    }
    Write-Verbose "Response: $($response)"
    Write-Verbose "Response value: $($response.value)"
    return $response
}




# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDzCY4MWX4rgo+C
# vOnJhQKF0acLymiMA59XQrf62zsQZKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADgZEm6+vpcFZTbwAAAAOBkTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDLg9Fhg6ETF1/qdS65Ceb5mq/4
# Cb8k81wAam1QVlSYDDANBgkqhkiG9w0BAQEFAASCAYA4LBia0F90lSL9rGsYyRCS
# HpwWmAghmmQpTll7uSz6IbihWuK5Bg7DGV3etWAqUuDR95eZJzl9lDg4DgZNnNYK
# 4haF2o629FYWeTlOJpOxWHqGbd8PjT6p/5TFjtSxi5Img8ft2CPoYYV7uLIDB2To
# 8Qs+ykqMUo2qE4HaNniaSIUmb1hSrmvGgme/1AOyZ8R+Fyq7rvySpXyFQlXpXBKH
# w45Nca8Z6/3nFuR7P5i8A2JHbttI6hPPx58bAWGc3QBuL2wH6jvUp78y6ggRt2T5
# wM0+1rKJw4LN4fyOcMOsuWMw0bNlgPTuW1qtYXSM4JqXa2cJvbw/1T9Ltd7LLti+
# tAHJe9XBg953vtNOMzZUBwELymWIv19uYVSAJCoiK1oH45X3asBdCcVOOJdbKmgI
# DZ//GVo7Sl0GNTx/pxkmDE8hgOJnx6CgPDLS9Hb+NmuiIyKgUEgMA+Gfk2cO13IF
# XP3x8MPPP8iFUCnfW51Q6P5jyEv3BWT8A0bmePiD4/ahghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgQnoxO2QBTRvbiPebZ3J5Zf0ktowR2pZtJ/rS3PwV
# MtECBmgLywGhehgTMjAyNTA0MjkwMzQzMjAuOTY4WjAEgAIB9KCB4aSB3jCB2zEL
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
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjkwMzQz
# MjBaMC8GCSqGSIb3DQEJBDEiBCCVL8ON+RsO5Gc2syfvT+v2Mfse9+ONLELKHdL7
# yCg4ITCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIJNm85ZyhQAGGe9QPhd3
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
# 67o9/DAiGA8yMDI1MDQyODE3NDg0NFoYDzIwMjUwNDI5MTc0ODQ0WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDruj38AgEAMAoCAQACAiFeAgH/MAcCAQACAhOKMAoC
# BQDru498AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAOLZiWTZAJLKRQNn
# cqckGRpmJ1hhqfn+5sugpcL58Sby6cFHepGOizvm24O+bWajn+JKd7BnEalXWh21
# Wgmk6P+/Nt/upvav6ATWRxuv+buYrdj2bfBYiPMIj9pYmNW7tf9lNEEOEbn6RoV9
# 7zCMPaWBf4+nzomj8uKsrzYREDR0ic2srICt2auU8cKeDylNCabH34RFUbyX5ZNO
# z8EMEPuDzFshlNkybwO0H2SQw+Jmo+lZCzvlecvN7BuYmI7FRNNgXC9zxGQzsVqR
# mvsAseTQiG+v9wL32TueFk9hAsoRtTnV9+a8qy0Vvq8qv1Bl6YfyKklNUFKoi9Nl
# WZkrhl4wDQYJKoZIhvcNAQEBBQAEggIAaCtR68ggqs50AitKtkJRO9hWF2bSC2vl
# 7bX0+W/VCxI1076dDodQTZ1ApJk2K7h3bDGqPH3jxSYtQKT1XGQ3mYhLL8uaGvuL
# DnErRrt7lbSIeL/ZlVV3+xpCT2J4ak9k3VuKvhZ5/M0L3PcwGBUUAbjdB+br+mNx
# u1urK1gdBKAzEWEWXTNyEVAlfzFMDE/KdVkgDT3yA6cpWQ3DmR/MnrUDlo/YX+MD
# ravSY9TOH2pHvAC+q2dZnMcv6piBsyIV/rofSejHCXQcxlCuFERfvJQJ/7ikJVVA
# K1J/vXEQSxAM4rzVO08i/fj/kWGl+yhGqQBiZ8exYXZ0fWdMlb1NKqq6RBZKNI0u
# x33uOr8W16ZD6waiKrG4F6yN8orfbQ59m1ekCvVIJOwgKCB5pWwgDDOh44mWqYOR
# qspWJK7hBEXCM0UkuRPBbM1cVXy+6UGX2Tiw6sAyMw44lPpUxzGbwkHd2ZQmbBoM
# gxx2hDMi+w8aOqgHHAX2gL5p71K+j8tCPl7d5REVKvoZ60D25WU/STwRoGNM2eao
# HMeOOi0em3b9dOTZdYAE0bH8T4rzpHCg5/RgGhH+a2fhvks7McgtsG1OVzpxs0lN
# BwJK6kdtKYz20a31JTPCorZdYJ0HdqFzi3k9fI95MD/WkIYy5CspJHn8rgaf5aUK
# FU6vexu0ar0=
# SIG # End signature block
