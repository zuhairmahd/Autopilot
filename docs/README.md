# Documentation Index

This directory contains technical documentation for the Windows Autopilot Management Tool.

## Primary Documentation

### For Users
- **[Main README](../readme.md)** - Quick start, features overview, device reports, troubleshooting

### For Developers
| Document | Description |
|----------|-------------|
| **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** | Architecture, menu system, caching, testing, coding standards |
| **[SETTINGS.md](SETTINGS.md)** | Complete settings and configuration reference |
| **[TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)** | Detailed API reference (212 functions across 10 categories) |
| **[CONTRIBUTOR_GUIDE.md](CONTRIBUTOR_GUIDE.md)** | Contribution guidelines and workflow |
| **[TROUBLESHOOTING_GUIDE.md](TROUBLESHOOTING_GUIDE.md)** | Common issues and diagnostic procedures |
| **[CLAUDE.md](../CLAUDE.md)** | AI assistant guidance for working with this codebase |

## Feature Documentation

Located in `features/` (15 documents):

| Document | Description |
|----------|-------------|
| [MENU_SYSTEM_DOCUMENTATION.md](features/MENU_SYSTEM_DOCUMENTATION.md) | Comprehensive menu system reference |
| [APP_MODE_CONFIGURATION.md](features/APP_MODE_CONFIGURATION.md) | Role-based access and app mode configuration |
| [SCOPE_VALIDATION.md](features/SCOPE_VALIDATION.md) | Microsoft Graph API permissions and scope validation |
| [unified-cache-implementation.md](features/unified-cache-implementation.md) | Multi-layer cache system implementation |
| [INTERACTIVE_SELECTION_*.md](features/) | Interactive selection system documentation |
| [EXCLUDE_SWITCH_*.md](features/) | Exclude switch implementation and usage |

## Testing Documentation

| Document | Description |
|----------|-------------|
| [../tests/AGENTS.md](../tests/AGENTS.md) | AI-optimized testing guide with Pester best practices |
| [tests/](tests/) | Test duration analysis and GitHub Actions testing guides |

## Implementation Guides

Located in `guides/` (4 documents):

| Document | Description |
|----------|-------------|
| [Fuzzy-Test-File-Search-Quick-Reference.md](guides/Fuzzy-Test-File-Search-Quick-Reference.md) | Fuzzy test file searching |
| [Interactive-File-Selection-Guide.md](guides/Interactive-File-Selection-Guide.md) | Interactive file selection patterns |
| [Interactive-Selection-Error-Handling.md](guides/Interactive-Selection-Error-Handling.md) | Error handling for interactive selections |
| [Interactive-Tag-Selection-Guide.md](guides/Interactive-Tag-Selection-Guide.md) | Tag-based test selection |

## Bug Fixes and Refactoring

Located in `fixes/` (28 documents) and `refactoring/` (10 documents):
- Certificate authentication fixes
- Groups editor improvements
- Settings function test fixes
- Smart caching enhancements
- Workflow deduplication
- HasScope refactoring
- Invoke-PesterTests enhancements

## Migrations

Located in `migrations/` (3 documents):

| Document | Description |
|----------|-------------|
| [DIRECTORY_OBJECT_MIGRATION_GUIDE.md](migrations/DIRECTORY_OBJECT_MIGRATION_GUIDE.md) | User/group function migration guide |
| [corevalidation-json-to-psd1-migration.md](migrations/corevalidation-json-to-psd1-migration.md) | JSON to PSD1 configuration migration |
| [settings-migration-implementation.md](migrations/settings-migration-implementation.md) | Settings migration procedures |

## Architecture Documentation

Located in `architecture/` (1 document):

| Document | Description |
|----------|-------------|
| [Unified-Selection-Architecture.md](architecture/Unified-Selection-Architecture.md) | Unified selection system architecture |

## Archived Documentation

Historical and implementation-specific documentation has been moved to `archive/` (62 documents) to maintain focus on current documentation while preserving context for reference.

See [archive/README.md](archive/README.md) for a complete list of archived documents including:
- Pester migration documentation (11 docs)
- Performance optimization initiatives (10 docs)
- Phase completion reports (9 docs)
- Historical bug fixes (14 docs)
- Feature implementation history (10 docs)
- Analysis and planning documents (8 docs)

## Quick Reference

**New Contributors**: Start with [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) and [../tests/AGENTS.md](../tests/AGENTS.md)

**Users**: See the main [README](../readme.md) for quick start and feature overview

**Troubleshooting**: Check [TROUBLESHOOTING_GUIDE.md](TROUBLESHOOTING_GUIDE.md) for common issues

**Settings Configuration**: Refer to [SETTINGS.md](SETTINGS.md) for complete configuration reference

---

*Last updated: February 2026 - Documentation reflects 212 functions across 10 categories*