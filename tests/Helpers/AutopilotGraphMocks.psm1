<#
.SYNOPSIS
    Comprehensive mocking infrastructure for Microsoft Graph API interactions in Autopilot tests

.DESCRIPTION
    This module provides a robust, maintainable, and extensible framework for mocking
    Microsoft Graph API calls in Pester tests. It handles:
    - User directory operations (exact match, fuzzy search, exclusions)
    - Group directory operations (exact match, fuzzy search, exclusions)
    - Caching simulation
    - Error scenarios
    - Extensible mock data management

.NOTES
    Author: Autopilot Test Framework
    Version: 1.3.0
    Compatible with: PowerShell 5.1+, Pester 5.x
#>

#region Mock Data Management

# Default mock user data
# Note: Regular hashtable used to support .Clone() method
# Results are sorted in query functions to ensure consistent order across PS versions
$script:DefaultMockUsers = @{
    "jane.smith@contoso.com"   = @{
        userPrincipalName = "jane.smith@contoso.com"
        displayName       = "Jane Smith"
        givenName         = "Jane"
        surname           = "Smith"
        mail              = "jane.smith@contoso.com"
        id                = "user-002"
    }
    "jane.test@contoso.com"    = @{
        userPrincipalName = "jane.test@contoso.com"
        displayName       = "Jane Test"
        givenName         = "Jane"
        surname           = "Test"
        mail              = "jane.test@contoso.com"
        id                = "user-004"
    }
    "john.admin@contoso.com"   = @{
        userPrincipalName = "john.admin@contoso.com"
        displayName       = "John Admin"
        givenName         = "John"
        surname           = "Admin"
        mail              = "john.admin@contoso.com"
        id                = "user-003"
    }
    "john.doe@contoso.com"     = @{
        userPrincipalName = "john.doe@contoso.com"
        displayName       = "John Doe"
        givenName         = "John"
        surname           = "Doe"
        mail              = "john.doe@contoso.com"
        id                = "user-001"
    }
    "john.johnson@contoso.com" = @{
        userPrincipalName = "john.johnson@contoso.com"
        displayName       = "John Johnson"
        givenName         = "John"
        surname           = "Johnson"
        mail              = "john.johnson@contoso.com"
        id                = "user-005"
    }
}

# Default mock group data
# Note: Regular hashtable used to support .Clone() method
# Results are sorted in query functions to ensure consistent order across PS versions
$script:DefaultMockGroups = @{
    "Archive Marketing" = @{
        displayName  = "Archive Marketing"
        id           = "group-003"
        mailNickname = "archive-marketing"
    }
    "Disabled Group"    = @{
        displayName  = "Disabled Group"
        id           = "group-004"
        mailNickname = "disabled-group"
    }
    "Marketing Support" = @{
        displayName  = "Marketing Support"
        id           = "group-005"
        mailNickname = "marketing-support"
    }
    "Marketing Team"    = @{
        displayName  = "Marketing Team"
        id           = "group-001"
        mailNickname = "marketing-team"
    }
    "Sales Team"        = @{
        displayName  = "Sales Team"
        id           = "group-002"
        mailNickname = "sales-team"
    }
}

# Active mock data (can be customized per test)
$script:MockUsers = $script:DefaultMockUsers.Clone()
$script:MockGroups = $script:DefaultMockGroups.Clone()
$script:MockImportedDevices = @{}
$script:MockDeviceAssignments = @{}
$script:MockProfileAssignments = @{}

<#
.SYNOPSIS
    Adds a mock user to the test data

.DESCRIPTION
    Creates a mock user object with the specified properties for testing.
    The user will be available for mock Graph API calls.
    
    Supports custom properties for advanced scenarios like certificate data,
    authorization info, or any other user properties needed for testing.

.PARAMETER UserPrincipalName
    The UPN of the user to add

.PARAMETER DisplayName
    The display name of the user

.PARAMETER GivenName
    The given name (first name)

.PARAMETER Surname
    The surname (last name)

.PARAMETER Id
    Optional custom ID (auto-generated if not provided)

.PARAMETER Mail
    Optional email address (defaults to UserPrincipalName)

