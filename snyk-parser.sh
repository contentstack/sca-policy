#!/usr/bin/env bash
set -euo pipefail

echo "Installing jq if needed..."
if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -qq >/dev/null 2>&1 || true
  sudo apt-get install -y -qq jq >/dev/null 2>&1 || true
fi

echo "Verifying snyk.json exists..."
if [ ! -f snyk.json ]; then
  echo "Error: snyk.json not found"
  echo "fail_build=true" >> "$GITHUB_OUTPUT" || true
  exit 1
fi

echo "Normalizing snyk.json structure..."
if jq -e 'type == "array"' snyk.json >/dev/null 2>&1; then
  echo "  -> snyk.json is an array (multi-project output), merging all vulnerabilities..."
  SNYK_DATA=$(jq '{ vulnerabilities: [ .[].vulnerabilities[]? ] }' snyk.json)
else
  echo "  -> snyk.json is a single object, reading as-is..."
  SNYK_DATA=$(cat snyk.json)
fi

# Load thresholds from environment (inputs provided by action.yml)
MAX_CRITICAL_ISSUES="${MAX_CRITICAL_ISSUES:-1}"
MAX_HIGH_ISSUES="${MAX_HIGH_ISSUES:-1}"
MAX_MEDIUM_ISSUES="${MAX_MEDIUM_ISSUES:-500}"
MAX_LOW_ISSUES="${MAX_LOW_ISSUES:-1000}"

SLA_CRITICAL_WITH_FIX="${SLA_CRITICAL_WITH_FIX:-15}"
SLA_HIGH_WITH_FIX="${SLA_HIGH_WITH_FIX:-30}"
SLA_MEDIUM_WITH_FIX="${SLA_MEDIUM_WITH_FIX:-90}"
SLA_LOW_WITH_FIX="${SLA_LOW_WITH_FIX:-180}"
SLA_CRITICAL_NO_FIX="${SLA_CRITICAL_NO_FIX:-30}"
SLA_HIGH_NO_FIX="${SLA_HIGH_NO_FIX:-120}"
SLA_MEDIUM_NO_FIX="${SLA_MEDIUM_NO_FIX:-365}"
SLA_LOW_NO_FIX="${SLA_LOW_NO_FIX:-365}"

echo "Counting vulnerabilities (only with fixes are counted toward thresholds)..."
critical_count=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "critical" and (.isUpgradable == true or .isPatchable == true))] | length' 2>/dev/null || echo 0)
high_count=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "high" and (.isUpgradable == true or .isPatchable == true))] | length' 2>/dev/null || echo 0)
medium_count=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "medium" and (.isUpgradable == true or .isPatchable == true))] | length' 2>/dev/null || echo 0)
low_count=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "low" and (.isUpgradable == true or .isPatchable == true))] | length' 2>/dev/null || echo 0)

critical_no_fix=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "critical" and (.isUpgradable != true and .isPatchable != true))] | length' 2>/dev/null || echo 0)
high_no_fix=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "high" and (.isUpgradable != true and .isPatchable != true))] | length' 2>/dev/null || echo 0)
medium_no_fix=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "medium" and (.isUpgradable != true and .isPatchable != true))] | length' 2>/dev/null || echo 0)
low_no_fix=$(echo "$SNYK_DATA" | jq -r '[.vulnerabilities[]? | select(.severity == "low" and (.isUpgradable != true and .isPatchable != true))] | length' 2>/dev/null || echo 0)

echo "Exporting counts to GITHUB_ENV..."
echo "critical_count=$critical_count" >> "$GITHUB_ENV"
echo "critical_no_fix=$critical_no_fix" >> "$GITHUB_ENV"
echo "high_count=$high_count" >> "$GITHUB_ENV"
echo "high_no_fix=$high_no_fix" >> "$GITHUB_ENV"
echo "medium_count=$medium_count" >> "$GITHUB_ENV"
echo "medium_no_fix=$medium_no_fix" >> "$GITHUB_ENV"
echo "low_count=$low_count" >> "$GITHUB_ENV"
echo "low_no_fix=$low_no_fix" >> "$GITHUB_ENV"
echo "MAX_CRITICAL_ISSUES=$MAX_CRITICAL_ISSUES" >> "$GITHUB_ENV"
echo "MAX_HIGH_ISSUES=$MAX_HIGH_ISSUES" >> "$GITHUB_ENV"
echo "MAX_MEDIUM_ISSUES=$MAX_MEDIUM_ISSUES" >> "$GITHUB_ENV"
echo "MAX_LOW_ISSUES=$MAX_LOW_ISSUES" >> "$GITHUB_ENV"

