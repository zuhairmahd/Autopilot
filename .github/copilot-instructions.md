- @azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available.
Whenever possible, maintain compatibility with Powershell 5.1 for Windows.  If that cannot be done, add appropriate comments to indicate the minimum version of Powershell required to run the code.

Code is running in Powershell for Windows, where variables are typically not case sensitive 

Always add verbose logging.
