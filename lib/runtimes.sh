#!/usr/bin/env bash

set -euo pipefail

runtime_log() { printf '[RUNTIME] %s\n' "$*"; }

install_uv_python() {
  local installer uv_bin
  uv_bin="${HOME}/.local/bin/uv"
  if [[ ! -x "${uv_bin}" ]]; then
    installer="$(mktemp)"
    curl --fail --location --silent --show-error https://astral.sh/uv/install.sh --output "${installer}"
    UV_NO_MODIFY_PATH=1 sh "${installer}"
    rm -f "${installer}"
  else
    "${uv_bin}" self update
  fi
  "${uv_bin}" python upgrade || "${uv_bin}" python install --default
  runtime_log "uv and the latest stable managed Python are ready."
}

install_node_lts() {
  local installer
  installer="$(mktemp)"
  curl --fail --location --silent --show-error https://deb.nodesource.com/setup_lts.x --output "${installer}"
  bash "${installer}"
  rm -f "${installer}"
  apt-get install --yes nodejs
  runtime_log "Node LTS is ready: $(node --version)."
}

install_go_stable() {
  local api arch base checksum download filename release temporary
  case "$(dpkg --print-architecture)" in
    arm64|amd64) arch="$(dpkg --print-architecture)" ;;
    *) log_error "Go stable installer supports arm64 and amd64 only."; return 1 ;;
  esac
  api="$(mktemp)"
  curl --fail --location --silent --show-error 'https://go.dev/dl/?mode=json' --output "${api}"
  release="$(jq -r 'map(select(.stable == true))[0].version' "${api}")"
  filename="$(jq -r --arg arch "${arch}" 'map(select(.stable == true))[0].files[] | select(.os == "linux" and .arch == $arch and .kind == "archive") | .filename' "${api}")"
  checksum="$(jq -r --arg arch "${arch}" 'map(select(.stable == true))[0].files[] | select(.os == "linux" and .arch == $arch and .kind == "archive") | .sha256' "${api}")"
  rm -f "${api}"
  [[ -n "${filename}" && "${filename}" != null && -n "${checksum}" && "${checksum}" != null ]]
  base='/opt/termux-ubuntu-bootstrap/go'
  if [[ ! -d "${base}/${release}" ]]; then
    temporary="$(mktemp -d)"
    download="${temporary}/${filename}"
    curl --fail --location --silent --show-error "https://go.dev/dl/${filename}" --output "${download}"
    printf '%s  %s\n' "${checksum}" "${download}" | sha256sum --check --status
    tar --extract --gzip --file "${download}" --directory "${temporary}"
    mkdir -p "${base}"
    mv "${temporary}/go" "${base}/${release}"
    rm -rf "${temporary}"
  fi
  ln -sfn "${base}/${release}" "${base}/current"
  cat > /etc/profile.d/termux-ubuntu-bootstrap-go.sh <<'EOF'
export PATH=/opt/termux-ubuntu-bootstrap/go/current/bin:$PATH
EOF
  export PATH="${base}/current/bin:${PATH}"
  runtime_log "Go stable is ready: $(go version)."
}

install_stable_development_runtimes() {
  install_uv_python
  install_node_lts
  install_go_stable
}