echo "Calculating SLA breaches..."
current_time=$(date +%s)

count_sla_breaches() {
  local severity=$1
  local has_fix=$2
  local threshold=$3
  if [ "$has_fix" = "true" ]; then
    echo "$SNYK_DATA" | jq --arg current "$current_time" --arg threshold "$threshold" --arg sev "$severity" -r '
      [.vulnerabilities[]? |
       select(.severity == $sev and (.isUpgradable == true or .isPatchable == true)) |
       select(.publicationTime != null) |
       .publicationTime |= (. | sub("\\.[0-9]+Z$"; "Z")) |
       select(($current | tonumber) - (.publicationTime | fromdateiso8601) > ($threshold | tonumber * 86400))] |
      length' 2>/dev/null || echo 0
  else
    echo "$SNYK_DATA" | jq --arg current "$current_time" --arg threshold "$threshold" --arg sev "$severity" -r '
      [.vulnerabilities[]? |
       select(.severity == $sev and (.isUpgradable != true and .isPatchable != true)) |
       select(.publicationTime != null) |
       .publicationTime |= (. | sub("\\.[0-9]+Z$"; "Z")) |
       select(($current | tonumber) - (.publicationTime | fromdateiso8601) > ($threshold | tonumber * 86400))] |
      length' 2>/dev/null || echo 0
  fi
}

critical_sla_breaches=$(count_sla_breaches "critical" "true" "$SLA_CRITICAL_WITH_FIX")
high_sla_breaches=$(count_sla_breaches "high" "true" "$SLA_HIGH_WITH_FIX")
medium_sla_breaches=$(count_sla_breaches "medium" "true" "$SLA_MEDIUM_WITH_FIX")
low_sla_breaches=$(count_sla_breaches "low" "true" "$SLA_LOW_WITH_FIX")

critical_sla_breaches_no_fix=$(count_sla_breaches "critical" "false" "$SLA_CRITICAL_NO_FIX")
high_sla_breaches_no_fix=$(count_sla_breaches "high" "false" "$SLA_HIGH_NO_FIX")
medium_sla_breaches_no_fix=$(count_sla_breaches "medium" "false" "$SLA_MEDIUM_NO_FIX")
low_sla_breaches_no_fix=$(count_sla_breaches "low" "false" "$SLA_LOW_NO_FIX")


echo "Exporting SLA counts to GITHUB_ENV..."
echo "critical_sla_breaches=$critical_sla_breaches" >> "$GITHUB_ENV"
echo "critical_sla_breaches_no_fix=$critical_sla_breaches_no_fix" >> "$GITHUB_ENV"
echo "high_sla_breaches=$high_sla_breaches" >> "$GITHUB_ENV"
echo "high_sla_breaches_no_fix=$high_sla_breaches_no_fix" >> "$GITHUB_ENV"
echo "medium_sla_breaches=$medium_sla_breaches" >> "$GITHUB_ENV"
echo "medium_sla_breaches_no_fix=$medium_sla_breaches_no_fix" >> "$GITHUB_ENV"
echo "low_sla_breaches=$low_sla_breaches" >> "$GITHUB_ENV"
echo "low_sla_breaches_no_fix=$low_sla_breaches_no_fix" >> "$GITHUB_ENV"
echo "SLA_CRITICAL_WITH_FIX=$SLA_CRITICAL_WITH_FIX" >> "$GITHUB_ENV"
echo "SLA_HIGH_WITH_FIX=$SLA_HIGH_WITH_FIX" >> "$GITHUB_ENV"
echo "SLA_MEDIUM_WITH_FIX=$SLA_MEDIUM_WITH_FIX" >> "$GITHUB_ENV"
echo "SLA_LOW_WITH_FIX=$SLA_LOW_WITH_FIX" >> "$GITHUB_ENV"
echo "SLA_CRITICAL_NO_FIX=$SLA_CRITICAL_NO_FIX" >> "$GITHUB_ENV"
echo "SLA_HIGH_NO_FIX=$SLA_HIGH_NO_FIX" >> "$GITHUB_ENV"
echo "SLA_MEDIUM_NO_FIX=$SLA_MEDIUM_NO_FIX" >> "$GITHUB_ENV"
echo "SLA_LOW_NO_FIX=$SLA_LOW_NO_FIX" >> "$GITHUB_ENV"

echo "Generating summary and checking thresholds..."
fail_build=false
warn_build=false
failure_reasons=""
warning_reasons=""

