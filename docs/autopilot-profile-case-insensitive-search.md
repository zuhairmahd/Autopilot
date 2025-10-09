# Autopilot Profile Case-Insensitive Search Enhancement

## Overview
Enhanced the Autopilot profile search functionality to work around Microsoft Graph API case-sensitivity limitations and provide better user experience when searching for profiles.

## Problems Addressed

### 1. Case-Sensitivity Issues
**Problem**: Microsoft Graph API filters (`contains`, `startswith`) were not consistently handling case-insensitive searches for Autopilot profiles. A search for "corporate" would not find "Corporate Profile".

**Research Findings**:
- Microsoft documentation indicates string comparisons should be case-insensitive by default, but this varies by endpoint
- Using `tolower()`/`toupper()` OData functions is NOT recommended and may not work reliably
- The `$search` parameter is inherently case-insensitive but may not be available for all endpoints
- Client-side filtering is the most reliable approach when API filters fail

### 2. Limited Search Options
**Problem**: Users had no way to browse all available Autopilot profiles when search failed, forcing them to guess profile names or skip profiles.

## Solution Implemented

### Three-Tier Search Strategy

#### Tier 1: Exact Match (Fastest)
- Uses OData `eq` filter for exact profile name match
- Leverages caching for performance
- Returns immediately if found

#### Tier 2: Similarity Search (API-based)
- Uses `startswith` and `contains` OData filters
- Attempts multiple filter strategies
- Includes deduplication and result filtering

#### Tier 3: Client-Side Filtering (Fallback)
- **NEW**: When API filters fail, retrieves ALL Autopilot profiles
- Performs case-insensitive filtering in PowerShell using `.ToLower()` comparisons
- Most reliable approach for handling case variations
- Example: Searching for "corp" will match "Corporate Profile", "Corp-Dept", "CORP-IT", etc.

### Enhanced User Experience

#### New "View All Profiles" Menu Option
When no profiles are found matching a search:
1. **Try different profile name** - Search again with new name
2. **View all Autopilot profiles** - *NEW* Browse complete list of profiles
3. **Save profile name without ID** - Defer ID resolution
4. **Skip this profile** - Continue without adding profile

#### Backward Compatibility
- All existing callers continue to work without changes
- Silent mode (`-Silent` parameter) preserved for automation
- Return value structure unchanged

## Technical Implementation

### GetAutopilotProfile.ps1 Changes

#### 1. Added `-GetAll` Parameter
```powershell
function GetAutopilotProfile() {
    param (
        [string]$AccessToken,
        [string]$ProfileName,
        [switch]$FindSimilar,
        [switch]$GetAll  # NEW
    )
}
```

**Purpose**: Retrieve all Autopilot profiles without filtering for browsing scenarios.

**Usage**:
```powershell
$result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $token -GetAll
```

#### 2. Client-Side Case-Insensitive Filtering
When API-based similarity search fails:
```powershell
# Retrieve all profiles
$allProfilesResult = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri ...

# Filter client-side using PowerShell case-insensitive comparison
$searchTermLower = $searchTerm.ToLower()
foreach ($profile in $allProfilesResult.value) {
    $displayNameLower = $profile.displayName.ToLower()
    if ($displayNameLower.Contains($searchTermLower)) {
        $matchedProfiles += $profile
    }
}
```

**Benefits**:
- 100% reliable case-insensitive matching
- Works around Graph API limitations
- No dependency on OData function support

### Show-AutopilotProfilesEditor.ps1 Changes

#### Enhanced Menu in Resolve-SingleAutopilotProfileInteractive
When no matches found, added option "2. View all Autopilot profiles":

```powershell
'2' {
    # Retrieve and display all profiles
    $allProfilesResult = GetAutopilotProfile -AccessToken $AccessToken -GetAll
    
    # Display numbered list
    for ($i = 0; $i -lt $allProfilesResult.value.Count; $i++) {
        Write-Host "    $($i + 1). $($profile.displayName) (ID: $($profile.id))"
    }
    
    # Let user select from list
    $profileChoice = Read-Host "Select profile (0-$count)"
    # Handle selection...
}
```

