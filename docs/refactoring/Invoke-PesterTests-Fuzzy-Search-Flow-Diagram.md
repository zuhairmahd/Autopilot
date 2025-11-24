# Fuzzy Test File Search - Visual Flow

## Main Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│ User runs: .\Invoke-PesterTests.ps1 -TestFile "Settings"      │
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │ Is path rooted (absolute)?          │
         └────────────┬────────────────────────┘
                      │
         ┌────────────┴───────────┐
         │                        │
        Yes                      No
         │                        │
         ▼                        ▼
    ┌─────────┐          ┌──────────────┐
    │ Use as  │          │ Join with    │
    │ is      │          │ script path  │
    └────┬────┘          └──────┬───────┘
         │                      │
         └──────────┬───────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │ Does file exist?     │
         └────────┬─────────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
     Yes                     No
      │                       │
      ▼                       ▼
┌───────────┐      ┌────────────────────────┐
│ Run test  │      │ File not found!        │
│ with file │      │ Starting search...     │
└───────────┘      └───────────┬────────────┘
                               │
                               ▼
                ┌──────────────────────────────────┐
                │ Get all *.Tests.ps1 files        │
                │ from tests folder (recursive)    │
                └──────────────┬───────────────────┘
                               │
                               ▼
                ┌──────────────────────────────────┐
                │ Extract filename from search     │
                │ (e.g., "Settings")               │
                └──────────────┬───────────────────┘
                               │
                               ▼
                ┌──────────────────────────────────┐
                │ Find exact filename matches      │
                └──────────────┬───────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
         Exact match                      No exact match
              │                                 │
              ▼                                 ▼
    ┌──────────────────┐            ┌────────────────────┐
    │ Single or        │            │ Perform fuzzy      │
    │ Multiple?        │            │ search             │
    └────┬─────────────┘            └─────────┬──────────┘
         │                                    │
    ┌────┴─────┐                              │
    │          │                              │
  Single    Multiple                          │
    │          │                              │
    ▼          ▼                              ▼
┌────────┐  ┌──────────────┐    ┌──────────────────────┐
│ Use    │  │ Show exact   │    │ Score all files      │
│ auto   │  │ match menu   │    │ using algorithm      │
└───┬────┘  └──────┬───────┘    └──────────┬───────────┘
    │              │                        │
    │              │                        ▼
    │              │            ┌────────────────────────┐
    │              │            │ Any scores > 0?        │
    │              │            └─────────┬──────────────┘
    │              │                      │
    │              │           ┌──────────┴──────────┐
    │              │           │                     │
    │              │          Yes                   No
    │              │           │                     │
    │              │           ▼                     ▼
    │              │  ┌──────────────────┐   ┌────────────┐
    │              │  │ Sort by score    │   │ Error: No  │
    │              │  │ Take top 10      │   │ similar    │
    │              │  └────────┬─────────┘   │ files      │
    │              │           │             └─────┬──────┘
    │              │           ▼                   │
    │              │  ┌──────────────────┐        │
    │              │  │ Show fuzzy menu  │        │
    │              │  └────────┬─────────┘        │
    │              │           │                  │
    └──────────────┴───────────┼──────────────────┘
                               │
                               ▼
                    ┌────────────────────┐
                    │ User Selection     │
                    └─────────┬──────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
          Valid (1-N)                        'q'
              │                               │
              ▼                               ▼
    ┌──────────────────┐           ┌──────────────────┐
    │ Get selected     │           │ Return null      │
    │ file path        │           │ (user quit)      │
    └────────┬─────────┘           └─────────┬────────┘
             │                               │
             └───────────┬───────────────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ File path exists?  │
              └─────────┬──────────┘
                        │
            ┌───────────┴───────────┐
            │                       │
           Yes                     No
            │                       │
            ▼                       ▼
  ┌──────────────────┐    ┌──────────────────┐
  │ Update config    │    │ Error: Could not │
  │ Use selected     │    │ resolve file     │
  │ file path        │    │ Exit 1           │
  └────────┬─────────┘    └──────────────────┘
           │
           ▼
  ┌──────────────────┐
  │ Run Pester tests │
  │ with file        │
  └──────────────────┘
