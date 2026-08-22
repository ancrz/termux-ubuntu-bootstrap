#!/usr/bin/env bash

set -euo pipefail

COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_DIR
REPO_ROOT="$(cd -- "${COMMON_DIR}/.." && pwd)"
readonly REPO_ROOT

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

declare -a RUN_ERRORS=()
RUN_LOG=''
RUN_NAME=''

# These packages make the setup script self-hosting on a minimal Ubuntu rootfs.
# They must be available before runtime installers can use curl, jq, tar, or
# sha256sum. They are also part of the declared profile where appropriate.
readonly BOOTSTRAP_PACKAGES=(ca-certificates coreutils curl jq tar)

init_run() {
  RUN_NAME="$1"
  local log_dir timestamp
  log_dir='/var/log/termux-ubuntu-bootstrap'
  mkdir -p "${log_dir}"
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  RUN_LOG="${log_dir}/${RUN_NAME}-${timestamp}.log"
  : > "${RUN_LOG}"
  local -a old_logs=()
  local old_log
  while IFS= read -r old_log; do
    [[ -n "${old_log}" ]] && old_logs+=("${old_log}")
  done <<< "$(ls -1t "${log_dir}/${RUN_NAME}-"*.log 2>/dev/null || true)"
  if (( ${#old_logs[@]} > 5 )); then
    rm -f -- "${old_logs[@]:5}"
  fi
  log_info "Run log: ${RUN_LOG}"
}

run_step() {
  local name="$1"; shift
  log_info "${name}"
  if "$@" >> "${RUN_LOG}" 2>&1; then
    log_info "${name}: ok"
    return 0
  fi
  local status=$?
  RUN_ERRORS+=("${name} (exit ${status}; see ${RUN_LOG})")
  log_error "${name}: failed"
  return 1
}

finish_run() {
  if (( ${#RUN_ERRORS[@]} == 0 )); then
    log_info 'Run completed successfully.'
    return 0
  fi
  log_error "Run completed with ${#RUN_ERRORS[@]} error(s):"
  printf ' - %s\n' "${RUN_ERRORS[@]}" >&2
  return 1
}

acquire_ubuntu_lock() {
  local lock_dir='/var/lock/termux-ubuntu-bootstrap-ubuntu'
  mkdir "${lock_dir}" 2>/dev/null || { log_error 'Another setup or updater run is in progress.'; exit 1; }
  trap 'rmdir "${lock_dir}" 2>/dev/null || true' EXIT
}

require_apt_commands() {
  local command
  for command in apt-get dpkg-query; do
    command -v "${command}" >/dev/null 2>&1 || { log_error "Required Ubuntu command missing: ${command}"; exit 1; }
  done
}

require_runtime_commands() {
  local command
  for command in apt-get curl dpkg-query jq sha256sum tar; do
    command -v "${command}" >/dev/null 2>&1 || { log_error "Required setup dependency missing: ${command}. Run scripts/02-setup-ubuntu-base.sh first."; exit 1; }
  done
}

install_bootstrap_packages() {
  apt-get -o DPkg::Lock::Timeout=60 install --yes "${BOOTSTRAP_PACKAGES[@]}"
  require_runtime_commands
}

check_ubuntu_storage() {
  local free_kib
  free_kib="$(df -Pk / | awk 'NR == 2 {print $4}')"
  [[ "${free_kib}" =~ ^[0-9]+$ ]] || { log_error 'Cannot determine free Ubuntu storage.'; exit 1; }
  (( free_kib >= 1048576 )) || { log_error 'At least 1 GiB free space is required for setup/update.'; exit 1; }
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error 'Run this script as root inside the Ubuntu PRoot environment.'
    exit 1
  fi
}

require_ubuntu() {
  if [[ ! -f /etc/os-release ]] || ! grep -qi '^ID=ubuntu' /etc/os-release; then
    log_error 'This script supports Ubuntu PRoot only.'
    exit 1
  fi
}

load_profile() {
  # shellcheck source=config/package-profile.sh
  source "${REPO_ROOT}/config/package-profile.sh"
}

load_profile_packages() {
  PROFILE_PACKAGES=()
  local package
  while IFS= read -r package; do
    PROFILE_PACKAGES+=("${package}")
  done <<< "$(profile_packages)"
}

is_installed() {
  dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx 'installed'
}

installed_profile_packages() {
  local package
  load_profile_packages
  for package in "${PROFILE_PACKAGES[@]}"; do
    if is_installed "${package}"; then
      printf '%s\n' "${package}"
    fi
  done
}

ubuntu_preflight() {
  require_root
  require_ubuntu
  [[ -r "${REPO_ROOT}/config/package-profile.sh" && -r "${REPO_ROOT}/lib/runtimes.sh" ]] || { log_error 'Repository files are incomplete.'; exit 1; }
  require_apt_commands
  check_ubuntu_storage
  acquire_ubuntu_lock
}
