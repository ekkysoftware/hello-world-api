#!/usr/bin/env bash
# Build a Lambda-ready zip at dist/lambda.zip.
#
# Env:
#   OUT   output zip path (default: dist/lambda.zip)
#
# The target runtime is read from .python-version, which is the single source of
# truth for uv, this script and the workflows. It must match the Lambda runtime
# and match the version uv.lock was resolved for (changing it needs `uv lock`).
#
# Produces a reproducible artifact: dependency wheels are pinned by uv.lock, and
# archive entries are sorted with normalized mtimes, so identical inputs give an
# identical sha256 (CI reports it and it only changes when the code does).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_VERSION="$(tr -d '[:space:]' < "$ROOT/.python-version")"
OUT="${OUT:-$ROOT/dist/lambda.zip}"
STAGE="$ROOT/build/lambda"

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$(dirname "$OUT")"

echo "==> resolving dependencies (python $PYTHON_VERSION)"
uv export \
  --quiet \
  --frozen \
  --no-dev \
  --no-emit-project \
  --format requirements-txt \
  --output-file "$STAGE/requirements.txt"

echo "==> installing wheels for x86_64-manylinux2014 / cp${PYTHON_VERSION//./}"
uv pip install \
  --quiet \
  --no-compile \
  --python-version "$PYTHON_VERSION" \
  --python-platform x86_64-manylinux2014 \
  --target "$STAGE" \
  --requirement "$STAGE/requirements.txt"

rm -f "$STAGE/requirements.txt" "$STAGE/.lock"

echo "==> copying application code"
# Package is copied to the zip root so the handler is
# hello_world_api.main.handler
cp -r "$ROOT/src/hello_world_api" "$STAGE/hello_world_api"
find "$STAGE/hello_world_api" -name '__pycache__' -type d -prune -exec rm -rf {} +

echo "==> archiving"
# Normalize mtimes so identical inputs produce a byte-identical zip. Without this
# the Lambda source_code_hash changes on every build and Pulumi redeploys a
# function whose code did not change.
find "$STAGE" -exec touch -d '2020-01-01T00:00:00Z' {} +
(cd "$STAGE" && find . -type f | LC_ALL=C sort | zip -q -X "$OUT" -@)

echo "==> dist/lambda.zip $(du -h "$OUT" | cut -f1)"
echo "==> sha256 $(sha256sum "$OUT" | cut -d' ' -f1)"