```

## Fuzzy Scoring Algorithm Detail

```
┌────────────────────────────────────────────────────────────────┐
│ Get-FuzzyMatchScore("Settings", "SettingsFunctions.Tests.ps1")│
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │ Convert both to lowercase           │
         │ search: "settings"                  │
         │ candidate: "settingsfunctions..."   │
         └────────────┬────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────────────────┐
         │ Check: Exact match?                 │
         │ "settings" == "settingsfunctions"?  │
         │ NO                                  │
         └────────────┬────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────────────────┐
         │ Check: Contains search term?        │
         │ "settingsfunctions".Contains        │
         │ ("settings")?                       │
         │ YES - at position 0                 │
         └────────────┬────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────────────────┐
         │ Calculate score:                    │
         │ 500 + (100 - 0) = 600               │
         │ RETURN 600                          │
         └─────────────────────────────────────┘

Alternative path if NOT contains:
         ┌─────────────────────────────────────┐
         │ Sequential character matching       │
         │ For each char in "settings":        │
         │   's' -> found at 0: +10, +5 = 15   │
         │   'e' -> found at 1: +10, +5 = 30   │
         │   't' -> found at 2: +10, +5 = 45   │
         │   't' -> found at 3: +10, +5 = 60   │
         │   'i' -> found at 4: +10, +5 = 75   │
         │   'n' -> found at 5: +10, +5 = 90   │
         │   'g' -> found at 6: +10, +5 = 105  │
         │   's' -> found at 7: +10, +5 = 120  │
         │                                     │
         │ Penalty: length diff (22 - 8) = -14│
         │ Final score: 120 - 14 = 106         │
         └─────────────────────────────────────┘
```

## User Selection Flow

```
┌────────────────────────────────────────────────────────────────┐
│ Display Menu:                                                  │
│                                                                │
│ Found 5 similar test file(s):                                 │
│                                                                │
│   [1] tests\Integration\SettingsFunctions.Tests.ps1           │
│   [2] tests\Unit\DomainConfiguration.Tests.ps1                │
│   [3] tests\Comprehensive\ConfigurationManagement.Tests.ps1   │
│   [4] tests\Unit\setupFunctions\Initialize-Application...     │
│   [5] tests\Integration\setupFunctions\ConfigurationWork...   │
│                                                                │
│   [q] Quit                                                     │
│                                                                │
│ Select a file (1-5) or 'q' to quit:                           │
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼ User Input
              ┌────────────────────────────────┐
              │ Parse input                    │
              └────────┬───────────────────────┘
                       │
        ┌──────────────┼──────────────┬─────────────┐
        │              │              │             │
        ▼              ▼              ▼             ▼
    ┌─────┐      ┌────────┐     ┌────────┐    ┌──────────┐
    │ "1" │      │  "q"   │     │  "99"  │    │  "abc"   │
    │ to  │      │  or    │     │ Out of │    │ Invalid  │
    │ "5" │      │  "Q"   │     │ range  │    │ format   │
    └──┬──┘      └───┬────┘     └───┬────┘    └────┬─────┘
       │             │              │              │
       ▼             ▼              ▼              ▼
  ┌─────────┐  ┌─────────┐   ┌──────────┐  ┌──────────┐
  │ Convert │  │ Return  │   │ Show     │  │ Show     │
  │ to index│  │ null    │   │ "Invalid │  │ "Invalid │
  │ (0-4)   │  │         │   │ select"  │  │ input"   │
  └────┬────┘  └────┬────┘   └────┬─────┘  └────┬─────┘
       │            │             │             │
       ▼            │             └─────┬───────┘
  ┌─────────┐       │                   │
  │ Validate│       │                   ▼
  │ index   │       │          ┌──────────────┐
  └────┬────┘       │          │ Return null  │
       │            │          └──────────────┘
       ▼            │
  ┌─────────┐       │
  │ Get file│       │
  │ at index│       │
  └────┬────┘       │
       │            │
       ▼            │
  ┌─────────┐       │
  │ Return  │       │
  │ file    │       │
  │ path    │       │
  └────┬────┘       │
       │            │
       └────────┬───┘
                │
                ▼
         ┌──────────────┐
         │ Calling code │
         │ handles      │
         │ result       │
         └──────────────┘
```

## Example Scoring Comparison

```
Search Term: "Config"