.PARAMETER CustomProperties
    Optional hashtable of additional properties to add to the user object.
    Useful for scenarios like certificate data, authorization info, etc.
    Properties are merged into the user object.

.EXAMPLE
    Add-MockUser -UserPrincipalName "test@contoso.com" -DisplayName "Test User" -GivenName "Test" -Surname "User"

.EXAMPLE
    # User with certificate data
    Add-MockUser -UserPrincipalName "admin@contoso.com" -DisplayName "Admin User" `
        -GivenName "Admin" -Surname "User" -CustomProperties @{
            authorizationInfo = @{
                certificateUserIds = @("C=US,O=Microsoft,CN=Admin")
            }
        }

.EXAMPLE
    # User with custom properties
    Add-MockUser -UserPrincipalName "user@contoso.com" -DisplayName "Test User" `
        -GivenName "Test" -Surname "User" -CustomProperties @{
            jobTitle = "Developer"
            department = "Engineering"
        }
#>
function Add-MockUser
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory)]
        [string]$DisplayName,
        
        [Parameter(Mandatory)]
        [string]$GivenName,
        
        [Parameter(Mandatory)]
        [string]$Surname,
        
        [string]$Id = "user-$([guid]::NewGuid().ToString().Substring(0, 8))",
        
        [string]$Mail = $UserPrincipalName,
        
        [hashtable]$CustomProperties = @{}
    )
    
    # Create base user object
    $user = @{
        userPrincipalName = $UserPrincipalName
        displayName       = $DisplayName
        givenName         = $GivenName
        surname           = $Surname
        mail              = $Mail
        id                = $Id
    }
    
    # Merge custom properties
    foreach ($key in $CustomProperties.Keys)
    {
        $user[$key] = $CustomProperties[$key]
    }
    
    $script:MockUsers[$UserPrincipalName] = $user
    
    $customPropsInfo = if ($CustomProperties.Count -gt 0) { " (with $($CustomProperties.Count) custom properties)" } else { "" }
    Write-Verbose "[Add-MockUser] Added user: $UserPrincipalName$customPropsInfo"
}

<#
.SYNOPSIS
    Adds a mock group to the test data

.PARAMETER DisplayName
    The display name of the group

.PARAMETER Id
    Optional custom ID (auto-generated if not provided)

.PARAMETER MailNickname
    Optional mail nickname (auto-generated if not provided)

.EXAMPLE
    Add-MockGroup -DisplayName "Test Group"
#>
function Add-MockGroup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,
        
        [string]$Id = "group-$([guid]::NewGuid().ToString().Substring(0, 8))",
        
        [string]$MailNickname = ($DisplayName -replace '\s+', '-').ToLower()
    )
    
    $script:MockGroups[$DisplayName] = @{
        displayName  = $DisplayName
        id           = $Id
        mailNickname = $MailNickname
    }
}

<#
.SYNOPSIS
    Resets mock data to defaults

.PARAMETER IncludeUsers
    Reset user data

.PARAMETER IncludeGroups
    Reset group data

.EXAMPLE
    Reset-MockData -IncludeUsers -IncludeGroups
#>
function Reset-MockData
{
    [CmdletBinding()]
    param(
        [switch]$IncludeUsers,
        [switch]$IncludeGroups
    )
    
    if ($IncludeUsers -or (-not $IncludeGroups -and -not $IncludeUsers))
    {
        $script:MockUsers = $script:DefaultMockUsers.Clone()
    }
    
    if ($IncludeGroups -or (-not $IncludeGroups -and -not $IncludeUsers))
    {
        $script:MockGroups = $script:DefaultMockGroups.Clone()
    }
}

<#
.SYNOPSIS
    Gets current mock users

.EXAMPLE
    $users = Get-MockUsers
#>
function Get-MockUsers
{
    return $script:MockUsers
}

<#
.SYNOPSIS
    Gets current mock groups

.EXAMPLE
    $groups = Get-MockGroups
#>
function Get-MockGroups
{
    return $script:MockGroups
}

#endregion

#region Graph API Mock Function

<#
.SYNOPSIS
    Mock implementation of CallGraphAPI function

