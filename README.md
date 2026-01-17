# J'Toye Digital - Project Standards Toolkit

> Enterprise-grade automation for code quality, security, testing, architecture validation, 
> API contracts, performance, database integrity, and monitoring across all repositories.

## Quick Start

```bash
# From any project directory:
../_project_standards/bootstrap.sh

# Or specify project type:
../_project_standards/bootstrap.sh --type monorepo
../_project_standards/bootstrap.sh --type python
../_project_standards/bootstrap.sh --type go

# Preview changes without applying:
../_project_standards/bootstrap.sh --dry-run
```

## What Gets Installed

### Core Scripts (Always Installed)

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `validate-project.sh` | Version & config consistency | Pre-commit (automatic) |
| `sync-version.sh` | Sync version across all files | When releasing |
| `install-hooks.sh` | Setup git pre-commit hooks | Once after clone |
| `release.sh` | Automated release process | When releasing versions |

### Quality & Security Scripts

| Script | Purpose | Priority |
|--------|---------|----------|
| `security-scan.sh` | Security vulnerabilities | 🔴 Required |
| `code-quality.sh` | Linting, formatting, dead code | 🔴 Required |
| `architecture-check.sh` | Layer violations, circular deps | 🟡 Recommended |
| `test-coverage.sh` | Coverage analysis | 🟡 Recommended |
| `docs-validator.sh` | Documentation completeness | 🟢 Optional |

### API & Integration Scripts

| Script | Purpose | Priority |
|--------|---------|----------|
| `api-contract.sh` | API spec validation, breaking changes | 🟡 Recommended |
| `dependency-health.sh` | Outdated deps, license conflicts, CVEs | 🟡 Recommended |
| `database-check.sh` | Schema validation, migration integrity | 🟡 Recommended |

### Performance & Observability Scripts

| Script | Purpose | Priority |
|--------|---------|----------|
| `performance-check.sh` | Anti-patterns (N+1, memory leaks) | 🟢 Optional |
| `ui-ux-check.sh` | Accessibility, component consistency | 🟢 Optional |
| `monitoring-check.sh` | Health endpoints, metrics, tracing | 🟢 Optional |

### Master Audit

| Script | Purpose |
|--------|---------|
| `full-audit.sh` | **Runs ALL 12 checks in sequence** |

## Usage Examples

```bash
# Run full project audit (recommended before releases)
./scripts/full-audit.sh

# Run in CI mode (strict, fails fast)
./scripts/full-audit.sh --ci

# Individual checks by category
./scripts/security-scan.sh          # Security vulnerabilities
./scripts/code-quality.sh           # Linting and formatting
./scripts/api-contract.sh           # API spec validation
./scripts/dependency-health.sh      # Dependency analysis
./scripts/performance-check.sh      # Performance anti-patterns
./scripts/database-check.sh         # Schema validation
./scripts/monitoring-check.sh       # Observability checks
./scripts/ui-ux-check.sh            # Accessibility audit

# Bump version (updates everywhere)
./scripts/sync-version.sh 1.2.3

# Automated release
./scripts/release.sh patch          # 1.0.0 -> 1.0.1
./scripts/release.sh minor          # 1.0.0 -> 1.1.0
./scripts/release.sh major          # 1.0.0 -> 2.0.0
./scripts/release.sh patch --dry-run # Preview changes
```

## Detailed Script Documentation

### 🔒 Security Scan (`security-scan.sh`)
Detects security vulnerabilities before they reach production.

**Checks:**
- Hardcoded passwords, API keys, tokens
- .env files tracked in git
- Insecure default configurations
- Dependency vulnerabilities (Go, Python, Node)
- Security headers in web apps
- Sensitive files (*.pem, *.key, credentials.json)

### 📊 Code Quality (`code-quality.sh`)
Enforces consistent code standards.

**Checks:**
- **Go**: `go vet`, `gofmt`, `staticcheck`, `golangci-lint`
- **Python**: `pylint`, `black`, `mypy`
- **TypeScript**: `eslint`, `tsc`
- Complexity analysis (large files)
- TODO/FIXME tracking
- Dead code detection

### 🏗️ Architecture Check (`architecture-check.sh`)
Validates structural integrity.

**Checks:**
- Layer violations (handlers→handlers, etc.)
- Circular import detection
- Directory structure validation
- Dependency direction analysis

### 🧪 Test Coverage (`test-coverage.sh`)
Ensures adequate test coverage.

