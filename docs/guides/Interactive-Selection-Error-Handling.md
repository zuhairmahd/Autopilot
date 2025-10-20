# Interactive Selection Error Handling

## Overview
The `Select-ItemsFromList` function now includes robust error handling with automatic reprompting for invalid selections, ensuring users can correct mistakes without restarting the entire process.

## New Behavior

### Automatic Reprompting
When users enter invalid selections, the system:
1. ✅ Displays clear error messages
2. ✅ Automatically reprompts for input
3. ✅ Continues until valid selection or quit
4. ✅ No need to restart the script

### Previous Behavior (Before Enhancement)
```powershell
Selection: 999
Invalid selection: 999 (out of range)
No valid items selected
# Script exits, need to run again
```

### New Behavior (After Enhancement)
```powershell
Selection: 999
Invalid selection: 999 (out of range 1-50)
No valid items selected. Please try again or enter 'q' to quit.
Selection: 5,10,15
Selected 3 item(s)
# Continues successfully!
```

## Error Scenarios Handled

### 1. Out of Range Numbers
**User Input:** Number outside valid range

**Example:**
```
Available items: 1-10

Selection: 15
Invalid selection: 15 (out of range 1-10)
No valid items selected. Please try again or enter 'q' to quit.
Selection: 5
Selected 1 item(s)
```

### 2. Non-Numeric Input
**User Input:** Letters or special characters

**Example:**
```
Selection: abc
Invalid input: 'abc' (not a number)
No valid items selected. Please try again or enter 'q' to quit.
Selection: 3
Selected 1 item(s)
```

### 3. Empty Input
**User Input:** Just pressing Enter

**Example:**
```
Selection: 
No selection entered. Please try again or enter 'q' to quit.
Selection: 1,2,3
Selected 3 item(s)
```

### 4. Mixed Valid/Invalid Input
**User Input:** Combination of valid and invalid numbers

**Example:**
```
Selection: 1,999,5,abc,10
Invalid selection: 999 (out of range 1-50)
Invalid input: 'abc' (not a number)
Selected 3 item(s)
# Successfully continues with valid selections (1, 5, 10)
```

### 5. All Invalid Input
**User Input:** All entries are invalid

**Example:**
```
Selection: 999,888,777
Invalid selection: 999 (out of range 1-50)
Invalid selection: 888 (out of range 1-50)
Invalid selection: 777 (out of range 1-50)
No valid items selected. Please try again or enter 'q' to quit.
Selection: 1,2,3
Selected 3 item(s)
```

## User Experience Improvements

### Clear Error Messages
Each error message includes:
- ✅ **What was wrong:** "Invalid selection" or "Invalid input"
- ✅ **Why it was wrong:** "(out of range 1-10)" or "(not a number)"
- ✅ **How to proceed:** "Please try again or enter 'q' to quit"

### Helpful Range Information
Error messages now show the valid range:
- Before: `Invalid selection: 999 (out of range)`
- After: `Invalid selection: 999 (out of range 1-50)`

### Partial Success Handling
When mixing valid and invalid selections:
- ✅ Shows errors for invalid items
- ✅ Successfully processes valid items
- ✅ Continues with valid selections without reprompting

### Quit Anytime
Users can always escape by entering `q`:
```
Selection: oops, wrong choice
Invalid input: 'oops' (not a number)
Invalid input: 'wrong choice' (not a number)
No valid items selected. Please try again or enter 'q' to quit.
Selection: q
Selection canceled
# Exits gracefully
```

## Interactive Workflows

### Workflow 1: Typo Recovery
```powershell
.\Invoke-PesterTests.ps1 -TestFile ""

===============================================================
  Available Test Files
===============================================================
  [1] AppMode.Tests.ps1
  [2] Authentication.Tests.ps1
  ...
  [50] Settings.Tests.ps1

Selection: 5,10,155    # Typo: 155 instead of 15
Invalid selection: 155 (out of range 1-50)

# User sees error immediately
Selection: 5,10,15     # Corrects to 15
Selected 3 item(s)
# Continues successfully
```

### Workflow 2: Learning Valid Range
```powershell
Selection: 100
Invalid selection: 100 (out of range 1-23)
# User now knows valid range is 1-23
No valid items selected. Please try again or enter 'q' to quit.

Selection: 20
Selected 1 item(s)
```

### Workflow 3: Multiple Attempts
```powershell
Selection: abc       # First mistake
Invalid input: 'abc' (not a number)
No valid items selected. Please try again or enter 'q' to quit.

Selection: 999       # Second mistake
Invalid selection: 999 (out of range 1-50)
No valid items selected. Please try again or enter 'q' to quit.

Selection: 5         # Success!
Selected 1 item(s)
```

### Workflow 4: Escape Hatch
```powershell
Selection: 1,2,3,4,5,6,7,8,9,10
# Oops, selected too many!

Selection: q         # Can quit and start over
Selection canceled
```

## Technical Implementation

### Loop Structure
```powershell
$validSelection = $false
$selectedItems = @()

while (-not $validSelection)
{
    $choice = Read-Host "Selection"
    
    # Process input...
    
    if ($selectedItems.Count -gt 0)
    {
        $validSelection = $true  # Exit loop
    }
    else
    {
        # Reprompt with helpful message
    }
}
```

