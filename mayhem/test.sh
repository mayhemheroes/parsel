#!/usr/bin/env bash
#
# mayhem/test.sh — RUN parsel's own pytest suite (deps + editable install already done by
# mayhem/build.sh) as a behavioral oracle, and emit a CTRF (https://ctrf.io) summary.
#
# The suite (parsel doctests + tests/) asserts real selector/XPath/CSS behavior — known-answer
# results — so a PATCH that no-ops the library FAILS here (anti-reward-hacking, §6.3). It runs
# under the COPIED venv interpreter /opt/venv/bin/python, which lives outside the system prefixes:
# the sabotage check's neuter exits that interpreter immediately, so the suite collapses (no
# junit report) and the oracle is correctly detected as behavioral.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

PY=/opt/venv/bin/python
JUNIT=/tmp/parsel-junit.xml

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

[ -x "$PY" ] || { echo "test.sh: $PY missing — build.sh did not create the venv" >&2; emit_ctrf pytest 0 1; exit 1; }

rm -f "$JUNIT"
# Run the project's KAT suite: parsel doctests (--doctest-modules from pyproject) + tests/.
"$PY" -m pytest -p no:cacheprovider -q --junitxml="$JUNIT" parsel tests
echo "pytest exit: $?"

if [ ! -s "$JUNIT" ]; then
  echo "test.sh: no junit report produced — suite did not run" >&2
  emit_ctrf pytest 0 1
  exit 1
fi

# Map junit counts -> CTRF.
read -r TESTS FAILURES ERRORS SKIPPED < <("$PY" - "$JUNIT" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
suites = [root] if root.tag == "testsuite" else root.findall("testsuite")
t = f = e = s = 0
for ts in suites:
    t += int(ts.get("tests", 0)); f += int(ts.get("failures", 0))
    e += int(ts.get("errors", 0)); s += int(ts.get("skipped", 0))
print(t, f, e, s)
PYEOF
)
FAILED=$(( FAILURES + ERRORS ))
PASSED=$(( TESTS - FAILED - SKIPPED ))
[ "$PASSED" -ge 0 ] || PASSED=0

emit_ctrf "pytest" "$PASSED" "$FAILED" "$SKIPPED"
