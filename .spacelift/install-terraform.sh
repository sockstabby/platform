#!/bin/sh
# Spacelift hook (before_init / before_apply / before_destroy): install the pinned Terraform.
#  - version comes from $TERRAFORM_VERSION (set once in .spacelift/config.yml)
#  - downloads the zip + SHA256SUMS from releases.hashicorp.com, verifies the checksum, FAILS on mismatch
#  - idempotent: skips the download if the right version is already installed
#  - runs the version drift check before doing anything
# POSIX sh on purpose: the default runner image is Alpine (bash is not guaranteed).
set -eu

INSTALL_DIR="${TF_INSTALL_DIR:-/mnt/workspace/.bin}"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BASE_URL="https://releases.hashicorp.com/terraform"

log() { printf '[install-terraform] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

V="${TERRAFORM_VERSION:-}"
[ -n "$V" ] || die "TERRAFORM_VERSION is not set (expected from .spacelift/config.yml stack_defaults.environment)"

# 1. Version drift check: required_version everywhere must equal $TERRAFORM_VERSION.
sh "$REPO_ROOT/scripts/check-terraform-version.sh"

# 2. Already installed?
if [ -x "$INSTALL_DIR/terraform" ] && "$INSTALL_DIR/terraform" version 2>/dev/null | head -n1 | grep -qx "Terraform v$V"; then
  log "terraform $V already installed at $INSTALL_DIR"
  exit 0
fi

# 3. Platform
case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) die "unsupported OS $(uname -s)" ;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) die "unsupported arch $(uname -m)" ;; esac
zip="terraform_${V}_${os}_${arch}.zip"
sums="terraform_${V}_SHA256SUMS"

# 4. Tools (the runner image's contents are not documented, so accept common alternatives)
if command -v curl >/dev/null 2>&1; then fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then fetch() { wget -q -O "$2" "$1"; }
else die "need curl or wget"; fi
if command -v sha256sum >/dev/null 2>&1; then sha256() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else die "need sha256sum or shasum"; fi
if command -v unzip >/dev/null 2>&1; then unz() { unzip -o -q "$1" terraform -d "$2"; }
elif command -v busybox >/dev/null 2>&1; then unz() { busybox unzip -o -q "$1" terraform -d "$2"; }
else die "need unzip (or busybox)"; fi

# 5. Download + verify
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
log "downloading $zip"
fetch "$BASE_URL/$V/$zip" "$tmp/$zip"
fetch "$BASE_URL/$V/$sums" "$tmp/$sums"

expected="$(awk -v f="$zip" '$2 == f { print $1 }' "$tmp/$sums")"
[ -n "$expected" ] || die "$zip not listed in $sums"
actual="$(sha256 "$tmp/$zip")"
if [ "$expected" != "$actual" ]; then
  die "checksum MISMATCH for $zip: expected $expected, got $actual"
fi
log "checksum OK ($actual)"

# 6. Install
mkdir -p "$INSTALL_DIR"
unz "$tmp/$zip" "$tmp/out"
mv "$tmp/out/terraform" "$INSTALL_DIR/terraform"
chmod 0755 "$INSTALL_DIR/terraform"

got="$("$INSTALL_DIR/terraform" version | head -n1)"
[ "$got" = "Terraform v$V" ] || die "installed binary reports '$got', expected 'Terraform v$V'"
log "installed $got at $INSTALL_DIR/terraform"

# Best effort for anything later in the same shell; workflow.yml uses the absolute path anyway.
case ":$PATH:" in *":$INSTALL_DIR:"*) ;; *) export PATH="$INSTALL_DIR:$PATH" ;; esac
