# Copilot Code Generation Instructions

## Azure Best Practices
- **@azure Rule** - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available.

## PowerShell Requirements
- Whenever possible, maintain compatibility with PowerShell 5.1 for Windows.
- If PowerShell 5.1 compatibility cannot be maintained, add appropriate comments to indicate the minimum version of PowerShell required to run the code.
- Remember that in PowerShell for Windows, variables are typically not case sensitive.

## Logging
- Always add verbose logging.