if [ "$critical_count" -gt "$MAX_CRITICAL_ISSUES" ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ CRITICAL SEVERITY THRESHOLD BREACHED: Found $critical_count critical issues (max allowed: $MAX_CRITICAL_ISSUES)\n"
fi
if [ "$high_count" -gt "$MAX_HIGH_ISSUES" ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ HIGH SEVERITY THRESHOLD BREACHED: Found $high_count high issues (max allowed: $MAX_HIGH_ISSUES)\n"
fi
if [ "$medium_count" -gt "$MAX_MEDIUM_ISSUES" ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ MEDIUM SEVERITY THRESHOLD BREACHED: Found $medium_count medium issues (max allowed: $MAX_MEDIUM_ISSUES)\n"
fi
if [ "$low_count" -gt "$MAX_LOW_ISSUES" ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ LOW SEVERITY THRESHOLD BREACHED: Found $low_count low issues (max allowed: $MAX_LOW_ISSUES)\n"
fi

if [ "$critical_sla_breaches" -gt 0 ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ CRITICAL SLA BREACHES (with fixes): $critical_sla_breaches\n"
fi
if [ "$critical_sla_breaches_no_fix" -gt 0 ]; then
  warn_build=true
  warning_reasons="${warning_reasons}⚠️ CRITICAL SLA BREACHES (no fixes): $critical_sla_breaches_no_fix\n"
fi
if [ "$high_sla_breaches" -gt 0 ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ HIGH SLA BREACHES (with fixes): $high_sla_breaches\n"
fi
if [ "$high_sla_breaches_no_fix" -gt 0 ]; then
  warn_build=true
  warning_reasons="${warning_reasons}⚠️ HIGH SLA BREACHES (no fixes): $high_sla_breaches_no_fix\n"
fi
if [ "$medium_sla_breaches" -gt 0 ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ MEDIUM SLA BREACHES (with fixes): $medium_sla_breaches\n"
fi
if [ "$medium_sla_breaches_no_fix" -gt 0 ]; then
  warn_build=true
  warning_reasons="${warning_reasons}⚠️ MEDIUM SLA BREACHES (no fixes): $medium_sla_breaches_no_fix\n"
fi
if [ "$low_sla_breaches" -gt 0 ]; then
  fail_build=true
  failure_reasons="${failure_reasons}❌ LOW SLA BREACHES (with fixes): $low_sla_breaches\n"
fi
if [ "$low_sla_breaches_no_fix" -gt 0 ]; then
  warn_build=true
  warning_reasons="${warning_reasons}⚠️ LOW SLA BREACHES (no fixes): $low_sla_breaches_no_fix\n"
fi

echo "fail_build=$fail_build" >> "$GITHUB_OUTPUT" || true
echo "fail_build=$fail_build" >> "$GITHUB_ENV" || true
echo "warn_build=$warn_build" >> "$GITHUB_OUTPUT" || true
echo "warn_build=$warn_build" >> "$GITHUB_ENV" || true

# Write summary to the step summary file
{
  echo "### 🔒 Security Scan Results"
  echo
  echo "> ℹ️ Note: Only vulnerabilities with available fixes (upgrades or patches) are counted toward thresholds."
  echo
  echo "| Check Type | Count (with fixes) | Without fixes | Threshold | Result |"
  echo "|------------|-------------------|---------------|-----------|--------|"
  if [ "$critical_count" -gt "$MAX_CRITICAL_ISSUES" ]; then
    echo "| 🔴 Critical Severity | $critical_count | $critical_no_fix | $MAX_CRITICAL_ISSUES | ❌ Failed |"
  else
    echo "| 🔴 Critical Severity | $critical_count | $critical_no_fix | $MAX_CRITICAL_ISSUES | ✅ Passed |"
  fi
  if [ "$high_count" -gt "$MAX_HIGH_ISSUES" ]; then
    echo "| 🟠 High Severity | $high_count | $high_no_fix | $MAX_HIGH_ISSUES | ❌ Failed |"
  else
    echo "| 🟠 High Severity | $high_count | $high_no_fix | $MAX_HIGH_ISSUES | ✅ Passed |"
  fi
  if [ "$medium_count" -gt "$MAX_MEDIUM_ISSUES" ]; then
    echo "| 🟡 Medium Severity | $medium_count | $medium_no_fix | $MAX_MEDIUM_ISSUES | ❌ Failed |"
  else
    echo "| 🟡 Medium Severity | $medium_count | $medium_no_fix | $MAX_MEDIUM_ISSUES | ✅ Passed |"
  fi
  if [ "$low_count" -gt "$MAX_LOW_ISSUES" ]; then
    echo "| 🔵 Low Severity | $low_count | $low_no_fix | $MAX_LOW_ISSUES | ❌ Failed |"
  else
    echo "| 🔵 Low Severity | $low_count | $low_no_fix | $MAX_LOW_ISSUES | ✅ Passed |"
  fi
  echo

  total_sla_breaches=$((critical_sla_breaches + high_sla_breaches + medium_sla_breaches + low_sla_breaches + critical_sla_breaches_no_fix + high_sla_breaches_no_fix + medium_sla_breaches_no_fix + low_sla_breaches_no_fix))
  
  echo "### ⏱️ SLA Breach Summary"
  echo
  if [ "$total_sla_breaches" -gt 0 ]; then
    echo "> ⚠️ Warning: The following vulnerabilities have exceeded their SLA thresholds (days since publication)."
  else
    echo "> ✅ No SLA breaches detected. All vulnerabilities are within acceptable time thresholds."
  fi
  echo
  echo "| Severity | Breaches (with fixes) | Breaches (no fixes) | SLA Threshold (with/no fixes) | Status |"
  echo "|----------|----------------------|---------------------|------------------------------|--------|"
  sla_status() {
    local with_fix=$1 no_fix=$2
    if [ "$with_fix" -gt 0 ] && [ "$no_fix" -gt 0 ]; then echo "❌ Failed / ⚠️ Warning"
    elif [ "$with_fix" -gt 0 ]; then echo "❌ Failed"
    elif [ "$no_fix" -gt 0 ]; then echo "⚠️ Warning"
    else echo "✅ Passed"; fi
  }
  echo "| 🔴 Critical | $critical_sla_breaches | $critical_sla_breaches_no_fix | $SLA_CRITICAL_WITH_FIX / $SLA_CRITICAL_NO_FIX days | $(sla_status "$critical_sla_breaches" "$critical_sla_breaches_no_fix") |"
  echo "| 🟠 High | $high_sla_breaches | $high_sla_breaches_no_fix | $SLA_HIGH_WITH_FIX / $SLA_HIGH_NO_FIX days | $(sla_status "$high_sla_breaches" "$high_sla_breaches_no_fix") |"
  echo "| 🟡 Medium | $medium_sla_breaches | $medium_sla_breaches_no_fix | $SLA_MEDIUM_WITH_FIX / $SLA_MEDIUM_NO_FIX days | $(sla_status "$medium_sla_breaches" "$medium_sla_breaches_no_fix") |"
  echo "| 🔵 Low | $low_sla_breaches | $low_sla_breaches_no_fix | $SLA_LOW_WITH_FIX / $SLA_LOW_NO_FIX days | $(sla_status "$low_sla_breaches" "$low_sla_breaches_no_fix") |"
  echo

  if [ "$critical_no_fix" -gt 0 ] || [ "$high_no_fix" -gt 0 ] || [ "$medium_no_fix" -gt 0 ] || [ "$low_no_fix" -gt 0 ]; then
    echo "### ℹ️ Vulnerabilities Without Available Fixes (Informational Only)"
    echo
    echo "The following vulnerabilities were detected but **do not have fixes available** (no upgrade or patch). These are excluded from failure thresholds:"
    echo
    echo "- Critical without fixes: **$critical_no_fix**"
    echo "- High without fixes: **$high_no_fix**"
    echo "- Medium without fixes: **$medium_no_fix**"
    echo "- Low without fixes: **$low_no_fix**"
    echo
  fi

  if [ "$fail_build" = true ]; then
    echo
    echo "❌ BUILD FAILED - Security checks failed"
    echo
    echo -e "$failure_reasons"
  fi
  if [ "$warn_build" = true ]; then
    echo
    echo "⚠️ WARNINGS - SLA breaches for issues without available fixes"
    echo
    echo -e "$warning_reasons"
  fi
  if [ "$fail_build" = false ] && [ "$warn_build" = false ]; then
    echo
    echo "✅ BUILD PASSED - All security checks passed"
    echo
  elif [ "$fail_build" = false ] && [ "$warn_build" = true ]; then
    echo
    echo "⚠️ BUILD PASSED WITH WARNINGS"
    echo
  fi
} >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true

if [ "$fail_build" = true ]; then
  echo "fail_build=true" >> "$GITHUB_OUTPUT" || true
  exit 1
else
  echo "fail_build=false" >> "$GITHUB_OUTPUT" || true
  exit 0
fi
