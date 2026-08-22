#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

fresh=false
assume_yes=false
readonly MINIMUM_INSTALL_KIB=$((4 * 1024 * 1024))
readonly RESERVED_FREE_PERCENT=20

usage() {
  cat <<'EOF'
Usage: 01-bootstrap-termux-ubuntu.sh [--fresh] [--yes]

Installs proot-distro and ensures an Ubuntu PRoot installation exists.
Without --fresh, an existing Ubuntu rootfs is preserved.
With --fresh, the existing Ubuntu rootfs is removed and recreated.
--yes confirms a destructive --fresh run when standard input is not a terminal.
EOF
}

fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

format_kib() { awk -v kib="$1" 'BEGIN { printf "%.1f GiB", kib / 1048576 }'; }

require_termux_user() {
  [[ "${EUID}" -ne 0 ]] || fail 'Do not run proot-distro as root; use the regular Termux user.'
  [[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || fail 'This script must run inside Termux.'
  command -v pkg >/dev/null 2>&1 || fail 'The Termux pkg command is unavailable.'
}

acquire_lock() {
  lock_dir="${PREFIX}/var/lock/termux-ubuntu-bootstrap"
  mkdir -p "${PREFIX}/var/lock"
  mkdir "${lock_dir}" 2>/dev/null || fail 'Another bootstrap run is already in progress.'
  trap 'rmdir "${lock_dir}" 2>/dev/null || true' EXIT
}

check_storage() {
  local available_kib usable_kib
  available_kib="$(df -Pk "${PREFIX}" | awk 'NR == 2 { print $4 }')"
  [[ "${available_kib}" =~ ^[0-9]+$ ]] || fail 'Could not determine free storage.'
  usable_kib=$((available_kib * (100 - RESERVED_FREE_PERCENT) / 100))
  printf '[INFO] Available storage: %s; reserving %s%% free after installation.\n' "$(format_kib "${available_kib}")" "${RESERVED_FREE_PERCENT}"
  if (( usable_kib < MINIMUM_INSTALL_KIB )); then
    fail "Ubuntu requires at least $(format_kib "${MINIMUM_INSTALL_KIB}") plus ${RESERVED_FREE_PERCENT}% free space; free storage is insufficient."
  fi
}

ubuntu_installed() {
  proot-distro list 2>/dev/null | grep -Eq '^[[:space:]]*\*[[:space:]]+ubuntu([[:space:]]|$)'
}

confirm_fresh() {
  [[ "${fresh}" == true ]] || return 0
  if [[ "${assume_yes}" == true ]]; then return 0; fi
  [[ -t 0 ]] || fail 'Use --fresh --yes for a non-interactive destructive run.'
  read -r -p 'Replace the existing Ubuntu rootfs? Type FRESH to continue: ' response
  [[ "${response}" == FRESH ]] || fail 'Fresh installation cancelled.'
}

for argument in "$@"; do
  case "${argument}" in
    --fresh) fresh=true ;;
    --yes) assume_yes=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "${argument}" >&2; usage >&2; exit 2 ;;
  esac
done

require_termux_user
acquire_lock

printf '[INFO] Updating Termux package metadata.\n'
pkg update -y
pkg upgrade -y
pkg install -y proot-distro
check_storage

if ubuntu_installed; then
  if proot-distro login ubuntu -- true >/dev/null 2>&1; then
    ubuntu_healthy=true
  else
    ubuntu_healthy=false
  fi
else
  ubuntu_healthy=absent
fi

if [[ "${ubuntu_healthy}" == true && "${fresh}" != true ]]; then
  printf '[INFO] Ubuntu already exists; preserving it.\n'
elif [[ "${ubuntu_healthy}" == false && "${fresh}" != true ]]; then
  fail 'Ubuntu exists but cannot start. Inspect it or rerun with --fresh --yes to replace it.'
elif [[ "${ubuntu_healthy}" != absent ]]; then
  confirm_fresh
  printf '[WARN] Removing the existing Ubuntu rootfs because --fresh was supplied.\n'
  proot-distro remove ubuntu
  proot-distro install ubuntu
else
  printf '[INFO] Installing Ubuntu through proot-distro.\n'
  proot-distro install ubuntu
fi

printf '%s\n' '[INFO] Bootstrap complete. Run scripts/02-setup-ubuntu-base.sh from the repository inside Ubuntu PRoot.'
