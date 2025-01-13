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
STORAGE="local-lvm" # Променете, ако желаете да използвате друг сторидж, напр. "local"

# Функция за проверка на наличност на шаблон
check_template() {
  echo -e "💡 Проверка за наличието на шаблон ${APP}..."
  if ! pveam list "$STORAGE" | grep -q "debian-12-standard_12.0-1_amd64.tar.zst"; then
    echo -e "💡 Шаблонът не е наличен. Изтегляне..."
    pveam update
    pveam download "$STORAGE" debian-12-standard_12.0-1_amd64.tar.zst
  fi
  echo -e "✔️ Шаблонът е наличен!"
}

create_lxc() {
  echo -e "💡 Създаване на LXC контейнер ${APP} с ID ${CT_ID}..."
  pct create "$CT_ID" "$STORAGE":vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
    -hostname "$CT_NAME" \
    -rootfs "$STORAGE":"$DISK_SIZE" \
    -memory "$RAM_SIZE" \
    -cores "$CPU_CORES" \
    -net0 name=eth0,bridge=vmbr0,ip="$NET_CONFIG" \
    -password "$PASSWORD" \
    -features nesting=1

  if [ $? -ne 0 ]; then
    echo -e "❌ Грешка при създаването на контейнера!"
    exit 1
  fi

  # Изключване на IPv6
  if [[ "$DISABLE_IPV6" == "yes" ]]; then
    echo "lxc.net.0.ipv6.address = none" >> /etc/pve/lxc/"$CT_ID".conf
  fi

  echo -e "✔️ Контейнерът ${APP} с ID ${CT_ID} е създаден успешно!"
}

post_install() {
  echo -e "💡 Стартиране на контейнера..."
  pct start "$CT_ID"

  echo -e "💡 Инсталиране на допълнителни зависимости..."
  pct exec "$CT_ID" -- bash -c "apt-get update && apt-get install -y curl wget vim"
  echo -e "✔️ Зависимостите са инсталирани успешно!"

  # Активиране на SSH root достъп
  if [[ "$ENABLE_SSH" == "yes" ]]; then
    echo -e "💡 Активиране на SSH root достъп..."
    pct exec "$CT_ID" -- bash -c "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && systemctl restart ssh"
  fi

  echo -e "💡 Настройка на съобщение за контейнера..."
  pct exec "$CT_ID" -- bash -c "echo 'Welcome to $APP' > /etc/motd"
  echo -e "✔️ Контейнерът е настроен успешно!"
}

start() {
  check_template
  create_lxc
  post_install
}

start
