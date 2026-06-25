# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for parsel (Python / Atheris). Builds on the org base image
# (ghcr.io/mayhemheroes/base) which already ships debian + clang/llvm + libFuzzer + python3 +
# the non-root identities + the build-contract ENV. This layer adds the Python toolchain bits
# (venv + headers), bakes an OFFLINE wheelhouse (so mayhem/build.sh re-runs air-gapped), then
# builds the harness + installs the project & test suite via mayhem/build.sh.
#
# Build (from the repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) -t parsel-commit:test .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (never a baked ENV — an empty value breaks clang / apt pinning).
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG MAYHEM_JOBS=

# --- root: Python toolchain + offline wheelhouse -----------------------------------------------
# python3-venv (ensurepip) + python3-dev (headers, needed to compile the Atheris native module).
# Re-pin apt to SOURCE_DATE_EPOCH for reproducibility when it is provided.
USER root
RUN { [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true; } \
 && apt-get update \
 && apt-get install -yq --no-install-recommends python3-venv python3-dev \
 && rm -rf /var/lib/apt/lists/*

# Bake the wheelhouse ONLINE here so mayhem/build.sh can install everything offline later.
# `pip wheel` pre-COMPILES Atheris (sdist) into a reusable wheel — the air-gapped re-run never
# touches PyPI or a compiler for deps. Includes parsel's runtime deps, the hatchling build
# backend (for the editable install), and the test stack (pytest/sybil/psutil/pytest-cov).
RUN python3 -m pip wheel --no-cache-dir --wheel-dir=/opt/wheels \
        pip setuptools wheel \
        atheris \
        cssselect jmespath lxml packaging w3lib \
        hatchling editables \
        pytest "pytest-cov>=7.0.0" sybil psutil \
 && mkdir -p /opt/venv \
 && chown -R 2000:2000 /opt/wheels /opt/venv

# --- mayhem: build harness + install project/tests --------------------------------------------
USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Functional oracle: a failing suite fails the image build.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
