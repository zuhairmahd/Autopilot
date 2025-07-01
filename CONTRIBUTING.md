# Contributing to Intune Autopilot Management Script

We welcome contributions to improve the Intune Autopilot Management Script! This document outlines the process for contributing to this project.

## Code of Conduct

### Our Pledge
We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards
Examples of behavior that contributes to creating a positive environment include:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Unacceptable Behavior
Examples of unacceptable behavior include:
- The use of sexualized language or imagery and unwelcome sexual attention or advances
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

## How to Contribute

### Reporting Issues
1. **Search existing issues** to ensure your issue hasn't already been reported
2. **Use the issue template** when creating a new issue
3. **Provide detailed information** including:
   - Steps to reproduce the issue
   - Expected behavior
   - Actual behavior
   - PowerShell version and environment details
   - Relevant log output (with sensitive information redacted)

### Suggesting Enhancements
1. **Check if the enhancement has been suggested** before
2. **Provide a clear description** of the proposed enhancement
3. **Explain the use case** and why it would be beneficial
4. **Consider the impact** on existing functionality

### Code Contributions

#### Before You Start
1. **Fork the repository** and create your branch from the main branch
2. **Ensure you have the development environment set up** (see [Development Setup](#development-setup))
3. **Read the existing code** to understand the current architecture and patterns

#### Development Guidelines

##### PowerShell Standards
- **PowerShell 5.1 Compatibility**: Maintain compatibility with PowerShell 5.1 for Windows
- **Use approved verbs**: Follow PowerShell naming conventions with approved verbs
- **Parameter validation**: Use parameter validation attributes where appropriate
- **Error handling**: Implement comprehensive error handling with try-catch blocks
- **Verbose logging**: Add verbose logging for debugging and troubleshooting

##### Code Style
- **Indentation**: Use 4 spaces for indentation
- **Line length**: Keep lines under 120 characters when possible
- **Comments**: Add meaningful comments for complex logic
- **Function documentation**: Use comment-based help for functions
- **Variable naming**: Use descriptive variable names with camelCase

##### Security Considerations
- **Never commit secrets**: Do not include credentials, keys, or sensitive data in code
- **Validate input**: Always validate and sanitize user input
- **Use secure practices**: Follow PowerShell security best practices
- **Principle of least privilege**: Request only necessary permissions

#### Pull Request Process
1. **Create a feature branch** from the main branch
2. **Make your changes** following the development guidelines
3. **Test thoroughly** in multiple environments when possible
4. **Update documentation** if your changes affect functionality
5. **Create a pull request** with a clear title and description

#### Pull Request Requirements
- [ ] Code follows the established style guidelines
- [ ] All tests pass (when applicable)
- [ ] Documentation has been updated if necessary
- [ ] Commit messages are clear and descriptive
- [ ] Changes are backwards compatible or breaking changes are clearly documented
- [ ] Security implications have been considered

## Development Setup

### Prerequisites
- Windows 10/11 or Windows Server
- PowerShell 5.1 or later
- Git for version control
- Visual Studio Code (recommended) with PowerShell extension
- Azure subscription for testing (optional but recommended)

### Environment Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/zuhairmahd/Autopilot.git
   cd Autopilot
   ```

2. **Create development configuration**:
   ```powershell
   # Create .secrets folder for development
   New-Item -ItemType Directory -Path ".secrets" -Force
   
   # Copy sample configuration
   Copy-Item "config-sample.json" ".secrets/config.json"
   ```

3. **Configure your development environment**:
   - Edit `.secrets/config.json` with your Azure App Registration details
   - Update `settings.json` with appropriate test domain settings
   - Ensure you have the required Azure permissions for testing

### Testing
- **Unit Testing**: Test individual functions in isolation
- **Integration Testing**: Test with actual Azure/Intune environments when possible
- **User Acceptance Testing**: Verify the interactive menu system works correctly
- **Security Testing**: Ensure no sensitive data is exposed or logged

### Debugging
- Use PowerShell ISE or Visual Studio Code for debugging
- Enable verbose logging with the `-Verbose` parameter
- Check the PowerShell execution policy if scripts won't run
- Use `Write-Verbose` for debugging output instead of `Write-Host`

## Documentation Guidelines

### Code Documentation
- Use comment-based help for all public functions
- Include parameter descriptions and examples
- Document any complex algorithms or business logic
- Keep comments up-to-date with code changes

### User Documentation
- Update README.md for user-facing changes
- Add examples for new features
- Document configuration changes
- Include troubleshooting information for common issues

## Release Process

### Version Management
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update version numbers in relevant files
- Create release notes documenting changes

### Release Checklist
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Version numbers are updated
- [ ] Release notes are prepared
- [ ] Security review completed (if applicable)

## Getting Help

### Resources
- **Documentation**: Check the `docs/` folder for detailed technical documentation
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions for general questions
- **Microsoft Resources**: Reference official Microsoft documentation for Graph API and Intune

### Contact
For questions about contributing, please:
1. Check the existing documentation
2. Search for similar issues or discussions
3. Create a new issue or discussion if needed

## Recognition

Contributors will be recognized in the project documentation and release notes. We appreciate all contributions, whether they're code, documentation, bug reports, or feature suggestions.

Thank you for contributing to the Intune Autopilot Management Script!