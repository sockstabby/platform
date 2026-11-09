#!/bin/sh
# Fails if the Terraform version drifts between its single source and anything that must match it.
#   source : TERRAFORM_VERSION env var; if unset, read from .spacelift/config.yml (the definition)
#   checks : every `required_version` in bootstrap/ and components/ (must be an exact X.Y.Z, equal),
#            and the `terraform` line in .tool-versions
# Runs in the Spacelift install hook and in CI (.github/workflows/terraform-version-check.yml).
# POSIX sh (Alpine runner).
set -eu

ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

defined="$(sed -n 's/^[[:space:]]*TERRAFORM_VERSION:[[:space:]]*"\{0,1\}\([^"[:space:]]*\)"\{0,1\}.*$/\1/p' .spacelift/config.yml | head -n1)"
[ -n "$defined" ] || { echo "drift-check: TERRAFORM_VERSION not found in .spacelift/config.yml" >&2; exit 1; }
want="${TERRAFORM_VERSION:-$defined}"

fail=0
err() { echo "drift-check: $*" >&2; fail=1; }

echo "$want" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || err "TERRAFORM_VERSION '$want' is not an exact X.Y.Z version"
[ "$want" = "$defined" ] || err "env TERRAFORM_VERSION=$want differs from .spacelift/config.yml ($defined)"

found=0
for f in $(find bootstrap components -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | sort); do
  lines="$(grep -n 'required_version' "$f" | grep -v '^[0-9]*:[[:space:]]*#' || true)"
  [ -n "$lines" ] || continue
  echo "$lines" | while IFS= read -r l; do
    v="$(printf '%s' "$l" | sed -n 's/.*required_version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [ "$v" != "$want" ]; then
      echo "drift-check: $f:${l%%:*} required_version = \"$v\", expected exactly \"$want\"" >&2
      exit 1
    fi
  done || fail=1
  found=$((found + 1))
done
[ "$found" -gt 0 ] || err "no required_version found under bootstrap/ or components/"

tv="$(awk '$1 == "terraform" { print $2 }' .tool-versions 2>/dev/null || true)"
[ "$tv" = "$want" ] || err ".tool-versions terraform = '${tv:-<missing>}', expected '$want'"

if [ "$fail" -ne 0 ]; then
  echo "drift-check: FAILED. Update every location to match TERRAFORM_VERSION in .spacelift/config.yml." >&2
  exit 1
fi
echo "drift-check: OK (terraform $want; $found file(s) with required_version, .tool-versions)"
