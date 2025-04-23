function DisplayNumericMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again."
    )
    #region Print a verbose message with received    parameters
    Write-Verbose "Received parameters: $($choices | Out-String)"
    Write-Verbose "Prompt: $Prompt"
    Write-Verbose "ErrorMessage: $errorMessage"
    Write-Verbose "Banner: $banner"
    #endregion

    # Display the menu options
    Write-Host $banner -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "$($i + 1). $($choices[$i])"
    }
    Write-Host "0. Exit"
    
    # Prompt for user input and suppress output
    $selection = (Read-Host -Prompt $Prompt)
    # Validate the selection
    while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $choices.Count)
    {
        Write-Host $errorMessage -ForegroundColor Red
        #beep
        [console]::beep(1000, 500)
        $selection = (Read-Host -Prompt $Prompt)
    }
    
    if ($selection -ne 0)
    {
        # Return the selected choice
        return $choices[[int]$selection - 1]
    }
    else
    {
        Write-Verbose "Exiting script."
        return $selection
    }
}

function NewMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description
    )
    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

function AddMenuItem()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $false)]
        [hashtable]$Submenu
    )
    
    if ($Action -and $Submenu)
    {
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
        throw "A menu item must have either an Action or a Submenu."
    }
    
    $item = @{
        Name    = $Name
        Action  = $Action
        Submenu = $Submenu
    }
    
    $Menu.Items += $item
    
    return $Menu
}

function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [int]$Depth = 0,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$History = $null,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$MenuHistory = $null,
        [string]$BackoutText = $backoutText
    )
    
    # Initialize history if not provided
    if ($null -eq $History)
    {
        $History = New-Object System.Collections.ArrayList
    }
    
    # Initialize menu history if not provided
    if ($null -eq $MenuHistory)
    {
        $MenuHistory = New-Object System.Collections.ArrayList
    }
    
    # Clear screen for better readability
    Clear-Host
    
    # Add navigation options based on depth
    $choices = @()
    $menuItems = @()
    
    # Loop through menu items and add to choices
    foreach ($item in $Menu.Items)
    {
        $choices += $item.Name
        $menuItems += $item
    }
    
    # Add navigation options - use ASCII friendly characters instead of Unicode arrows
    if ($Depth -gt 0)
    {
        $choices += "Back"
    }
    if ($Depth -gt 1)
    {
        $choices += "Main Menu"
    }
    
    # Create banner text
    $banner = $Menu.Title
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        $banner += "`n$($Menu.Description)"
    }
    
    # Add current path to banner - create proper breadcrumb
    if ($History.Count -gt 0)
    {
        # Create a clean breadcrumb path without duplicates
        $cleanHistory = [System.Collections.ArrayList]@()
        $previousItem = ""
        
        foreach ($item in $History)
        {
            if ($item -ne $previousItem)
            {
                [void]$cleanHistory.Add($item)
                $previousItem = $item
            }
        }
        
        $path = $cleanHistory -join " > "
        $banner += "`n[$path]"
    }
    
    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option"
    
    # Handle navigation options
    if ($selectedOption -eq "Back")
    {
        if ($History.Count -gt 0)
        {
            $History.RemoveAt($History.Count - 1)
            # Get previous menu from MenuHistory
            $previousMenu = $MenuHistory[$MenuHistory.Count - 1]
            $MenuHistory.RemoveAt($MenuHistory.Count - 1)
            return ShowMenu -Menu $previousMenu -Depth ($Depth - 1) -History $History -MenuHistory $MenuHistory
        }
    }
    elseif ($selectedOption -eq "Main Menu")
    {
        # Go to main menu
        $mainMenu = $MenuHistory[0]
        $History.Clear()
        $MenuHistory.Clear()
        $MenuHistory.Add($mainMenu)
        return ShowMenu -Menu $mainMenu -Depth 0 -History $History -MenuHistory $MenuHistory
    }
    elseif ($selectedOption -eq 0)
    {
        # Exit
        return $null
    }
    else
    {
        # Find the selected item
        $selectedIndex = $choices.IndexOf($selectedOption)
        $selectedItem = $menuItems[$selectedIndex]
        # Handle action or submenu
        if ($selectedItem.Action)
        {
            # Execute the action
            $result = & $selectedItem.Action
            # Always display press any key to continue, regardless of whether action returns a value
            Write-Host "`n"
            # If the action returned a value, display it
            if ($null -ne $result)
            {
                Write-Host "$result`n" -ForegroundColor Cyan
            }
            if (-not ($result -eq $backoutText)) 
            {
                Write-Verbose "Action executed: $($selectedItem.Name)"
                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            return ShowMenu -Menu $Menu -Depth $Depth -History $History -MenuHistory $MenuHistory
        }
        elseif ($selectedItem.Submenu)
        {
            # Navigate to submenu - only add the title once to avoid duplicates
            $History.Add($Menu.Title)
            $MenuHistory.Add($Menu)
            return ShowMenu -Menu $selectedItem.Submenu -Depth ($Depth + 1) -History $History -MenuHistory $MenuHistory
        }
    }
}