Candidates with Scores:
┌────────────────────────────────────────────────────┬────────┐
│ Filename                                           │ Score  │
├────────────────────────────────────────────────────┼────────┤
│ ConfigurationWorkflow.Tests.ps1                    │  600   │ Contains "config" at pos 0
│ ConfigurationManagement.Tests.ps1                  │  600   │ Contains "config" at pos 0
│ Initialize-ApplicationConfiguration.Tests.ps1      │  516   │ Contains "config" at pos 26
│ DomainConfiguration.Tests.ps1                      │  506   │ Contains "config" at pos 6
│ SettingsFunctions.Tests.ps1                        │   0    │ No match
│ MenuNavigation.Tests.ps1                           │   0    │ No match
└────────────────────────────────────────────────────┴────────┘

Top 4 shown to user ✓
```

## Color-Coded User Experience

```
Terminal Output with Colors:

Test file not found: C:\...\Autopilot\Config          [Yellow]

Searching for test file in tests folder...            [Yellow]
No exact match found. Searching for similar files...  [Yellow]

Found 4 similar test file(s):                         [Cyan]

  [1] tests\Integration\ConfigurationWorkflow.Tests   [White]
  [2] tests\Comprehensive\ConfigurationManagement     [White]
  [3] tests\Unit\Initialize-ApplicationConfig...      [White]
  [4] tests\Unit\DomainConfiguration.Tests.ps1        [White]

  [q] Quit                                             [Gray]

Select a file (1-4) or 'q' to quit: 1                 [Input]

Using selected test file: C:\...\Config...Tests.ps1   [Green]

Running single test file: ConfigurationWorkflow       [Yellow]

[Pester execution continues...]
```

## Performance Visualization

```
Time Comparison (Typical Developer Workflow)

Before Fuzzy Search:
│
├─ Remember path? ────────────────────── [30s thinking]
├─ Try command ──────────────────────────── [2s]
│    ERROR: File not found
├─ Open File Explorer ───────────────────── [5s]
├─ Navigate to tests folder ─────────────── [5s]
├─ Search for file ──────────────────────── [10s]
├─ Copy path ────────────────────────────── [3s]
├─ Try command again ────────────────────── [2s]
│    SUCCESS
└─ Total: ~60 seconds


After Fuzzy Search:
│
├─ Try command with partial name ────────── [2s]
│    Fuzzy search activates (<0.1s)
├─ View menu ────────────────────────────── [1s]
├─ Select file ──────────────────────────── [2s]
│    SUCCESS
└─ Total: ~5 seconds

Time Saved: 55 seconds (91% reduction) ✓
```

## Edge Cases Handling

```
┌──────────────────────────────────────────────────────────────┐
│ Edge Case Matrix                                             │
├──────────────────────────────────────┬───────────────────────┤
│ Scenario                             │ Behavior              │
├──────────────────────────────────────┼───────────────────────┤
│ No files in tests folder             │ "No similar files"    │
│ Single exact match                   │ Auto-use file         │
│ Multiple exact matches               │ Show selection menu   │
│ No fuzzy matches (score all ≤ 0)     │ "No similar files"    │
│ User enters 'q'                      │ Return null, exit     │
│ User enters invalid number           │ "Invalid selection"   │
│ User enters non-numeric text         │ "Invalid input"       │
│ Empty search term                    │ Process normally      │
│ Search term longer than all files    │ Low scores, may fail  │
│ Special characters in filename       │ Process normally      │
│ Case differences                     │ Case-insensitive OK   │
│ Backup files (*.backup-*)            │ Included in search    │
└──────────────────────────────────────┴───────────────────────┘
```

## Success Flow Example

```
Developer wants to run Settings tests:

Step 1: Initial Attempt
   PS> .\Invoke-PesterTests.ps1 -TestFile "Settings"
   
Step 2: File Not Found (Expected)
   Test file not found: C:\...\Autopilot\Settings
   
Step 3: Automatic Search Initiated
   Searching for test file in tests folder...
   No exact match found. Searching for similar files...
   
Step 4: Results Displayed
   Found 3 similar test file(s):
   [1] tests\Integration\SettingsFunctions.Tests.ps1    [600]
   [2] tests\Unit\DomainConfiguration.Tests.ps1         [80]
   [3] tests\Comprehensive\ConfigurationManagement      [45]
   
Step 5: User Selects
   Select a file (1-3) or 'q' to quit: 1
   
Step 6: File Resolved
   Using selected test file: ...\SettingsFunctions.Tests.ps1
   
Step 7: Test Execution
   Running single test file: SettingsFunctions.Tests.ps1
   ===============================================================
   Autopilot Pester Test Suite
   [Tests run successfully...]
   
Total time: ~5 seconds ✓
Success: Test executed without manual path lookup ✓
```