.DESCRIPTION
    Provides comprehensive mocking of Microsoft Graph API calls supporting:
    - User exact match (by UPN)
    - User fuzzy search (startswith filters)
    - Group exact match (displayName filter, case-sensitive and case-insensitive)
    - Group fuzzy search ($search, startsWith, contains filters)
    - Proper error responses (404 for not found)
    - OData response structure

.PARAMETER accessToken
    The access token (not validated in mock)

.PARAMETER ResourcePath
    The Graph API resource path (e.g., "users/john@contoso.com", "groups")

.PARAMETER Filter
    OData $filter parameter

.PARAMETER ExtraParameters
    Additional query parameters (e.g., $search)

.PARAMETER consistencyLevel
    Consistency level for advanced queries

.EXAMPLE
    $result = Invoke-MockGraphAPI -ResourcePath "users/john.doe@contoso.com" -accessToken "test"
#>
function Invoke-MockGraphAPI
{
    [CmdletBinding()]
    param(
        [string]$accessToken,
        [string]$ResourcePath,
        [string]$Filter,
        [string]$ExtraParameters,
        [switch]$consistencyLevel,
        [string]$Method = "GET",
        [string]$Body = $null,
        [string]$apiVersion = 'v1.0'
    )
    
    Write-Verbose "[MockGraphAPI] Method: $Method"
    Write-Verbose "[MockGraphAPI] ResourcePath: $ResourcePath"
    Write-Verbose "[MockGraphAPI] Filter: $Filter"
    Write-Verbose "[MockGraphAPI] ExtraParameters: $ExtraParameters"
    
    # User exact match: users/{upn}
    if ($ResourcePath -like "users/*")
    {
        $upn = $ResourcePath -replace "users/", ""
        if ($script:MockUsers.ContainsKey($upn))
        {
            Write-Verbose "[MockGraphAPI] Returning user exact match for: $upn"
            return $script:MockUsers[$upn]
        }
        Write-Verbose "[MockGraphAPI] User not found: $upn"
        return 404
    }
    
    # Group exact match: groups?$filter=displayName eq 'name'
    # Supports both case-sensitive and case-insensitive (tolower) filters
    if ($ResourcePath -eq "groups" -and ($Filter -like "displayName eq*" -or $Filter -like "tolower(displayName) eq*"))
    {
        $matching = $null
        
        if ($Filter -like "tolower(displayName) eq*")
        {
            # Case-insensitive match using tolower()
            $groupName = ($Filter -replace "tolower\(displayName\) eq '(.+?)'", '$1').Trim()
            Write-Verbose "[MockGraphAPI] Case-insensitive group search for: $groupName"
            $matching = $script:MockGroups.Values | Where-Object { $_.displayName.ToLower() -eq $groupName.ToLower() }
        }
        else
        {
            # Case-sensitive match (legacy)
            $groupName = ($Filter -replace "displayName eq '(.+?)'", '$1').Trim()
            Write-Verbose "[MockGraphAPI] Case-sensitive group search for: $groupName"
            $matching = $script:MockGroups.Values | Where-Object { $_.displayName -eq $groupName }
        }
        
        if ($matching)
        {
            Write-Verbose "[MockGraphAPI] Returning group exact match"
            return [PSCustomObject]@{
                '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
                value            = @($matching)
            }
        }
        
        Write-Verbose "[MockGraphAPI] No groups found matching: $groupName"
        return [PSCustomObject]@{ value = @() }
    }
    
    # User fuzzy search: users?$filter=startswith(givenName, 'term') or startswith(surname, 'term')
    if ($ResourcePath -eq "users" -and $Filter -like "startswith*")
    {
        # Extract search term from complex filter
        $searchTerm = ""
        if ($Filter -match "startswith\(givenName, '(.+?)'\)")
        {
            $searchTerm = $Matches[1]
        }
        elseif ($Filter -match "startswith\(surname, '(.+?)'\)")
        {
            $searchTerm = $Matches[1]
        }
        
        Write-Verbose "[MockGraphAPI] User fuzzy search for: $searchTerm"
        $matching = $script:MockUsers.Values | Where-Object { 
            $_.givenName -like "$searchTerm*" -or $_.surname -like "$searchTerm*" 
        } | Sort-Object userPrincipalName
        
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#users'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search: groups?$search="displayName:term"
    if ($ResourcePath -eq "groups" -and $ExtraParameters -like "*search=*")
    {
        $searchTerm = [uri]::UnescapeDataString(($ExtraParameters -replace '.*search=([^&]+).*', '$1'))
        $searchTerm = $searchTerm -replace '"displayName:(.+)"', '$1'
        Write-Verbose "[MockGraphAPI] Group search for: $searchTerm"
        
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "*$searchTerm*" } | Sort-Object displayName
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search: groups?$filter=startsWith(displayName, 'term')
    if ($ResourcePath -eq "groups" -and $Filter -like "startsWith*")
    {
        $searchTerm = ($Filter -replace "startsWith\(displayName, '(.+?)'\)", '$1').Trim()
        Write-Verbose "[MockGraphAPI] Group startsWith search for: $searchTerm"
        
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "$searchTerm*" } | Sort-Object displayName
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }
    
    # Group fuzzy search: groups?$filter=contains(displayName, 'term')
    if ($ResourcePath -eq "groups" -and $Filter -like "contains*")
    {
        $searchTerm = ($Filter -replace "contains\(displayName, '(.+?)'\)", '$1').Trim()
        Write-Verbose "[MockGraphAPI] Group contains search for: $searchTerm"
        
        $matching = $script:MockGroups.Values | Where-Object { $_.displayName -like "*$searchTerm*" } | Sort-Object displayName
        return [PSCustomObject]@{
            '@odata.context' = 'https://graph.microsoft.com/v1.0/$metadata#groups'
            value            = @($matching)
        }
    }

    # POST to importedWindowsAutopilotDeviceIdentities
    if ($ResourcePath -eq "deviceManagement/importedWindowsAutopilotDeviceIdentities" -and $Method -eq "POST")
    {
        $bodyJson = $Body | ConvertFrom-Json
        $serial = $bodyJson.serialNumber
        $userId = $bodyJson.assignedUserPrincipalName

        # Basic validation
        if (-not $script:MockDevices.ContainsKey($serial))
        {
            Write-Warning "[MockGraphAPI] Device with serial '$serial' not found in mock data."
            return 404
        }
        if (-not [string]::IsNullOrEmpty($userId) -and -not $script:MockUsers.ContainsKey($userId))
        {
            Write-Warning "[MockGraphAPI] User with UPN '$userId' not found in mock data."
            return 400 # Bad Request
        }

        $importId = "import-id-$([guid]::NewGuid().ToString().Substring(0,8))"
        $newImport = @{
            id                        = $importId
            serialNumber              = $serial
            assignedUserPrincipalName = $userId
            state                     = @{
                deviceImportStatus = 'complete' # Simulate immediate completion for tests
            }
        }
        $script:MockImportedDevices[$importId] = $newImport
        $script:MockDeviceAssignments[$($script:MockDevices[$serial].id)] = $userId

        return $newImport
    }

    # GET for importedWindowsAutopilotDeviceIdentities/{id}
    if ($ResourcePath -like "deviceManagement/importedWindowsAutopilotDeviceIdentities/*" -and $Method -eq "GET")
    {
        $importId = $ResourcePath.Split('/')[-1]
        if ($script:MockImportedDevices.ContainsKey($importId))
        {
            return $script:MockImportedDevices[$importId]
        }
        return 404
    }

    # GET for windowsAutopilotDeploymentProfiles (list all profiles)
    if ($ResourcePath -like "*deviceManagement/windowsAutopilotDeploymentProfiles*" -and $Method -eq "GET" -and $ResourcePath -notlike "*/assignments")
    {
        $profiles = @()
        foreach ($profile in $script:MockProfiles.GetEnumerator())
        {
            $profiles += @{
                id          = $profile.Value.id
                displayName = $profile.Value.displayName
            }
        }
        return @{ value = $profiles }
    }

    # GET for windowsAutopilotDeploymentProfiles/{id}/assignments
    if ($ResourcePath -like "*windowsAutopilotDeploymentProfiles/*/assignments" -and $Method -eq "GET")
    {
        $profileId = ($ResourcePath -split '/')[-2]
        $assignments = @()
        foreach ($assignment in $script:MockProfileAssignments.GetEnumerator())
        {
            if ($assignment.Name -eq $profileId)
            {
                $assignments += $assignment.Value
            }
        }
        return @{ value = $assignments }
    }
    
    # POST for $batch requests
    if ($ResourcePath -eq '$batch' -and $Method -eq "POST")
    {
        # Parse body if it's a JSON string
        $bodyObject = if ($Body -is [string])
        {
            $Body | ConvertFrom-Json
        }
        else
        {
            $Body
        }
        
        $responses = @()
        foreach ($request in $bodyObject.requests)
        {
            $batchResourcePath = $request.url
            $batchMethod = if ($request.method) { $request.method } else { 'GET' }
            
            # Recursively call Invoke-MockGraphAPI for each batch request
            $batchResult = Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $batchResourcePath -Method $batchMethod
            
            $response = @{
                id     = $request.id
                status = 200
                body   = $batchResult
            }
            $responses += $response
        }
        return @{ responses = $responses }
    }
    
    # Default: not found
    Write-Verbose "[MockGraphAPI] No matching mock found, returning 404"
    return 404
}