### Error Detection
```powershell
$hasErrors = $false

foreach ($num in $numbers)
{
    try
    {
        $index = [int]$num - 1
        if ($index -ge 0 -and $index -lt $Items.Count)
        {
            $selectedItems += $Items[$index]
        }
        else
        {
            Write-Host "Invalid selection: $num (out of range 1-$($Items.Count))" -ForegroundColor Red
            $hasErrors = $true
        }
    }
    catch
    {
        Write-Host "Invalid input: '$num' (not a number)" -ForegroundColor Red
        $hasErrors = $true
    }
}
```

### Reprompt Logic
```powershell
if ($selectedItems.Count -gt 0)
{
    # Valid selections found - exit loop
    $validSelection = $true
}
elseif (-not $hasErrors)
{
    # Empty input - specific message
    Write-Host "No selection entered. Please try again or enter 'q' to quit." -ForegroundColor Yellow
}
else
{
    # Had errors but no valid selections
    Write-Host "No valid items selected. Please try again or enter 'q' to quit." -ForegroundColor Yellow
}
```

## Benefits

### 1. User-Friendly
- No need to restart script after mistakes
- Clear, actionable error messages
- Learn valid range from error messages

### 2. Efficient
- Fix typos immediately
- No wasted time restarting
- Partial success handling (mixed valid/invalid)

### 3. Robust
- Handles all error types gracefully
- Prevents script crashes
- Always provides escape hatch (quit)

### 4. Consistent
- Same error handling for files and tags
- Unified UX across all selection scenarios
- Predictable behavior

## Comparison with Other Functions

### Other Functions in Codebase
Many other interactive selections in the codebase don't reprompt:
- Select once, exit on error
- User must restart entire operation

### Select-ItemsFromList (Enhanced)
- Reprompts automatically on error
- User can correct mistakes
- Continues until success or explicit quit

**Result:** Better UX, fewer frustrations, faster workflows

## Testing Scenarios

### Test 1: Out of Range
```powershell
# Setup: Menu with 10 items
Selection: 15          # Out of range
Expected: Error + reprompt
Selection: 5           # Valid
Expected: Success + continue
```

### Test 2: Non-Numeric
```powershell
Selection: hello       # Not a number
Expected: Error + reprompt
Selection: 3           # Valid
Expected: Success + continue
```

### Test 3: Empty Input
```powershell
Selection:             # Empty
Expected: Specific message + reprompt
Selection: 1,2,3       # Valid
Expected: Success + continue
```

### Test 4: Mixed Input
```powershell
Selection: 1,abc,999,5 # Mixed
Expected: Errors for abc and 999, but success with 1 and 5
Result: Continues with valid selections
```

### Test 5: Multiple Retries
```powershell
Selection: 999         # Invalid
Selection: abc         # Invalid
Selection: 5           # Valid
Expected: Success after 3 attempts
```

### Test 6: Quit After Error
```powershell
Selection: 999         # Invalid
Selection: q           # Quit
Expected: Cancel + exit gracefully
```

## Error Message Design

### Principles
1. **Specific:** Tell exactly what went wrong
2. **Helpful:** Show valid range or expected format
3. **Actionable:** Tell user what to do next
4. **Consistent:** Same format for all error types

### Message Components

**For Out of Range:**
```
Invalid selection: {number} (out of range 1-{max})
```

**For Non-Numeric:**
```
Invalid input: '{input}' (not a number)
```

**For Empty:**
```
No selection entered. Please try again or enter 'q' to quit.
```

**For All Invalid:**
```
No valid items selected. Please try again or enter 'q' to quit.
```

## Integration with Existing Features

### Tag Selection
```powershell
.\Invoke-PesterTests.ps1 -Tags @()

Selection: 999         # Error + reprompt
Selection: 5,10,15     # Success
# Runs tests with selected tags
```

### File Selection
```powershell
.\Invoke-PesterTests.ps1 -TestFile ""

Selection: abc         # Error + reprompt
Selection: 1,5,10      # Success
# Runs selected test files
```

### Fuzzy Search
```powershell
.\Invoke-PesterTests.ps1 -TestFile "Config"

Selection: 100         # Error + reprompt
Selection: a           # Select all
# Runs all matched files
```

## Future Enhancements

Potential improvements to consider:

### 1. Smart Suggestions
```
Invalid selection: 155 (out of range 1-50)
Did you mean: 15?
```

### 2. Range Support
```
Selection: 1-5         # Select items 1 through 5
Currently: Not supported
Future: Parse range syntax
```

### 3. Maximum Retry Limit
```
After 5 invalid attempts:
"Multiple invalid attempts. Type 'help' for usage or 'q' to quit."
```

### 4. Help Command
```
Selection: help
Shows: Valid input format and examples
```

## Summary

The enhanced `Select-ItemsFromList` function provides:

✅ **Automatic reprompting** on invalid input  
✅ **Clear error messages** with valid ranges  
✅ **Partial success handling** for mixed input  
✅ **Empty input detection** with specific message  
✅ **Quit anytime** escape hatch  
✅ **Consistent UX** across all selection scenarios  

**Result:** More forgiving, user-friendly selection experience that reduces frustration and saves time.

## Quick Reference

| Scenario | Behavior | User Action |
|----------|----------|-------------|
| Out of range number | Error + reprompt | Enter valid number |
| Non-numeric input | Error + reprompt | Enter valid number |
| Empty input | Specific message + reprompt | Enter selection |
| Mixed valid/invalid | Process valid, show errors | Continues with valid |
| All invalid | Error + reprompt | Try again or quit |
| Want to quit | Cancel gracefully | Enter 'q' |

---

**Version:** 2.0 (Enhanced with Reprompting)  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready
