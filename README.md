# Snyk SCA Scan (composite action)

Analyzes a Snyk JSON report (`snyk-report.json`) for severity thresholds and SLA breaches. Counts only vulnerabilities that have available fixes (upgrades or patches) toward configured thresholds, generates a summary in the GitHub Actions step summary, uploads the report artifact, and optionally comments on pull requests.

## Inputs
- `snyk-report-artifact` (required): Name of the artifact containing `snyk-report.json` (e.g. `snyk-report`).
- `MAX_CRITICAL_ISSUES`, `MAX_HIGH_ISSUES`, `MAX_MEDIUM_ISSUES`, `MAX_LOW_ISSUES` (optional): numeric thresholds for allowed vulnerabilities with fixes. Defaults are `1`, `1`, `500`, `1000`.
- `SLA_CRITICAL_WITH_FIX`, `SLA_HIGH_WITH_FIX`, `SLA_MEDIUM_WITH_FIX`, `SLA_LOW_WITH_FIX` (optional): SLA days for vulnerabilities with fixes. Defaults are `15`, `30`, `90`, `180`.
- `SLA_CRITICAL_NO_FIX`, `SLA_HIGH_NO_FIX`, `SLA_MEDIUM_NO_FIX`, `SLA_LOW_NO_FIX` (optional): SLA days for vulnerabilities without fixes. Defaults are `30`, `120`, `365`, `365`.

## Outputs
- `fail_build`: `true` when thresholds or SLA checks failed (action exits non-zero).

## Example usage

This action expects a `snyk-report.json` uploaded as an artifact. Example workflow that runs Snyk, uploads the report, then calls this action:

```yaml
name: Run Snyk and analyze
on: [push, pull_request]

jobs:
  snyk-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Snyk test (example)
        run: |
          # run Snyk and output JSON to snyk-report.json
          snyk test --json > snyk-report.json || true
      - name: Upload Snyk report
        uses: actions/upload-artifact@v4
        with:
          name: snyk-report
          path: snyk-report.json

  analyze-snyk:
    needs: snyk-test
    runs-on: ubuntu-latest
    steps:
      - name: Run Snyk SCA Scan action
        uses: contentstack/contentstack-ci-workflows/.github/actions/snyk-sca-scan@main
        with:
          snyk-report-artifact: snyk-report
          MAX_CRITICAL_ISSUES: '1'
          MAX_HIGH_ISSUES: '1'
          MAX_MEDIUM_ISSUES: '500'
          MAX_LOW_ISSUES: '1000'
```

If you prefer to reference the action by path in the same repository, set `uses: ./.github/actions/snyk-sca-scan`.

## Permissions
To allow the action to post PR comments, ensure the workflow grants the GITHUB_TOKEN `issues: write` (or `pull-requests: write` depending on how you post comments) permissions. Example:

```yaml
permissions:
  contents: read
  issues: write
  actions: read
```

## Notes
- The action installs `jq` on Ubuntu runners if not present.
- Only vulnerabilities with `.isUpgradable == true` or `.isPatchable == true` are counted toward configured thresholds; vulnerabilities without fixes are reported separately as informational.
- The action writes a human-readable summary to the step summary and sets `fail_build` output when checks fail.
