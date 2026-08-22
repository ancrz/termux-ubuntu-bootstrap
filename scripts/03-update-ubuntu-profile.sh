#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=lib/runtimes.sh
source "${SCRIPT_DIR}/../lib/runtimes.sh"

ubuntu_preflight
init_run 'update'
require_runtime_commands
load_profile
packages=()
while IFS= read -r package; do
  packages+=("${package}")
done <<< "$(installed_profile_packages)"
if run_step 'Refresh Ubuntu package metadata' apt-get -o DPkg::Lock::Timeout=60 update; then
  if (( ${#packages[@]} > 0 )); then
    run_step "Update ${#packages[@]} installed profile packages" apt-get -o DPkg::Lock::Timeout=60 install --yes --only-upgrade "${packages[@]}" || true
  else
    log_warn 'No managed APT profile packages are installed; continuing with runtime maintenance.'
  fi
else
  RUN_ERRORS+=('Profile package update skipped because APT metadata refresh failed.')
fi
run_step 'Update uv and Python' install_uv_python || true
run_step 'Update Node LTS' install_node_lts || true
run_step 'Update stable Go' install_go_stable || true
run_step 'Clean APT cache' apt-get clean || true
finish_run
