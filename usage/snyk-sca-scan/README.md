# Snyk SCA Scan - Usage Examples

This folder contains example workflow files for using the Snyk Source Composition Analysis (SCA) scan workflow with different programming languages and configurations.

## Examples

### [golang.yml](./golang.yml)
Example for **Go/Golang** projects with custom Go version specification.

**Important for Go projects with private dependencies:**
- Add `USER_NAME` and `PERSONAL_ACCESS_TOKEN` secrets to your repository (Settings → Secrets and variables → Actions)
- These are required to authenticate with private Go modules during the scan

### [nodejs.yml](./nodejs.yml)
Example for **Node.js** projects with monorepo support using `--all-projects` flag.

### [python.yml](./python.yml)
Example for **Python** projects.

### [auto-detect.yml](./auto-detect.yml)
Example using **auto-detection** - Snyk will automatically detect the project language.

> **⚠️ Note:** For Golang projects with private package dependencies, do not rely on auto-detect. Use the [golang.yml](./golang.yml) example instead and explicitly set `language: "golang"`.

### [monorepo.yml](./monorepo.yml)
Example for **monorepo** projects with multiple packages/modules.

## How to Use

1. Copy the relevant example file to your repository at `.github/workflows/security-scan.yml`
2. Update the workflow name and configuration as needed
3. Ensure you have the required secrets configured in your repository
4. Commit and push the file to trigger the workflow

## Required Secrets

All examples require:
- `SNYK_TOKEN`: Your Snyk authentication token

For Go projects with private dependencies, also add:
- `USER_NAME`: GitHub username for private repository access
- `PERSONAL_ACCESS_TOKEN`: GitHub Personal Access Token with repo access

## More Information

For full documentation, see the [main README](../../README.md).
