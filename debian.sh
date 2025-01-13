#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/<ВАШ_GITHUB_USER>/<ВАШ_РЕПОЗИТОРИЙ>/main/build.func)

# Настройки на приложението
APP="Debian"
var_tags="os"
var_cpu="2"
var_ram="8192"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"

# Заглавна информация и базови настройки
header_info "$APP"
base_settings

# Инициализация на основни функции
variables
color
catch_errors

# Проверка на околната среда
pve_check
shell_check
root_check
arch_check

# Основна логика
build_container
description

# Финално съобщение
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
