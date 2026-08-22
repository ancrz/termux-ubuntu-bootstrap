#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/package-profile.sh
source "${TEST_DIR}/../config/package-profile.sh"

packages=()
while IFS= read -r package; do
  packages+=("${package}")
done <<< "$(profile_packages)"
[[ "${#packages[@]}" -gt 0 ]]
[[ "$(printf '%s\n' "${packages[@]}" | sort -u | wc -l)" -eq "${#packages[@]}" ]]

for required in nmap netcat-openbsd ripgrep shellcheck shfmt; do
  printf '%s\n' "${packages[@]}" | grep -qx "${required}"
done

repo_root="$(cd -- "${TEST_DIR}/.." && pwd)"
grep -q 'python upgrade' "${repo_root}/lib/runtimes.sh"
grep -q 'setup_lts.x' "${repo_root}/lib/runtimes.sh"
grep -q 'sha256sum --check --status' "${repo_root}/lib/runtimes.sh"
grep -q 'MINIMUM_INSTALL_KIB' "${repo_root}/scripts/01-bootstrap-termux-ubuntu.sh"
grep -q 'Another bootstrap run is already in progress' "${repo_root}/scripts/01-bootstrap-termux-ubuntu.sh"
grep -q 'cannot start' "${repo_root}/scripts/01-bootstrap-termux-ubuntu.sh"

printf 'profile consistency: ok (%s packages)\n' "${#packages[@]}"
