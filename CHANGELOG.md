# Changelog

All notable changes to the J'Toye Digital Project Standards Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-17

### Added
- **Help System**: All scripts now support `--help` and `-h` flags with consistent output format
- **Common Library** (`lib/common.sh`): Shared utilities for all audit scripts
  - `setup_help()` / `add_help_option()` / `handle_help()` - Standardized help handler
  - `require_tool()` / `require_tools()` - Consistent tool requirement checking with `required`, `warn`, and `optional` modes
  - `acquire_lock()` / `release_lock()` - Lock file management to prevent concurrent execution
  - `check_bash_version()` - Bash 4.3+ version requirement check
  - `safe_find_null()` / `process_files_safely()` - Proper handling of spaces in file paths
  - `log_info()`, `log_success()`, `log_warn()`, `log_error()`, `log_debug()` - Logging utilities
  - `init_script()` - One-liner for consistent script initialization
- **Lock File Support**: `full-audit.sh` now prevents concurrent execution with automatic cleanup
- **`--no-lock` Flag**: Skip lock file in `full-audit.sh` when parallel execution is needed
- **Bash Version Check**: Scripts automatically verify Bash 4.3+ is available (skippable with `SKIP_BASH_CHECK=1`)

### Changed
- All 12 audit scripts now source `lib/common.sh` for shared utilities
- Colors and exclusion patterns are now centralized in `common.sh`
- `EXCL` grep exclusion variable is now provided by common library
- Improved script headers with consistent formatting

### Fixed
- Scripts now properly handle file paths containing spaces using null-delimited find output

## [1.0.0] - 2026-01-15

### Added
- Initial release of Project Standards Toolkit
- Core scripts: `validate-project.sh`, `sync-version.sh`, `install-hooks.sh`, `release.sh`
- Security scan: `security-scan.sh`
- Code quality: `code-quality.sh`
- Architecture validation: `architecture-check.sh`
- Test coverage: `test-coverage.sh`
- Documentation validator: `docs-validator.sh`
- API contract validation: `api-contract.sh`
- Dependency health: `dependency-health.sh`
- Performance checks: `performance-check.sh`
- UI/UX accessibility: `ui-ux-check.sh`
- Database schema checks: `database-check.sh`
- Monitoring/observability: `monitoring-check.sh`
- Conda environment checks: `conda-env-check.sh`
- Makefile validation: `makefile-check.sh`
- Master audit: `full-audit.sh`
- Bootstrap script for project initialization
