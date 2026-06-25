#!/usr/bin/env bash
#
# mayhem/build.sh — build the parsel Atheris (Python) fuzz harness + install the project
# and its test suite. Re-runnable OFFLINE: every Python dependency is resolved from the
# in-image wheelhouse baked by mayhem/Dockerfile (/opt/wheels), never from PyPI
# (SPEC §6.5 — "Python (pip / atheris): bake a wheelhouse and install with
# `pip install --no-index --find-links=<dir>`").
#
# Runs as `mayhem` in /mayhem on top of ghcr.io/mayhemheroes/base. parsel is pure Python,
# so there is no C library to instrument; the memory-safety surface (lxml) ships as a
# prebuilt wheel and Atheris drives Python-level coverage. We therefore do NOT compile the
# project with $SANITIZER_FLAGS (it would be a no-op for Python) — the only native artifact
# is the libFuzzer launcher shim, built with $DEBUG_FLAGS so Mayhem triage can read it.
set -euo pipefail

# clang rejects an empty SOURCE_DATE_EPOCH — unset it if blank.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build contract (from the base ENV), with parameter-expansion fallbacks. SANITIZER_FLAGS is
# referenced for contract completeness; parsel is Python so it is not applied to project code.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"          # DWARF < 4 — Mayhem triage can't read DWARF >= 4
: "${CC:=clang}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC MAYHEM_JOBS

WHEELS=/opt/wheels
VENV=/opt/venv
PY="$VENV/bin/python"

cd "$SRC"

# 1) Python environment — a COPIED venv (not symlinked) at /opt/venv. `--copies` matters:
#    the venv interpreter must be a real ELF outside the system prefixes so (a) the libFuzzer
#    shim can exec a stable path and (b) the anti-reward-hack sabotage check can neuter it.
if [ ! -x "$PY" ]; then
  python3 -m venv --copies "$VENV"
fi

# 2) Install everything OFFLINE from the baked wheelhouse: runtime deps, Atheris, the build
#    backend, and the test stack. --no-index + --find-links keeps it air-gapped.
"$PY" -m pip install --no-index --find-links="$WHEELS" --upgrade pip setuptools wheel
"$PY" -m pip install --no-index --find-links="$WHEELS" \
    atheris \
    cssselect jmespath lxml packaging w3lib \
    hatchling editables \
    pytest "pytest-cov>=7.0.0" sybil psutil

# 3) Install parsel itself EDITABLE so a PATCH-tier edit to /mayhem/parsel is exercised by
#    both the harness (`import parsel`) and the test suite, without a reinstall. Build
#    isolation is disabled because hatchling is already present (offline).
"$PY" -m pip install --no-index --find-links="$WHEELS" --no-build-isolation -e .

# 4) Native artifact: the libFuzzer launcher shim (an ELF `cmd:` target Mayhem accepts).
#    $DEBUG_FLAGS gives it DWARF < 4; no sanitizer (nothing C to instrument here).
$CC $DEBUG_FLAGS "$SRC/mayhem/fuzz_extract_shim.c" -o /mayhem/fuzz_extract_shim

echo "build.sh: OK — venv=$VENV shim=/mayhem/fuzz_extract_shim"