#endregion

#region Test Environment Helpers

<#
.SYNOPSIS
    Initializes mock environment for Graph API testing

.DESCRIPTION
    Sets up global variables and functions required for testing directory object functions.
    Includes Write-Log mock, return values, settings, and cache initialization.

.PARAMETER ReturnValues
    Custom return values hashtable (uses defaults if not provided)

.PARAMETER Settings
    Custom settings hashtable (uses defaults if not provided)

.PARAMETER ClearCache
    Clear the DirectoryObjectCache

.EXAMPLE
    Initialize-GraphMockEnvironment -ClearCache
#>
function Initialize-GraphMockEnvironment
{
    [CmdletBinding()]
    param(
        [hashtable]$ReturnValues,
        [hashtable]$Settings,
        [switch]$ClearCache
    )
    
    # Default return values
    $defaultReturnValues = @{
        noUserFoundInDirectoryMessage = "User not found in directory"
        noGroupFoundMessage           = "Group not found"
        noAccessTokenMessage          = "Access token is required"
        backoutText                   = "Back"
        mainMenuText                  = "Main Menu"
        exitText                      = "Exit"
    }
    
    # Default settings
    $defaultSettings = @{
        userPatternsToExclude  = @("admin", "test")
        groupPatternsToExclude = @("Archive", "Disabled")
        maxUserMatchDisplay    = 10
        maxGroupMatchDisplay   = 10
    }
    
    # Set global variables
    $global:returnValues = if ($ReturnValues) { $ReturnValues } else { $defaultReturnValues }
    $global:settings = if ($Settings) { $Settings } else { $defaultSettings }
    
    # Initialize or clear cache
    if ($ClearCache -or -not (Get-Variable -Name DirectoryObjectCache -Scope Global -ErrorAction SilentlyContinue))
    {
        $global:DirectoryObjectCache = @{}
    }
    
    # Mock Write-Log if not already defined
    if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue))
    {
        function global:Write-Log
        {
            param($LogFile, $Module, $Message, $LogLevel)
            # Silent mock
        }
    }
}

