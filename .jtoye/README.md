# J'Toye Digital Project Standards Toolkit v2.1

A comprehensive suite of project validation scripts for J'Toye Digital projects.

## Prerequisites

**Required**: `bash 4.3+`, `git`, `grep`, `find`

**Optional** (by project type):
- Go: `go`, `gofmt`
- Python: `python`, `ruff`/`flake8`, `pip-audit`
- Node.js: `npm`/`pnpm`, `eslint`
- JSON parsing: `jq` (has fallback)

## Quick Start

```bash
# Run full audit (from project root with .jtoye installed)
./.jtoye/jtoye-audit .

# Run quick audit (skip optional checks)
./.jtoye/jtoye-audit . --quick

# Run in CI mode (stop on first required failure)
./.jtoye/jtoye-audit . --ci

# Run in offline mode (skip network-dependent checks)
./.jtoye/jtoye-audit . --offline
```

## Installation

```bash
# From the _project_standards directory:
./install-jtoye.sh /path/to/your/project

# Or create symlink (for projects in same workspace):
./install-jtoye.sh --symlink /path/to/your/project
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
# Security scan (from project with .jtoye installed)
./.jtoye/jtoye-security .

# With explicit project path
./.jtoye/jtoye-security /path/to/project

# Using environment variable
JTOYE_PROJECT_ROOT=/path/to/project ./.jtoye/jtoye-quality .
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JTOYE_PROJECT_ROOT` | (auto-detect) | Override project root detection |
| `JTOYE_COMMAND_TIMEOUT` | `60` | Seconds before command timeout |
| `JTOYE_FIND_MAXDEPTH` | `15` | Max directory depth for searches |
| `JTOYE_OFFLINE` | `false` | Skip network-dependent checks |
| `JTOYE_GO_COVERAGE` | `60` | Go test coverage threshold % |
| `JTOYE_PY_COVERAGE` | `50` | Python coverage threshold % |
| `JTOYE_NODE_COVERAGE` | `40` | Node.js coverage threshold % |
| `JTOYE_EXTRA_EXCLUDES` | (empty) | Additional paths to exclude |

### Example with custom settings:

```bash
JTOYE_GO_COVERAGE=80 \
JTOYE_PY_COVERAGE=70 \
JTOYE_COMMAND_TIMEOUT=120 \
./.jtoye/jtoye-coverage .
```

## Architecture

### Shared Library

All scripts source the common library at `lib/jtoye-common.sh`:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/jtoye-common.sh"

PROJECT_ROOT="$(detect_project_root "${1:-}")" || exit 1
cd -- "$PROJECT_ROOT" || exit 1
```

### Features

- **Strict mode**: Uses `set -euo pipefail` for robust error handling
- **Unified exclusion patterns**: All scripts skip `node_modules`, `.venv`, `vendor`, etc.
- **Consistent output**: Color-coded results with `jtoye_pass`, `jtoye_warn`, `jtoye_fail`
- **Timeout protection**: Commands have configurable timeouts via `run_with_timeout`
- **Offline mode**: Skip network checks with `--offline` or `JTOYE_OFFLINE=true`
- **Auto-detection**: Detects Go, Python, Node.js, Rust projects automatically

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |
| 124 | Command timed out |

## Makefile Integration

Add to your project's Makefile:

```makefile
.PHONY: audit audit-quick lint security

audit:
	@./.jtoye/jtoye-audit .

audit-quick:
	@./.jtoye/jtoye-audit . --quick

audit-ci:
	@./.jtoye/jtoye-audit . --ci

lint:
	@./.jtoye/jtoye-quality .

security:
	@./.jtoye/jtoye-security .
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
        run: ./.jtoye/jtoye-audit . --ci
```

### GitLab CI

```yaml
audit:
  script:
    - ./.jtoye/jtoye-audit . --ci
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
