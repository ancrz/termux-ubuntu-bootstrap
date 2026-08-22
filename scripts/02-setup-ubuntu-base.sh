#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=lib/runtimes.sh
source "${SCRIPT_DIR}/../lib/runtimes.sh"

ubuntu_preflight
init_run 'setup'
load_profile
load_profile_packages
packages=("${PROFILE_PACKAGES[@]}")
if run_step 'Refresh Ubuntu package metadata' apt-get -o DPkg::Lock::Timeout=60 update; then
  if run_step 'Install bootstrap prerequisites' install_bootstrap_packages; then
    run_step "Reconcile ${#packages[@]} profile packages" apt-get -o DPkg::Lock::Timeout=60 install --yes "${packages[@]}" || true
  else
    RUN_ERRORS+=('Profile package reconciliation skipped because bootstrap prerequisites could not be installed.')
  fi
else
  RUN_ERRORS+=('Profile package reconciliation skipped because APT metadata refresh failed.')
fi
run_step 'Install or update uv and Python' install_uv_python || true
run_step 'Install or update Node LTS' install_node_lts || true
run_step 'Install or update stable Go' install_go_stable || true
run_step 'Clean APT cache' apt-get clean || true
finish_run