<#
.SYNOPSIS
    Cleans up mock environment

.DESCRIPTION
    Removes global variables and functions created during testing

.EXAMPLE
    Clear-GraphMockEnvironment
#>
function Clear-GraphMockEnvironment
{
    [CmdletBinding()]
    param()
    
    # Remove global variables
    if (Get-Variable -Name DirectoryObjectCache -Scope Global -ErrorAction SilentlyContinue)
    {
        Remove-Variable -Name DirectoryObjectCache -Scope Global -Force
    }
    
    if (Get-Variable -Name returnValues -Scope Global -ErrorAction SilentlyContinue)
    {
        Remove-Variable -Name returnValues -Scope Global -Force
    }
    
    if (Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue)
    {
        Remove-Variable -Name settings -Scope Global -Force
    }
    Clear-MockDeviceAssignments
    Clear-MockProfileAssignments
}

#endregion

#region Device Mocks

# Default mock device data
$script:DefaultMockDevices = @{
    "DEVICE001" = @{
        serialNumber      = "DEVICE001"
        deviceName        = "WIN11-DEVICE001"
        id                = "device-001"
        manufacturer      = "Microsoft Corporation"
        model             = "Surface Laptop 4"
        operatingSystem   = "Windows 11"
        osVersion         = "10.0.22000.795"
        enrollmentState   = "enrolled"
        managementState   = "managed"
        azureADDeviceId   = "azuread-device-001"
        autopilotEnrolled = $true
        groupTag          = "Corporate"
        userPrincipalName = "john.doe@contoso.com"
    }
    "DEVICE002" = @{
        serialNumber      = "DEVICE002"
        deviceName        = "WIN11-DEVICE002"
        id                = "device-002"
        manufacturer      = "Dell Inc."
        model             = "Latitude 7420"
        operatingSystem   = "Windows 11"
        osVersion         = "10.0.22000.795"
        enrollmentState   = "enrolled"
        managementState   = "managed"
        azureADDeviceId   = "azuread-device-002"
        autopilotEnrolled = $true
        groupTag          = "IT"
        userPrincipalName = $null
    }
}

