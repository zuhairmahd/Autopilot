#region other code

$choices = @('Clean the device', 'Wipe the device')
$choice = DisplayNumericMenu -Choices $choices 
switch ($choice)
{
    $choices[0]
    {
        Write-Host "Cleaning the device is a distructive action and cannot be undone" -ForegroundColor Red
        Write-Host "Are you sure you want to clean the device?" -ForegroundColor Red
        $subchoices = @('Yes', 'No')
        $subchoice = DisplayNumericMenu -Choices $subchoices
        switch ($subchoice)
        {
            'yes'
            {
                Write-Host "Cleaning device..."
                $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes -ForceNewToken
                SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'clean'
            }
            'no'
            {
                Write-Host "Exitting... Come back when you are sure."
            }
        }
    }
    $choices[1]
    {
        Write-Host "Wiping device..."
        Write-Host "This will remove all data from the device." -ForegroundColor Red
        Write-Host "Are you sure you want to wipe the device?" -ForegroundColor Red
        Write-Host "This is a destructive action and cannot be undone." -ForegroundColor Red
        $subchoices = @('Yes', 'No')
        $subchoice = DisplayNumericMenu -Choices $subchoices
        switch ($subchoice)
        {
            'yes'
            {
                Write-Host "Wiping device..."
                $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes
                SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'wipe'
            }
            'no'
            {
                Write-Host "Exitting... Come back when you are sure."
            }
        }
    }
}
#endregion other code