## Usage Examples

### Example 1: Automatic Case-Insensitive Fallback
```powershell
# User searches for "corporate" (lowercase)
$result = Resolve-SingleAutopilotProfileInteractive -ProfileName "corporate" -AccessToken $token

# Search progression:
# 1. Tries exact match: "corporate" (fails)
# 2. Tries API contains filter: "corporate" (may fail due to case)
# 3. Retrieves all profiles and filters client-side (succeeds)
# 4. Finds: "Corporate Profile", "Corporate-IT", etc.
```

### Example 2: Browse All Profiles
```powershell
# User doesn't know exact profile name
# 1. Searches for "test" - no matches found
# 2. Menu appears with option "2. View all Autopilot profiles"
# 3. User selects option 2
# 4. All profiles displayed in numbered list
# 5. User browses and selects "Production-Deployment-Profile"
```

### Example 3: Silent Mode (Automation)
```powershell
# Automated migration scenario
$profiles = @("Corporate", "DEPARTMENT", "it-group")
foreach ($profileName in $profiles) {
    $resolved = Resolve-SingleAutopilotProfileInteractive `
        -ProfileName $profileName `
        -AccessToken $token `
        -Silent
    # Client-side filtering handles case variations automatically
}
```

## Performance Considerations

### Caching Strategy
- Exact matches are cached with key: `"ProfileName|False"`
- Similarity searches are cached with key: `"ProfileName|True"`
- All-profiles requests are NOT cached (may change frequently)
- Cache persists for PowerShell session lifetime

### Network Efficiency
- Exact match: 1 API call (best case)
- Similarity search: 2-3 API calls (typical case)
- Client-side fallback: 1 additional API call to get all profiles
- All-profiles browsing: 1 API call

### Best Practices
1. Provide accurate profile names when possible (uses fast exact match)
2. Use descriptive search terms for similarity search
3. Browse all profiles as last resort (retrieves most data)

## Testing Recommendations

### Test Scenarios
1. **Case variations**: Search for "CORPORATE", "corporate", "Corporate"
2. **Partial matches**: Search for "corp" to find "Corporate Profile"
3. **No matches**: Verify menu appears with "View all" option
4. **All profiles**: Test browsing complete profile list
5. **Duplicates**: Verify duplicate detection works across all search modes
6. **Silent mode**: Confirm automation scenarios still work

### Test Commands
```powershell
# Test case-insensitive search
$result = Resolve-SingleAutopilotProfileInteractive -ProfileName "corporate" -AccessToken $token -Verbose

# Test get all profiles
$allProfiles, $_ = GetAutopilotProfile -AccessToken $token -GetAll

# Test silent mode with case variation
$result = Resolve-SingleAutopilotProfileInteractive -ProfileName "CORPORATE" -AccessToken $token -Silent
```

## Related Functions

### Modified Functions
- `GetAutopilotProfile` - Added client-side filtering and `-GetAll` parameter
- `Resolve-SingleAutopilotProfileInteractive` - Added "View all profiles" menu option

### Dependent Functions
- `CallGraphAPI` - Used for all Graph API calls
- `Test-ItemExists` - Used for duplicate detection
- `Resolve-MigratedAutopilotProfiles` - Calls `Resolve-SingleAutopilotProfileInteractive`

## Documentation Updates
- Updated `GetAutopilotProfile` function documentation
- Added `.PARAMETER GetAll` documentation
- Added examples for new functionality
- Updated notes about case-insensitive handling

## Future Enhancements
1. Consider adding pagination for very large profile lists (> 100 profiles)
2. Add profile search within "View all" mode (client-side filtering)
3. Cache all-profiles result with TTL for better performance
4. Add profile sorting options (by name, by date, etc.)
5. Consider adding profile description/metadata display in list view
