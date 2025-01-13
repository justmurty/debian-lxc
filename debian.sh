#!/usr/bin/env bash
# Copyright (c) 2021-2025
# Author: your_name
# License: MIT

APP="Debian"
APP_SCRIPT="debian_lxc_install.sh"
GITHUB_REPO="https://raw.githubusercontent.com/justmurty/debian-lxc/refs/heads/main/"

variables() {
  NSAPP=$(echo ${APP,,} | tr -d ' ')
  PVEHOST_NAME=$(hostname)
}

color() {
  YW="\033[33m"
  GN="\033[1;92m"
  RD="\033[01;31m"
  CL="\033[m"
  CM="${GN}✔️${CL}"
  CROSS="${RD}✖️${CL}"
  INFO="${YW}💡${CL}"
}

catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

error_handler() {
  local line_number="$1"
  local command="$2"
  echo -e "${RD}[ERROR]${CL} at line ${RD}$line_number${CL}: while executing command ${YW}$command${CL}"
  exit 1
}

root_check() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${CROSS} Скриптът трябва да се изпълнява с root права!${CL}"
    exit 1
  fi
}

pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
    echo -e "${CROSS} Скриптът изисква Proxmox VE версия 8.1 или по-нова.${CL}"
    exit 1
  fi
}

fetch_install_script() {
  echo -e "${INFO} Изтегляне на скрипт за инсталация от GitHub...${CL}"
  bash -c "$(wget -qLO - ${GITHUB_REPO}/${APP_SCRIPT})"
}

start_install() {
  variables
  color
  root_check
  pve_check
  catch_errors
  fetch_install_script
}

start_install
