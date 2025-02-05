#!/bin/bash

# Цветове
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Проверка за root потребител
if [[ <span class="math-inline">EUID \-ne 0 \]\]; then
SUDO\='sudo'
echo \-e "</span>{YELLOW}Изпълнява се като потребител, който не е root. Използва се sudo за привилегировани команди.<span class="math-inline">\{NC\}"
else
SUDO\=''
echo \-e "</span>{GREEN}Изпълнява се като root потребител.<span class="math-inline">\{NC\}"
fi
\# Проверка за whiptail
if \! command \-v whiptail &\> /dev/null; then
echo \-e "</span>{RED}Грешка: 'whiptail' не е инсталиран. Инсталиране сега...${NC}"
    $SUDO apt update && $SUDO apt install -y whiptail
    if [[ <span class="math-inline">? \-ne 0 \]\]; then
echo \-e "</span>{RED}Неуспешно инсталиране на 'whiptail'. Изход.${NC}"
        exit 1
    fi
fi

# Функция за инсталиране на libguestfs-tools с прогрес бар
install_libguestfs_tools() {
    {
        echo 10
        $SUDO apt update -y > /dev/null 2>&1
        echo 50
        <span class="math-inline">SUDO apt install \-y libguestfs\-tools \> /dev/null 2\>&1
echo 100
\} \| whiptail \-\-gauge "Инсталиране на 'libguestfs\-tools'\.\.\." 6 50 0
\}
\# Въвеждане на публичен ключ
PUB\_KEY\=</span>(whiptail --title "SSH Публичен Ключ" --inputbox "Моля, поставете вашия SSH публичен ключ:" 10 60 3>&1 1>&2 2>&3)