**Checks:**
- Files without corresponding tests
- Coverage percentage vs thresholds
- Test organization (fixtures, utilities)
- Integration/E2E test presence

### 📚 Documentation Validator (`docs-validator.sh`)
Keeps docs synchronized.

**Checks:**
- README completeness (install, usage, license)
- CHANGELOG maintenance
- API documentation (OpenAPI/Swagger)
- Stale documentation detection

### 📋 API Contract (`api-contract.sh`)
Validates API specifications.

**Checks:**
- OpenAPI/Swagger spec presence and validity
- Route documentation completeness
- Undocumented endpoints detection
- Breaking change warnings
- Version field validation

### 📦 Dependency Health (`dependency-health.sh`)
Manages dependency quality.

**Checks:**
- Outdated packages (npm, pip, go)
- License conflicts (GPL in MIT projects)
- Known vulnerabilities (npm audit, pip-audit)
- Lock file consistency
- Major version drift warnings

### ⚡ Performance Check (`performance-check.sh`)
Catches performance anti-patterns.

**Checks:**
- N+1 query patterns (loops with queries)
- Large payload risks (unbounded responses)
- Memory leak patterns
- Slow regex patterns
- Missing pagination
- O(n²) algorithm detection
- Blocking operations in async code

### 🎨 UI/UX Check (`ui-ux-check.sh`)
Accessibility and UX validation.

**Checks:**
- Missing alt text on images
- Form labels and ARIA attributes
- Color contrast issues
- Dead CSS rules
- Large images without optimization
- Missing loading states
- Responsive design patterns

### 🗄️ Database Check (`database-check.sh`)
Database schema integrity.

**Checks:**
- Migration file sequence
- Missing indexes
- Foreign key definitions
- Data type consistency
- Rollback script presence
- Schema drift detection

### 📈 Monitoring Check (`monitoring-check.sh`)
Observability completeness.

**Checks:**
- Health endpoint presence (/health, /ready, /live)
- Deep health checks (DB/Redis pings)
- Prometheus metrics exposure
- Structured logging usage
- Distributed tracing (OpenTelemetry/Jaeger)
- Error tracking (Sentry, etc.)
- Docker healthcheck configuration

### 🚀 Release Automation (`release.sh`)
Streamlined release process.

**Features:**
- Semantic versioning (patch/minor/major)
- Automatic changelog generation from commits
- Version synchronization across all files
- Git tagging with annotation
- Dry-run preview mode

## Project Types

### Monorepo (default)
For projects with multiple packages/services
```
project/
├── apps/
├── services/
├── packages/
└── package.json
```

### Python
For pure Python projects
```
project/
├── src/
├── tests/
├── requirements.txt
└── setup.py
```

### Go
For pure Go projects
```
project/
├── cmd/
├── internal/
├── pkg/
└── go.mod
```

### Node
For Node.js/TypeScript projects
```
project/
├── src/
├── dist/
└── package.json
```

## Customization

After bootstrapping, edit `scripts/project-config.sh`:

```bash
# Which files contain version numbers
JSON_VERSION_FILES=(
    "package.json"
    "apps/web/package.json"
)

# Required files that must exist
REQUIRED_FILES=(
    "VERSION"
    "README.md"
    ".env.example"
)

# Coverage thresholds
GO_COVERAGE_THRESHOLD=60
PYTHON_COVERAGE_THRESHOLD=50
NODE_COVERAGE_THRESHOLD=40

# Forbidden paths in documentation
FORBIDDEN_DOC_PATHS=(
    "services/web"  # Should be apps/web
)
```

## CI Integration

Add to `.github/workflows/ci.yml`:

```yaml
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run full audit
        run: ./scripts/full-audit.sh --ci
```

## Recommended External Tools

Install for enhanced checks:

```bash
# Go
go install honnef.co/go/tools/cmd/staticcheck@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

# Python
pip install pylint black mypy pip-audit

# Node
npm install -g eslint prettier
```

## Standards Enforced

1. **Single Version Source**: `VERSION` file is authoritative
2. **Pre-commit Validation**: Catches drift before commits
3. **CI Validation**: Catches issues in PRs
4. **Security by Default**: No secrets in code
5. **Quality Gates**: Linting and formatting
6. **Architecture Guards**: Layer boundaries enforced
7. **Test Requirements**: Coverage thresholds
8. **Living Documentation**: Docs stay current
