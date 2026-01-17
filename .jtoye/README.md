# J'Toye Digital Project Standards Toolkit v2.0

A comprehensive suite of project validation scripts for J'Toye Digital projects.

## Quick Start

```bash
# Run full audit
./scripts/jtoye-audit

# Run quick audit (skip optional checks)
./scripts/jtoye-audit --quick

# Run in CI mode (stop on first required failure)
./scripts/jtoye-audit --ci
```

## Scripts Overview

| Script | Description | Level |
|--------|-------------|-------|
| `jtoye-audit` | Main orchestrator - runs all checks | - |
| `jtoye-security` | Secret detection, vulnerability scanning | Required |
| `jtoye-quality` | Code style, linting, formatting | Required |
| `jtoye-architecture` | Project structure validation | Recommended |
| `jtoye-coverage` | Test coverage analysis | Recommended |
| `jtoye-docs` | Documentation completeness | Recommended |
| `jtoye-api` | API contract validation | Recommended |
| `jtoye-deps` | Dependency health & security | Recommended |
| `jtoye-database` | Migration & schema checks | Recommended |
| `jtoye-conda` | Conda environment validation | Recommended |
| `jtoye-makefile` | Makefile quality checks | Recommended |
| `jtoye-performance` | Performance anti-patterns | Optional |
| `jtoye-uiux` | Accessibility & UX patterns | Optional |
| `jtoye-monitoring` | Observability configuration | Optional |

## Usage

### Individual Scripts

Each script can be run standalone:

```bash
# Security scan
./scripts/jtoye-security

# With explicit project path
./scripts/jtoye-security /path/to/project

# Using environment variable
JTOYE_PROJECT_ROOT=/path/to/project ./scripts/jtoye-quality
```

### Custom Thresholds

Some scripts support custom thresholds via environment variables:

```bash
# Coverage thresholds
JTOYE_GO_COVERAGE_THRESHOLD=80 \
JTOYE_PYTHON_COVERAGE_THRESHOLD=70 \
./scripts/jtoye-coverage
```

## Architecture

### Shared Library

All scripts source the common library at `lib/jtoye-common.sh`:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/jtoye-common.sh"

PROJECT_ROOT="$(detect_project_root "${1:-}")"
```

### Features

- **Unified exclusion patterns**: All scripts skip `node_modules`, `.venv`, `vendor`, etc.
- **Consistent output**: Color-coded results with `jtoye_pass`, `jtoye_warn`, `jtoye_fail`
- **Safe operations**: Uses `set -e` and safe increment patterns
- **Auto-detection**: Detects Go, Python, Node.js, Rust projects automatically

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |

## Makefile Integration

Add to your project's Makefile:

```makefile
.PHONY: audit audit-quick lint security

audit:
	@./scripts/jtoye-audit

audit-quick:
	@./scripts/jtoye-audit --quick

lint:
	@./scripts/jtoye-quality

security:
	@./scripts/jtoye-security
```

## CI/CD Integration

### GitHub Actions

```yaml
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run audit
        run: ./scripts/jtoye-audit --ci
```

### GitLab CI

```yaml
audit:
  script:
    - ./scripts/jtoye-audit --ci
  allow_failure: false
```

## Customization

### Project-Specific Configuration

Create a `scripts/lib/project-config.sh` file for project-specific overrides:

```bash
# Custom exclusion directories
JTOYE_EXTRA_EXCLUDES="--exclude-dir=generated --exclude-dir=legacy"

# Custom thresholds
JTOYE_GO_COVERAGE_THRESHOLD=70
```

## Version History

### v2.0.0 (2026-01-17)
- Complete rewrite with `jtoye-*` naming convention
- Shared library for consistent behavior
- Fixed .venv/site-packages scanning issue
- Added CI mode and quick mode
- Improved performance (~37s full audit)

### v1.0.0
- Initial release with separate scripts