# Active mock device data
$script:MockDevices = $script:DefaultMockDevices.Clone()

<#
.SYNOPSIS
    Adds a mock device to the test data

.PARAMETER SerialNumber
    The serial number of the device

.PARAMETER DeviceName
    The device name

.PARAMETER Manufacturer
    Device manufacturer

.PARAMETER Model
    Device model

.PARAMETER GroupTag
    Autopilot group tag

.PARAMETER UserPrincipalName
    Primary user UPN

.PARAMETER Id
    Optional custom ID (auto-generated if not provided)

.EXAMPLE
    Add-MockDevice -SerialNumber "TEST001" -DeviceName "WIN11-TEST001" -Manufacturer "HP" -Model "EliteBook"
#>
function Add-MockDevice
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SerialNumber,
        
        [Parameter(Mandatory)]
        [string]$DeviceName,
        
        [string]$Manufacturer = "Unknown",
        [string]$Model = "Unknown",
        [string]$GroupTag = $null,
        [string]$UserPrincipalName = $null,
        [string]$Id = "device-$([guid]::NewGuid().ToString().Substring(0, 8))"
    )
    
    $script:MockDevices[$SerialNumber] = @{
        serialNumber      = $SerialNumber
        deviceName        = $DeviceName
        id                = $Id
        manufacturer      = $Manufacturer
        model             = $Model
        operatingSystem   = "Windows 11"
        osVersion         = "10.0.22000.795"
        enrollmentState   = "enrolled"
        managementState   = "managed"
        azureADDeviceId   = "azuread-$Id"
        autopilotEnrolled = $true
        groupTag          = $GroupTag
        userPrincipalName = $UserPrincipalName
    }
}

<#
.SYNOPSIS
    Gets mock device data

.EXAMPLE
    $devices = Get-MockDevices
#>
function Get-MockDevices
{
    [CmdletBinding()]
    param()
    
    return $script:MockDevices
}

<#
.SYNOPSIS
    (Mock) Assigns a user to a device.
#>
function Add-MockDeviceUserAssignment
{
    param(
        [string]$DeviceId,
        [string]$UserId
    )
    $script:MockDeviceAssignments[$DeviceId] = $UserId
    Write-Verbose "[MockGraphAPI] Assigned user $UserId to device $DeviceId"
}

<#
.SYNOPSIS
    (Mock) Gets user assignments for a device.
#>
function Get-MockDeviceUserAssignments
{
    param([string]$DeviceId)
    return $script:MockDeviceAssignments[$DeviceId]
}

<#
.SYNOPSIS
    Clears all mock device assignments.
#>
function Clear-MockDeviceAssignments
{
    $script:MockDeviceAssignments.Clear()
    $script:MockImportedDevices.Clear()
}


#endregion

#region Autopilot Profile Mocks