if [[ -z "<span class="math-inline">PUB\_KEY" \]\]; then
echo \-e "</span>{RED}Грешка: Не е предоставен публичен ключ. Изход.<span class="math-inline">\{NC\}"
exit 1
fi
\# Обработка на LXC контейнери
LXC\_IDS\=\(</span>($SUDO pct list | awk 'NR>1 {print $1}'))
if [[ <span class="math-inline">\{\#LXC\_IDS\[@\]\} \-gt 0 \]\]; then
LXC\_CHOICES\=</span>(whiptail --title "Избор на LXC контейнери" --checklist \
  "Изберете контейнерите за обработка (SPACE за избор, ENTER за потвърждение):" 15 60 2 \
  "all" "Всички LXC контейнери" OFF \
  ${LXC_IDS[@]/#/\"} OFF 3>&1 1>&2 2>&3)

  if [[ <span class="math-inline">? \-ne 0 \]\]; then
echo \-e "</span>{RED}Не е направен избор. Изход.${NC}"
    exit 1
  fi

  if [[ "<span class="math-inline">LXC\_CHOICES" \=\= \*"all"\* \]\]; then
for ID in "</span>{LXC_IDS[@]}"; do
      echo -e "${YELLOW}Добавяне на ключ към LXC контейнер <span class="math-inline">ID\.\.\.</span>{NC}"
      $SUDO pct exec $ID -- mkdir -p /root/.ssh
      $SUDO pct exec $ID -- bash -c "echo \"<span class="math-inline">PUB\_KEY\\" \>\> /root/\.ssh/authorized\_keys"
echo \-e "</span>{GREEN}Ключът е добавен към LXC контейнер <span class="math-inline">ID\.</span>{NC}"
    done
  else
    for ID in "${LXC_IDS[@]}"; do
      if [[ " $LXC_CHOICES " == *" <span class="math-inline">ID "\* \]\]; then \# Check if ID is in the choices
echo \-e "</span>{YELLOW}Добавяне на ключ към LXC контейнер <span class="math-inline">ID\.\.\.</span>{NC}"
        $SUDO pct exec $ID -- mkdir -p /root/.ssh
        $SUDO pct exec $ID -- bash -c "echo \"<span class="math-inline">PUB\_KEY\\" \>\> /root/\.ssh/authorized\_keys"
echo \-e "</span>{GREEN}Ключът е добавен към LXC контейнер <span class="math-inline">ID\.</span>{NC}"
      fi
    done
  fi
else
  echo -e "<span class="math-inline">\{YELLOW\}Не са намерени LXC контейнери\.</span>{NC}"
fi


# Обработка на виртуални машини
VM_IDS=($($SUDO qm list | awk 'NR>1 {print $1}'))
if [[ ${#VM_IDS[@]} -gt 0 ]]; then

 if whiptail --title "Инсталиране на libguestfs-tools" --yesno \
"Желаете ли да инсталирате 'libguestfs-tools'? Необходимо е за правилна обработка на виртуални машини." 10 60; then
        install_libguestfs_tools
        if [[ <span class="math-inline">? \-ne 0 \]\]; then
echo \-e "</span>{RED}Неуспешно инсталиране на 'libguestfs-tools'. Обработката на виртуални машини може да има проблеми.<span class="math-inline">\{NC\}"
else
echo \-e "</span>{GREEN}'libguestfs-tools' е инсталиран успешно.<span class="math-inline">\{NC\}"
fi
else
echo \-e "</span>{YELLOW}Пропуска се инсталирането на 'libguestfs-tools'.<span class="math-inline">\{NC\}"
echo \-e "</span>{RED}Обработката на виртуални машини ще продължи, но пълната функционалност може да не е налична.<span class="math-inline">\{NC\}"
fi
VM\_CHOICES\=</span>(whiptail --title "Избор на виртуални машини" --checklist \
  "Изберете виртуалните машини за обработка (SPACE за избор, ENTER за потвърждение):" 15 60 2 \
  "all" "Всички виртуални машини" OFF \
  ${VM_IDS[@]/#/\"} OFF 3>&1 1>&2 2>&3)

  if [[ <span class="math-inline">? \-ne 0 \]\]; then
echo \-e "</span>{RED}Не е направен избор. Изход.${NC}"
    exit 1
  fi

  if [[ "<span class="math-inline">VM\_CHOICES" \=\= \*"all"\* \]\]; then
for ID in "</span>{VM_IDS[@]}"; do
        # ... (останалата част от кода за обработка на VM, както преди, но вече в цикъл)
        echo -e "${YELLOW}Добавяне на ключ към VM <span class="math-inline">ID\.\.\.</span>{NC}"
            DISK_PATH=$($SUDO qm config $ID | grep '^scsi\|^virtio\|^ide' | head -1 | awk -F ':' '{print $2}' | awk '{print $1}')
            MOUNT_DIR="/mnt/vm-$ID"
            if [[ -n "$DISK_PATH" ]]; then
                mkdir -p $MOUNT_DIR
                $SUDO guestmount -a "/var/lib/vz/images/$ID/$DISK_PATH" -i --ro $MOUNT_DIR 2>/dev/null
                if [[ <span class="math-inline">? \-ne 0 \]\]; then
echo \-e "</span>{RED}Неуспешно монтиране на VM <span class="math-inline">ID\. Пропуска се\.</span>{NC}"
                else
                    if [[ -d "$MOUNT_DIR/root/.ssh" ]]; then
                        echo "$PUB_KEY" | $SUDO tee -a "$MOUNT_DIR/root/.ssh/authorized_keys" > /dev/null
                    else
                        $SUDO mkdir -p "$MOUNT_DIR/root/.ssh"
                        echo "$PUB_KEY" | $SUDO tee "$MOUNT_DIR/root/.ssh/authorized_keys" > /dev/null
                    fi
                    $SUDO guestunmount $MOUNT_DIR
                    rmdir <span class="math-inline">MOUNT\_DIR
echo \-e "</span>{GREEN}Ключът е добавен към VM <span class="math-inline">ID\.</span>{NC}"
                fi
            else
                echo -e "${RED}Не е намерен валиден диск за VM <span class="math-inline">ID\. Пропуска се\.</span>{NC}"
            fi
    done
  else
    for ID in "${VM_IDS[@]}"; do
      if [[ " $VM_CHOICES " == *" <span class="math-inline">ID "\* \]\]; then \# Check if ID is in the choices
\# \.\.\. \(останалата част от кода за обработка на VM, както преди, но вече в цикъл\)
echo \-e "</span>{YELLOW}Добавяне на ключ към VM <span class="math-inline">ID\.\.\.</span>{NC}"
            DISK_PATH=<span class="math-inline">\(</span>
