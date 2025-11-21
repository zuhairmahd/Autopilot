function Start-HttpListener()
{
    <#
    .SYNOPSIS
    Starts a local HTTP listener to capture OAuth authorization code callback.

    .DESCRIPTION
    This function creates and manages a local HTTP listener that captures the OAuth authorization
    code from the redirect callback after user authentication in the browser. It implements timeout
    handling, extracts the authorization code from the callback URL, sends a user-friendly response
    page to the browser, and handles errors and edge cases in the OAuth flow.

    .PARAMETER redirectUri
    The redirect URI configured in Azure AD app registration (must match exactly). Should be
    a localhost URL like "http://localhost:8080/".

    .OUTPUTS
    System.Collections.Hashtable
    Returns hashtable with properties:
    - Success: Boolean indicating if authorization code was captured successfully
    - Code: The authorization code extracted from callback URL
    - ErrorMessage: Error message if operation failed

    .EXAMPLE
    $result = Start-HttpListener -redirectUri "http://localhost:8080/"
    if ($result.Success) {
        $authCode = $result.Code
    }

    .NOTES
    Creates System.Net.HttpListener on specified localhost port.
    Implements 5-minute timeout for user authentication.
    Captures authorization code from query string parameter.
    Sends HTML response page to browser confirming completion.
    Handles listener cleanup on timeout or completion.
    Provides diagnostic information including local IP addresses.
    Requires redirect URI to end with trailing slash.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [string]$redirectUri
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting HTTP listener function with redirectUri: $redirectUri"
    # Result object to return
    $result = @{
        Success      = $false
        Code         = $null
        ErrorMessage = $null
    }
    try
    {
        # Get local IP address for diagnostics
        try
        {
            $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*Virtual*"}).IPAddress
            Write-Verbose "[$functionName] Local IP addresses: $($localIp -join ', ')"
        }
        catch
        {
            Write-Verbose "[$functionName] Could not get local IP address: $_"
        }
        # Create HTTP listener
        $listener = New-Object System.Net.HttpListener
        # Make sure redirect URI ends with a slash for matching
        $redirectUri = $redirectUri.TrimEnd('/') + '/'
        Write-Verbose "[$functionName] Using redirect URI: $redirectUri"
        # Add prefix
        $listener.Prefixes.Add($redirectUri)
        Write-Verbose "[$functionName] Added listener prefix: $redirectUri"
        # Start listener
        Write-Verbose "[$functionName] Starting HTTP listener..."
        $listener.Start()
        Write-Host "Waiting for authorization response. Please complete the sign in within your browser..."
        # Set timeout for listener
        $timeout = New-TimeSpan -Minutes 5
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        # Wait for the callback
        while ($stopwatch.Elapsed -lt $timeout)
        {
            # Check for pending request with a timeout
            if ($listener.IsListening)
            {
                try
                {
                    # Try to get context with a 15-second timeout
                    $task = $listener.GetContextAsync()
                    $timeoutTask = [System.Threading.Tasks.Task]::Delay(15000)
                    $completedTask = [System.Threading.Tasks.Task]::WhenAny($task, $timeoutTask).GetAwaiter().GetResult()
                    # If the HTTP request came in before timeout
                    if ($completedTask -eq $task)
                    {
                        $context = $task.GetAwaiter().GetResult()
                        Write-Verbose "[$functionName] Received HTTP request"
                        # Get request details for diagnostics
                        $request = $context.Request
                        Write-Verbose "[$functionName] Request URL: $($request.Url)"
                        Write-Verbose "[$functionName] Request headers: $($request.Headers)"
                        # Check if QueryString exists and has keys
                        if ($null -ne $request.QueryString -and $request.QueryString.Count -gt 0)
                        {
                            Write-Verbose "[$functionName] Query string keys: $($request.QueryString.AllKeys -join ', ')"
                            # Check for code
                            $code = $request.QueryString.Get("code")
                            if ($null -ne $code)
                            {
                                Write-Verbose "[$functionName] Successfully retrieved authorization code"
                                $result.Success = $true
                                $result.Code = $code
                            }
                            else
                            {
                                # Check if there's an error
                                $authError = $request.QueryString.Get("error")
                                $errorDescription = $request.QueryString.Get("error_description")
                                if ($authError)
                                {
                                    Write-Verbose "[$functionName] Error in response: $authError - $errorDescription"
                                    $result.ErrorMessage = "Authentication error: $authError - $errorDescription"
                                }
                                else
                                {
                                    Write-Verbose "[$functionName] No code or error found in query string"
                                    $result.ErrorMessage = "Authorization code not found in the response"
                                }
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Query string is empty or null"
                            $result.ErrorMessage = "Empty query string in redirect response"
                        }
                        # Send response to browser
                        $response = $context.Response
                        $responseHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Complete</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f0f0; }
        .container { background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 40px; text-align: center; max-width: 600px; }
        h1 { color: #0078d4; margin-bottom: 20px; }
        p { color: #333; font-size: 16px; line-height: 1.6; }
        .status { font-weight: bold; margin: 20px 0; padding: 10px; border-radius: 4px; }
        .success { background-color: #dff6dd; color: #107c10; }
        .error { background-color: #fde7e9; color: #d13438; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Authentication Response</h1>
        $(if ($result.Success) {
            '<div class="status success">Authentication successful! You can close this window and return to the application.</div>'
        } else {
            "<div class='status error'>Authentication error: $($result.ErrorMessage)</div>"
        })
        <p>You may close this window and return to the PowerShell window.</p>
    </div>
</body>
</html>
"@
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
                        $response.ContentLength64 = $buffer.Length
                        $response.ContentType = "text/html"
                        $response.StatusCode = 200
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                        $response.Close()
                        # Break out of the loop
                        break
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Error while waiting for request: $_"
                    Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
                    $result.ErrorMessage = "HTTP listener error: $($_.Exception.Message)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Listener is no longer listening"
                $result.ErrorMessage = "HTTP listener stopped unexpectedly"
                break
            }
            # Brief pause before checking again
            Start-Sleep -Milliseconds 100
        }
        # Check for timeout
        if ($stopwatch.Elapsed -ge $timeout)
        {
            Write-Verbose "[$functionName] Timeout waiting for authentication response"
            $result.ErrorMessage = "Timed out waiting for authentication response"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error in HTTP listener: $_"
        Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
        $result.ErrorMessage = "Failed to start HTTP listener: $($_.Exception.Message)"
    }
    finally
    {
        # Clean up
        if ($listener -and $listener.IsListening)
        {
            $listener.Stop()
            $listener.Close()
            Write-Verbose "[$functionName] HTTP listener stopped"
        }
    }
    return $result
}

