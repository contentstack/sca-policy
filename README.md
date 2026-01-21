# Contentstack CI Workflows

This repository contains reusable GitHub Actions workflows for Contentstack projects. These workflows can be easily integrated into any repository to automate CI/CD processes.

## How to Use Workflows in Your Repository

These workflows are designed to be used as **reusable workflows** using the `uses:` syntax. You don't need to copy the workflow files - simply reference them from this repository.

### Step 1: Create a Workflow File in Your Repository

Create a new workflow file in your repository at `.github/workflows/<your-workflow-name>.yml`:

```yaml
name: Code Quality Pipeline

on:
    push:
        branches: [main, master, feature/*]
    pull_request:
        branches: [main, master]
    workflow_dispatch:

jobs:
    security-scan:
        name: Security Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
```

### Step 2: Configure Required Secrets

Go to your repository's **Settings → Secrets and variables → Actions** and add:

- **Required Secrets**: 
  - `SNYK_TOKEN`: Your Snyk authentication token


### Step 3: Reference the Workflow

Use the `uses:` syntax to reference the workflow from this repository:

```yaml
jobs:
    my-job:
        uses: contentstack/contentstack-ci-workflows/.github/workflows/<workflow-name>.yml@main
        secrets: inherit
```


## Available Workflows

### [Source Composition Analysis Scan](.github/workflows/snyk-sca-scan.yml)

A comprehensive security scanning workflow that uses Snyk to detect vulnerabilities in your project dependencies. This workflow supports **multiple languages** including Go, Node.js, Python, and more.

**Features:**
- **Multi-language support**: Golang, Node.js, Python, and auto-detection for other languages
- **Scans dependencies** for open-source vulnerabilities
- **Enforces severity thresholds** for critical, high, medium, and low severity issues
- **Tracks SLA breaches** based on days since vulnerability publication
- **Posts detailed results** as PR comments with actionable fixes
- **Fails builds** when security thresholds are exceeded

**Required Secrets:**
- `SNYK_TOKEN`: Your Snyk authentication token

**Additional Secrets (for Go projects with private dependencies):**
- `USER_NAME`: GitHub username for private repository access
- `PERSONAL_ACCESS_TOKEN`: GitHub Personal Access Token with repo access

**Input Parameters:**

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `language` | Language/runtime for Snyk scan (e.g., `golang`, `node`, `python`) | No | Auto-detect |
| `args` | Additional arguments to pass to Snyk (e.g., `--all-projects`, `--file=go.mod`) | No | `""` |
| `go-version` | Go version to use for Golang projects (e.g., `1.23`, `1.24`, `stable`) | No | `stable` |

**Optional Repository Variables:**
- `MAX_CRITICAL_ISSUES`: Maximum allowed critical issues (default: 1)
- `MAX_HIGH_ISSUES`: Maximum allowed high issues (default: 1)
- `MAX_MEDIUM_ISSUES`: Maximum allowed medium issues (default: 500)
- `MAX_LOW_ISSUES`: Maximum allowed low issues (default: 1000)
- `SLA_CRITICAL_WITH_FIX`: SLA threshold in days for critical issues with fixes (default: 15)
- `SLA_HIGH_WITH_FIX`: SLA threshold in days for high issues with fixes (default: 30)
- `SLA_MEDIUM_WITH_FIX`: SLA threshold in days for medium issues with fixes (default: 90)
- `SLA_LOW_WITH_FIX`: SLA threshold in days for low issues with fixes (default: 180)
- `SLA_CRITICAL_NO_FIX`: SLA threshold in days for critical issues without fixes (default: 30)
- `SLA_HIGH_NO_FIX`: SLA threshold in days for high issues without fixes (default: 120)
- `SLA_MEDIUM_NO_FIX`: SLA threshold in days for medium issues without fixes (default: 365)
- `SLA_LOW_NO_FIX`: SLA threshold in days for low issues without fixes (default: 365)

**Triggers:**
- Pull requests (opened, synchronize, reopened)
- Manual workflow dispatch

#### Usage Examples

Here are complete examples of how to use this workflow for different languages:

##### Example 1: Go/Golang Project

```yaml
name: Security Scan - Golang

on:
    pull_request:
        types: [opened, synchronize, reopened]
    workflow_dispatch:

jobs:
    security-sca:
        name: Snyk SCA Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
        with:
            language: "golang"
            go-version: "1.23"  # or "stable", "1.24", etc.
            args: ""  # Optional: Add custom Snyk args like "--all-projects"
```

**Important for Go projects with private dependencies:**
- Add `USER_NAME` and `PERSONAL_ACCESS_TOKEN` secrets to your repository (Settings → Secrets and variables → Actions)
- These are required to authenticate with private Go modules during the scan

##### Example 2: Node.js Project

```yaml
name: Security Scan - Node.js

on:
    pull_request:
        types: [opened, synchronize, reopened]
    workflow_dispatch:

jobs:
    security-sca:
        name: Snyk SCA Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
        with:
            language: "node"
            args: "--all-projects"  # Optional: Scan all projects in monorepo
```

##### Example 3: Python Project

```yaml
name: Security Scan - Python

on:
    pull_request:
        types: [opened, synchronize, reopened]
    workflow_dispatch:

jobs:
    security-sca:
        name: Snyk SCA Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
        with:
            language: "python"

```

##### Example 4: Auto-detect Language (Default)

```yaml
name: Security Scan - Auto Detect

on:
    pull_request:
        types: [opened, synchronize, reopened]
    workflow_dispatch:

jobs:
    security-sca:
        name: Snyk SCA Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
        # No 'with' block - Snyk will auto-detect the language
```

> **⚠️ Note:** For Golang projects with private package dependencies, do not rely on auto-detect. Use Example 1 instead and explicitly set `language: "golang"`.

##### Example 5: Monorepo with Multiple Projects

```yaml
name: Security Scan - Monorepo

on:
    pull_request:
        types: [opened, synchronize, reopened]
    workflow_dispatch:

jobs:
    security-sca:
        name: Snyk SCA Scan
        uses: contentstack/contentstack-ci-workflows/.github/workflows/snyk-sca-scan.yml@main
        secrets: inherit
        with:
            language: "node"  # or "golang", "python", etc.
            args: "--all-projects"  # Scan all detected projects
```

---
