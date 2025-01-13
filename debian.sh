#!/usr/bin/env bash

# Основни функции
color() {
  YW=$(echo "\033[33m")
  GN=$(echo "\033[1;92m")
  RD=$(echo "\033[01;31m")
  CL=$(echo "\033[m")
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
  echo -e "${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: while executing command ${YW}$command${CL}"
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

# Получаване на следващото свободно CT-ID
get_next_ct_id() {
  local next_id
  next_id=$(pvesh get /cluster/nextid)
  echo "$next_id"
}

# Основни настройки
APP="Debian"
CT_ID=$(get_next_ct_id)  # Автоматично задаване на свободното CT-ID
CT_NAME="debian-lxc-$CT_ID"
PASSWORD="123123Raw"
DISABLE_IPV6="yes"
ENABLE_SSH="yes"
NET_CONFIG="dhcp"
DISK_SIZE="8G"
RAM_SIZE="8192"
CPU_CORES="2"

# Инсталация на LXC контейнер
install_lxc() {
  echo -e "${INFO} Създаване на LXC контейнер: ${APP} с ID ${CT_ID}${CL}"
  pct create "$CT_ID" local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
    -hostname "$CT_NAME" \
    -rootfs local-lvm:"$DISK_SIZE" \
    -memory "$RAM_SIZE" \
    -cores "$CPU_CORES" \
    -net0 name=eth0,bridge=vmbr0,ip="$NET_CONFIG" \
    -password "$PASSWORD" \
    -features nesting=1

  # Изключване на IPv6, ако е зададено
  if [[ "$DISABLE_IPV6" == "yes" ]]; then
    echo "lxc.net.0.ipv6.address = none" >>/etc/pve/lxc/"$CT_ID".conf
  fi

  # Активиране на SSH root достъп
  if [[ "$ENABLE_SSH" == "yes" ]]; then
    pct exec "$CT_ID" -- bash -c "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && systemctl restart ssh"
  fi

  echo -e "${CM} Контейнерът ${APP} с ID ${CT_ID} беше създаден успешно!${CL}"
}

# Инсталиране на зависимости и приложения
post_install() {
  echo -e "${INFO} Инсталиране на зависимости в контейнера $APP...${CL}"
  pct exec "$CT_ID" -- apt-get update
  pct exec "$CT_ID" -- apt-get install -y curl wget vim
  echo -e "${CM} Зависимостите са инсталирани успешно!${CL}"

  echo -e "${INFO} Настройка на специфично приложение...${CL}"
  pct exec "$CT_ID" -- bash -c "echo 'Welcome to $APP' > /etc/motd"
  echo -e "${CM} Приложението е настроено успешно!${CL}"
}

# Проверки и стартиране на инсталацията
root_check
pve_check
catch_errors
install_lxc
post_install
