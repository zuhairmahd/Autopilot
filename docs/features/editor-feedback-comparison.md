# Side-by-Side Comparison: Groups vs Autopilot Profiles Feedback

## User Experience Comparison

Both editors now provide identical feedback patterns:

### Choice Prompt (via Get-EditorReplaceOrAddChoice)

**Groups Editor:**
```
You have existing group in this list.
Do you want to:
  1. Replace all existing group with new ones
  2. Add new group to the existing ones
  3. Keep current group unchanged
Enter your choice (1-3):
```

**Autopilot Profiles Editor:**
```
You have existing profile in this list.
Do you want to:
  1. Replace all existing profile with new ones
  2. Add new profile to the existing ones
  3. Keep current profile unchanged
Enter your choice (1-3):
```

### Confirmation Message

**Groups:**
```
[*] You chose: REPLACE all existing group
  -> All current group will be removed
  -> Only new group you enter will be saved
```

**Profiles:**
```
[*] You chose: REPLACE all existing profile
  -> All current profile will be removed
  -> Only new profile you enter will be saved
```

### Mode Banner - REPLACE

**Groups:**
```
=======================================
  MODE: REPLACE - Old groups will be removed
=======================================
```

**Profiles:**
```
=======================================
  MODE: REPLACE - Old profiles will be removed
=======================================
```

### Mode Banner - ADD

**Groups:**
```
=======================================
  MODE: ADD - New groups will be added
=======================================
```

**Profiles:**
```
=======================================
  MODE: ADD - New profiles will be added
=======================================
```

### Input Instructions - REPLACE

**Groups:**
```
[!] REPLACE MODE: Enter new groups (old groups will be removed)
   * Enter group names one per line
   * Group names will be searched and resolved interactively
   * Press Enter on empty line to finish
   * Leave first line empty to cancel
```

**Profiles:**
```
[!] REPLACE MODE: Enter new profiles (old profiles will be removed)
   * Enter profile names one per line
   * Profile names will be searched and resolved interactively
   * Press Enter on empty line to finish
   * Leave first line empty to cancel
```

### Input Instructions - ADD

**Groups:**
```
[+] ADD MODE: Enter new groups (old groups will be kept)
   * Enter group names one per line
   * Group names will be searched and resolved interactively
   * Press Enter on empty line to finish
   * Leave first line empty to cancel
```

**Profiles:**
```
[+] ADD MODE: Enter new profiles (old profiles will be kept)
   * Enter profile names one per line
   * Profile names will be searched and resolved interactively
   * Press Enter on empty line to finish
   * Leave first line empty to cancel
```

### Summary - REPLACE Mode

**Groups:**
```
=======================================
  SUMMARY - REPLACE MODE
=======================================
Old groups (2): REMOVED
New groups (1): WILL BE SAVED
```

**Profiles:**
```
=======================================
  SUMMARY - REPLACE MODE
=======================================
Old profiles (2): REMOVED
New profiles (1): WILL BE SAVED
```

### Summary - ADD Mode

**Groups:**
```
=======================================
  SUMMARY - ADD MODE
=======================================
Old groups (2): KEPT
New groups (1): ADDED
Total groups: 3
```

**Profiles:**
```
=======================================
  SUMMARY - ADD MODE
=======================================
Old profiles (2): KEPT
New profiles (1): ADDED
Total profiles: 3
```

### Keep Unchanged

**Groups:**
```
=======================================
  NO CHANGES - Keeping 2 existing groups
=======================================
```

**Profiles:**
```
=======================================
  NO CHANGES - Keeping 2 existing profiles
=======================================
```

## Key Observations

1. **Perfect Pattern Consistency**: Only difference is the item type name ("group" vs "profile")
2. **Number-Neutral Language**: Works naturally in all contexts without awkward singular/plural handling
3. **Visual Hierarchy**: Same color coding across both editors
4. **Clear Expectations**: Users know exactly what to expect regardless which editor they use
5. **ASCII Compatibility**: Both use identical ASCII characters for PowerShell 5.1 support

## Code Implementation Consistency

Both functions now follow the same structure:

1. Detect current format
2. Call `Get-EditorReplaceOrAddChoice` with appropriate ItemType
3. Check `$decision.ShouldProceed`
4. Display mode banner
5. Show current items
6. Display mode-specific instructions
7. Collect input with duplicate checking
8. Show summary before returning
9. Handle keep unchanged case with banner

This consistency makes the codebase more maintainable and provides users with a predictable, familiar experience.