# Default mock Autopilot profile data
$script:DefaultMockProfiles = @{
    "Corporate-Profile" = @{
        displayName                    = "Corporate-Profile"
        id                             = "profile-001"
        description                    = "Standard corporate deployment profile"
        deviceNameTemplate             = "CORP-%SERIAL%"
        enableWhiteGlove               = $false
        outOfBoxExperienceSettings     = @{
            hidePrivacySettings       = $true
            hideEULA                  = $true
            userType                  = "standard"
            deviceUsageType           = "shared"
            skipKeyboardSelectionPage = $true
            hideEscapeLink            = $true
        }
        enrollmentStatusScreenSettings = @{
            hideInstallationProgress                         = $false
            allowDeviceUseBeforeProfileAndAppInstallComplete = $false
            blockDeviceSetupRetryByUser                      = $true
        }
    }
    "IT-Profile"        = @{
        displayName                    = "IT-Profile"
        id                             = "profile-002"
        description                    = "IT department deployment profile"
        deviceNameTemplate             = "IT-%SERIAL%"
        enableWhiteGlove               = $true
        outOfBoxExperienceSettings     = @{
            hidePrivacySettings       = $true
            hideEULA                  = $true
            userType                  = "administrator"
            deviceUsageType           = "single"
            skipKeyboardSelectionPage = $true
            hideEscapeLink            = $false
        }
        enrollmentStatusScreenSettings = @{
            hideInstallationProgress                         = $false
            allowDeviceUseBeforeProfileAndAppInstallComplete = $false
            blockDeviceSetupRetryByUser                      = $false
        }
    }
}

# Active mock profile data
$script:MockProfiles = $script:DefaultMockProfiles.Clone()

<#
.SYNOPSIS
    Adds a mock Autopilot profile to the test data

.PARAMETER DisplayName
    The display name of the profile

.PARAMETER DeviceNameTemplate
    Device naming template

.PARAMETER EnableWhiteGlove
    Enable white glove provisioning

.PARAMETER Description
    Profile description

.PARAMETER Id
    Optional custom ID (auto-generated if not provided)

.EXAMPLE
    Add-MockAutopilotProfile -DisplayName "Test-Profile" -DeviceNameTemplate "TEST-%SERIAL%"
#>
function Add-MockAutopilotProfile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,
        
        [string]$DeviceNameTemplate = "%SERIAL%",
        [bool]$EnableWhiteGlove = $false,
        [string]$Description = "Test profile",
        [string]$Id = "profile-$([guid]::NewGuid().ToString().Substring(0, 8))"
    )
    
    $script:MockProfiles[$DisplayName] = @{
        displayName                    = $DisplayName
        id                             = $Id
        description                    = $Description
        deviceNameTemplate             = $DeviceNameTemplate
        enableWhiteGlove               = $EnableWhiteGlove
        outOfBoxExperienceSettings     = @{
            hidePrivacySettings       = $true
            hideEULA                  = $true
            userType                  = "standard"
            deviceUsageType           = "shared"
            skipKeyboardSelectionPage = $true
            hideEscapeLink            = $true
        }
        enrollmentStatusScreenSettings = @{
            hideInstallationProgress                         = $false
            allowDeviceUseBeforeProfileAndAppInstallComplete = $false
            blockDeviceSetupRetryByUser                      = $true
        }
    }
}

<#
.SYNOPSIS
    Gets mock Autopilot profile data

.EXAMPLE
    $profiles = Get-MockAutopilotProfiles
#>
function Get-MockAutopilotProfiles
{
    [CmdletBinding()]
    param()
    
    return $script:MockProfiles
}

<#
.SYNOPSIS
    (Mock) Assigns a profile to a target.
#>
function Add-MockProfileAssignment
{
    param(
        [string]$ProfileId,
        [string]$TargetId,
        [ValidateSet('Device', 'Group')]
        [string]$TargetType = 'Group'
    )
    $assignment = @{
        target = @{
            '@odata.type' = "#microsoft.graph.groupAssignmentTarget"
            groupId       = $TargetId
        }
    }
    $script:MockProfileAssignments[$ProfileId] = $assignment
}

<#
.SYNOPSIS
    (Mock) Gets assignments for a profile.
#>
function Get-MockProfileAssignments
{
    param([string]$ProfileId)
    return $script:MockProfileAssignments[$ProfileId]
}

<#
.SYNOPSIS
    Clears all mock profile assignments.
#>
function Clear-MockProfileAssignments
{
    $script:MockProfileAssignments.Clear()
}

#endregion

#region Authentication Token Mocks

<#
.SYNOPSIS
    Creates a mock authentication token

.PARAMETER TokenType
    Type of token (e.g., "Bearer", "Certificate")

.PARAMETER ExpiresIn
    Token expiration time in seconds (default: 3600)

.EXAMPLE
    $token = New-MockAuthToken
#>
function New-MockAuthToken
{
    [CmdletBinding()]
    param(
        [string]$TokenType = "Bearer",
        [int]$ExpiresIn = 3600
    )
    
    return @{
        access_token = "mock-token-$([guid]::NewGuid().ToString())"
        token_type   = $TokenType
        expires_in   = $ExpiresIn
        scope        = "User.Read Group.Read Device.Read"
        timestamp    = Get-Date
    }
}

<#
.SYNOPSIS
    Creates a mock JWT token for testing

.DESCRIPTION
    Generates a properly formatted JWT token string with customizable claims.
    The token can be decoded using DecodeJwtToken and contains valid Base64 encoding.

.PARAMETER Scopes
    Array of Microsoft Graph scopes/roles to include in the token

.PARAMETER CustomPayload
    Optional custom payload hashtable to use instead of default structure.
    Useful for testing specific token formats or edge cases.

.EXAMPLE
    $token = New-MockGraphToken -Scopes @('User.Read.All', 'Group.Read.All')

.EXAMPLE
    $token = New-MockGraphToken -CustomPayload @{
        roles = 'User.Read.All, Group.Read.All'
        aud = 'https://graph.microsoft.com'
    }
#>
function New-MockGraphToken
{
    [CmdletBinding()]
    param(
        [string[]]$Scopes = @(),
        [hashtable]$CustomPayload,
        [switch]$Delegated
    )
    
    # Create payload
    if ($CustomPayload)
    {
        $payload = $CustomPayload
    }
    else
    {
        $payload = @{
            aud = 'https://graph.microsoft.com'
            iss = 'https://sts.windows.net/test-tenant-id/'
            exp = ([DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds())
            iat = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            nbf = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            tid = 'test-tenant-id'
            ver = '2.0'
        }
        
        # Add scopes based on auth type
        if ($Delegated)
        {
            # Delegated auth: scp claim (space-separated string)
            $payload.scp = $Scopes -join ' '
        }
        else
        {
            # Application auth: roles claim (array)
            $payload.roles = $Scopes
        }
    }
    
    # Convert payload to JSON
    $payloadJson = $payload | ConvertTo-Json -Compress
    
    # Base64 encode the payload (JWT format)
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
    $payloadBase64 = [System.Convert]::ToBase64String($payloadBytes)
    
    # URL-safe Base64 encoding (replace + with -, / with _, remove =)
    $payloadBase64 = $payloadBase64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
    
    # Create a simple header (we don't need to validate signature in tests)
    $header = @{
        alg = 'RS256'
        typ = 'JWT'
    } | ConvertTo-Json -Compress
    
    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)
    $headerBase64 = [System.Convert]::ToBase64String($headerBytes)
    $headerBase64 = $headerBase64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
    
    # Create mock signature (not validated in tests)
    $signature = 'mock-signature'
    
    # Combine parts with dots
    return "$headerBase64.$payloadBase64.$signature"
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Add-MockUser',
    'Add-MockGroup',
    'Add-MockDevice',
    'Add-MockAutopilotProfile',
    'Reset-MockData',
    'Get-MockUsers',
    'Get-MockGroups',
    'Get-MockDevices',
    'Get-MockAutopilotProfiles',
    'New-MockAuthToken',
    'New-MockGraphToken',
    'Invoke-MockGraphAPI',
    'Initialize-GraphMockEnvironment',
    'Clear-GraphMockEnvironment',
    'Add-MockDeviceUserAssignment',
    'Get-MockDeviceUserAssignments',
    'Clear-MockDeviceAssignments',
    'Add-MockProfileAssignment',
    'Get-MockProfileAssignments',
    'Clear-MockProfileAssignments'
)

