#!/usr/bin/env bash
APP="Debian"

# Настройки по подразбиране
CT_ID=$(pvesh get /cluster/nextid)
CT_NAME="debian-lxc-$CT_ID"
DISK_SIZE="8G"
RAM_SIZE="8192"
CPU_CORES="2"
PASSWORD="123123Raw"
DISABLE_IPV6="yes"
ENABLE_SSH="yes"
NET_CONFIG="dhcp"

create_lxc() {
  echo -e "💡 Създаване на LXC контейнер ${APP} с ID ${CT_ID}..."
  pct create "$CT_ID" local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
    -hostname "$CT_NAME" \
    -rootfs local-lvm:"$DISK_SIZE" \
    -memory "$RAM_SIZE" \
    -cores "$CPU_CORES" \
    -net0 name=eth0,bridge=vmbr0,ip="$NET_CONFIG" \
    -password "$PASSWORD" \
    -features nesting=1

  # Изключване на IPv6
  if [[ "$DISABLE_IPV6" == "yes" ]]; then
    echo "lxc.net.0.ipv6.address = none" >> /etc/pve/lxc/"$CT_ID".conf
  fi

  # Активиране на SSH root достъп
  if [[ "$ENABLE_SSH" == "yes" ]]; then
    pct exec "$CT_ID" -- bash -c "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && systemctl restart ssh"
  fi

  echo -e "✔️ Контейнерът ${APP} с ID ${CT_ID} е създаден успешно!"
}

post_install() {
  echo -e "💡 Инсталиране на допълнителни зависимости..."
  pct exec "$CT_ID" -- apt-get update
  pct exec "$CT_ID" -- apt-get install -y curl wget vim
  echo -e "✔️ Зависимостите са инсталирани успешно!"

  echo -e "💡 Настройка на съобщение за контейнера..."
  pct exec "$CT_ID" -- bash -c "echo 'Welcome to $APP' > /etc/motd"
  echo -e "✔️ Контейнерът е настроен успешно!"
}

start() {
  create_lxc
  post_install
}

start
