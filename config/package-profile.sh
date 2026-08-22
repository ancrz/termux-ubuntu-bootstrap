#!/usr/bin/env bash
# Shared package manifest for Ubuntu PRoot. Do not install packages here.

PROFILE_BASE=(
  bash-completion ca-certificates curl file less nano psmisc tar tree unzip
  wget zip
)

PROFILE_DEVELOPMENT=(
  autoconf automake build-essential ccache cmake gdb git libtool make
  ninja-build pkg-config python3 python3-pip python3-venv
)

PROFILE_NETWORK=(
  dnsutils iproute2 iputils-ping lsof mtr-tiny net-tools netcat-openbsd
  openssh-client rsync socat traceroute whois
)

PROFILE_ANALYSIS=(
  htop jq ncdu nmap procps ripgrep strace sysstat
)

# Tools that make repository inspection and agent-assisted iteration repeatable.
PROFILE_AI_WORKFLOW=(
  fd-find fzf shellcheck shfmt tmux
)

profile_packages() {
  printf '%s\n' \
    "${PROFILE_BASE[@]}" \
    "${PROFILE_DEVELOPMENT[@]}" \
    "${PROFILE_NETWORK[@]}" \
    "${PROFILE_ANALYSIS[@]}" \
    "${PROFILE_AI_WORKFLOW[@]}"
}
