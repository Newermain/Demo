#!/bin/bash

# =============================================
# МОДУЛЬ 2 - ПОЛНАЯ НАСТРОЙКА ALT LINUX
# Специальность: Сетевое и системное администрирование
# Устройства: ISP, HQ-SRV, BR-SRV, HQ-CLI
# Задания: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.9, 2.10, 2.11
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ошибка: Запусти с sudo или от root!${NC}"
    echo "Пример: sudo ./2module"
    exit 1
fi

# Глобальные переменные
INTERFACE=""
CURRENT_DEVICE=$(hostname)

# Функция определения текущего устройства
detect_device() {
    if [[ "$CURRENT_DEVICE" == "hq-srv.au-team.irpo" ]] || [[ "$CURRENT_DEVICE" == "hq-srv" ]]; then
        CURRENT_DEVICE_TYPE="HQ-SRV"
    elif [[ "$CURRENT_DEVICE" == "br-srv.au-team.irpo" ]] || [[ "$CURRENT_DEVICE" == "br-srv" ]]; then
        CURRENT_DEVICE_TYPE="BR-SRV"
    elif [[ "$CURRENT_DEVICE" == "hq-cli.au-team.irpo" ]] || [[ "$CURRENT_DEVICE" == "hq-cli" ]]; then
        CURRENT_DEVICE_TYPE="HQ-CLI"
    elif [[ "$CURRENT_DEVICE" == "isp" ]]; then
        CURRENT_DEVICE_TYPE="ISP"
    else
        CURRENT_DEVICE_TYPE="UNKNOWN"
    fi
}

# Функция выбора интерфейса
select_interface() {
    echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    echo ""
    read -p "Введи имя интерфейса (например, eth0, ens19): " INTERFACE
    if [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
        echo -e "${RED}Ошибка: Интерфейс $INTERFACE не найден!${NC}"
        return 1
    fi
    return 0
}

# ==================== ЗАДАНИЕ 2.1 ====================
setup_samba_dc() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.1 - Samba Domain Controller${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        echo -e "${YELLOW}Текущее устройство: $CURRENT_DEVICE${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # 1. Установка Samba DC
    echo -e "${BLUE}[1/9] Установка Samba DC...${NC}"
    apt-get update
    apt-get install -y task-samba-dc
    echo -e "${GREEN}✓ Samba DC установлен${NC}"
    
    # 2. Остановка конфликтующих служб
    echo -e "${BLUE}[2/9] Остановка конфликтующих служб...${NC}"
    for service in smb nmb krb5kdc slapd bind; do
        systemctl disable $service --now 2>/dev/null
    done
    echo -e "${GREEN}✓ Конфликтующие службы остановлены${NC}"
    
    # 3. Очистка старых конфигураций
    echo -e "${BLUE}[3/9] Очистка старых конфигураций...${NC}"
    rm -f /etc/samba/smb.conf
    rm -rf /var/lib/samba
    rm -rf /var/cache/samba
    mkdir -p /var/lib/samba/sysvol
    echo -e "${GREEN}✓ Очистка выполнена${NC}"
    
    # 4. Интерактивное развертывание
    echo -e "${BLUE}[4/9] Развертывание домена au-team.irpo...${NC}"
    echo -e "${YELLOW}Сейчас запустится интерактивный мастер настройки${NC}"
    echo -e "  - Realm: AU-TEAM.IRPO"
    echo -e "  - Domain: au-team.irpo"
    echo -e "  - DNS forwarder: 77.88.8.7"
    echo -e "  - Administrator password: P@ssw0rd123"
    echo ""
    read -p "Нажми Enter для запуска мастера..."
    samba-tool domain provision --use-rfc2307 --interactive
    
    # 5. Настройка resolv.conf
    echo -e "${BLUE}[5/9] Настройка DNS резолвера...${NC}"
    select_interface || return 1
    cat > /etc/net/ifaces/$INTERFACE/resolv.conf <<EOF
search au-team.irpo
nameserver 127.0.0.1
EOF
    systemctl restart network
    echo -e "${GREEN}✓ DNS резолвер настроен${NC}"
    
    # 6. Настройка Kerberos
    echo -e "${BLUE}[6/9] Настройка Kerberos...${NC}"
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    echo -e "${GREEN}✓ Kerberos настроен${NC}"
    
    # 7. Запуск Samba
    echo -e "${BLUE}[7/9] Запуск Samba...${NC}"
    systemctl enable --now samba
    systemctl restart samba
    echo -e "${GREEN}✓ Samba запущена${NC}"
    
    # 8. Создание группы и пользователей
    echo -e "${BLUE}[8/9] Создание группы hq и пользователей...${NC}"
    samba-tool group add hq 2>/dev/null
    for i in {1..5}; do
        samba-tool user add hquser$i P@ssw0rd 2>/dev/null
        samba-tool user setexpiry hquser$i --noexpiry 2>/dev/null
        samba-tool group addmembers "hq" hquser$i 2>/dev/null
    done
    echo -e "${GREEN}✓ Созданы пользователи hquser1-hquser5${NC}"
    
    # 9. Проверка
    echo -e "${BLUE}[9/9] Проверка...${NC}"
    echo -e "${GREEN}✓ Samba DC настроен!${NC}"
    echo -e "IP адрес BR-SRV: $(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)"
    
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.2 ====================
setup_raid0() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.2 - Настройка RAID 0${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    echo -e "${YELLOW}Доступные диски:${NC}"
    lsblk | grep -E "NAME|sd|vd|hd"
    echo ""
    read -p "Введи первый диск (например, sdb): " DISK1
    read -p "Введи второй диск (например, sdc): " DISK2
    
    echo -e "${RED}Все данные на /dev/$DISK1 и /dev/$DISK2 будут уничтожены!${NC}"
    read -p "Продолжить? (y/n): " confirm
    [[ $confirm != "y" ]] && return 1
    
    # Установка mdadm
    apt-get update
    apt-get install -y mdadm
    
    # Очистка и создание RAID
    mdadm --zero-superblock --force /dev/$DISK1 /dev/$DISK2 2>/dev/null
    wipefs -a /dev/$DISK1 /dev/$DISK2 2>/dev/null
    mdadm --create --verbose /dev/md0 -l 0 -n 2 /dev/$DISK1 /dev/$DISK2
    
    # Сохранение конфигурации
    mkdir -p /etc/mdadm
    mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf
    
    # Создание ФС и монтирование
    mkfs.ext4 -F /dev/md0
    mkdir -p /raid
    echo "/dev/md0 /raid ext4 defaults 0 0" >> /etc/fstab
    mount -av
    
    echo -e "${GREEN}✓ RAID 0 настроен и смонтирован в /raid${NC}"
    df -h /raid
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.3 ====================
setup_nfs_server() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.3 - NFS сервер на HQ-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Проверка RAID
    if [[ ! -d "/raid" ]]; then
        echo -e "${RED}RAID массив /raid не найден! Сначала выполни задание 2.2${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка NFS
    apt-get install -y nfs-server nfs-utils
    mkdir -p /raid/nfs
    chmod 777 /raid/nfs
    
    # Настройка exports
    echo "/raid/nfs 192.168.200.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -arv
    
    # Запуск
    systemctl enable --now nfs-server
    
    echo -e "${GREEN}✓ NFS сервер настроен${NC}"
    echo -e "Общий ресурс: /raid/nfs для сети 192.168.200.0/24"
    read -p "Нажми Enter для продолжения..."
}

setup_nfs_client() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.3 - NFS клиент на HQ-CLI${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    NFS_SERVER="192.168.100.2"
    
    # Установка клиента
    apt-get install -y nfs-utils nfs-clients
    
    # Монтирование
    mkdir -p /mnt/nfs
    mount -t nfs $NFS_SERVER:/raid/nfs /mnt/nfs
    echo "$NFS_SERVER:/raid/nfs /mnt/nfs nfs defaults 0 0" >> /etc/fstab
    
    echo -e "${GREEN}✓ NFS клиент настроен, смонтирован в /mnt/nfs${NC}"
    df -h | grep nfs
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.4 ====================
setup_ntp_server() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.4 - NTP сервер на ISP${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "ISP" ]]; then
        echo -e "${RED}Этот скрипт предназначен для ISP!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка chrony
    apt-get install -y chrony
    
    # Настройка
    cat > /etc/chrony/chrony.conf <<EOF
server ntp.mobik.ru iburst
server ntp.msk.ru iburst
local stratum 5
allow 172.16.1.0/28
allow 172.16.2.0/28
allow 192.168.100.0/27
allow 192.168.200.0/24
allow 192.168.0.0/28
deny all
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF
    
    systemctl enable --now chronyd
    systemctl restart chronyd
    
    echo -e "${GREEN}✓ NTP сервер настроен (стратум 5)${NC}"
    chronyc tracking
    read -p "Нажми Enter для продолжения..."
}

setup_ntp_client() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.4 - NTP клиент${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}Выбери NTP сервер:${NC}"
    echo "1) 172.16.1.1 (через HQ-RTR)"
    echo "2) 172.16.2.1 (через BR-RTR)"
    read -p "Выбери (1-2): " ntp_choice
    
    case $ntp_choice in
        1) NTP_SERVER="172.16.1.1" ;;
        2) NTP_SERVER="172.16.2.1" ;;
        *) NTP_SERVER="172.16.1.1" ;;
    esac
    
    apt-get install -y chrony
    cat > /etc/chrony/chrony.conf <<EOF
server $NTP_SERVER iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF
    
    systemctl enable --now chronyd
    systemctl restart chronyd
    
    echo -e "${GREEN}✓ NTP клиент настроен на сервер $NTP_SERVER${NC}"
    chronyc sources -v
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.5 ====================
setup_ansible() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.5 - Ansible на BR-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка Ansible
    apt-get update
    apt-get install -y ansible sshpass python3-module-pip
    
    # Установка коллекций
    ansible-galaxy collection install ansible.netcommon
    ansible-galaxy collection install cisco.ios
    pip3 install ansible-pylibssh
    
    # Создание инвентаря
    mkdir -p /etc/ansible
    cat > /etc/ansible/hosts <<EOF
[all:vars]
ansible_user=sshuser
ansible_password=P@ssw0rd

[alt_servers]
hq-srv ansible_host=192.168.100.2
hq-cli ansible_host=192.168.200.2

[ecorouters]
hq-rtr ansible_host=172.16.1.2 ansible_user=net_admin
br-rtr ansible_host=172.16.2.2 ansible_user=net_admin

[all_hosts:children]
alt_servers
ecorouters

[ecorouters:vars]
ansible_connection=network_cli
ansible_network_os=cisco.ios

[alt_servers:vars]
ansible_connection=ssh
ansible_python_interpreter=/usr/bin/python3
EOF
    
    # Настройка ansible.cfg
    cat > /etc/ansible/ansible.cfg <<EOF
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
timeout = 30
forks = 10

[ssh_connection]
pipelining = True
EOF
    
    echo -e "${GREEN}✓ Ansible настроен${NC}"
    echo -e "${YELLOW}Проверка подключения:${NC}"
    ansible all -m ping --one-line 2>&1 | head -4
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.6 ====================
setup_docker_testapp() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.6 - Docker testapp на BR-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка Docker
    apt-get install -y docker-engine docker-compose-v2
    systemctl enable --now docker
    
    # Поиск Additional.iso
    mkdir -p /mnt
    mount /dev/sr0 /mnt 2>/dev/null
    DOCKER_PATH="/mnt/docker"
    
    if [[ ! -d "$DOCKER_PATH" ]]; then
        echo -e "${YELLOW}Диск с Additional.iso не найден${NC}"
        read -p "Укажи путь к образам docker: " DOCKER_PATH
    fi
    
    # Импорт образов
    docker load < $DOCKER_PATH/site_latest.tar
    docker load < $DOCKER_PATH/mariadb_latest.tar
    
    # Создание docker-compose.yaml
    mkdir -p /opt/testapp
    cd /opt/testapp
    cat > docker-compose.yaml <<EOF
version: '3.8'

services:
  db:
    image: mariadb_latest:latest
    container_name: db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: P@ssw0rd
      MYSQL_DATABASE: testdb
      MYSQL_USER: test
      MYSQL_PASSWORD: P@ssw0rd
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - testapp_network

  testapp:
    image: site_latest:latest
    container_name: testapp
    restart: always
    ports:
      - "8080:80"
    environment:
      DB_HOST: db
      DB_NAME: testdb
      DB_USER: test
      DB_PASSWORD: P@ssw0rd
    depends_on:
      - db
    networks:
      - testapp_network

volumes:
  db_data:

networks:
  testapp_network:
    driver: bridge
EOF
    
    docker compose up -d
    
    echo -e "${GREEN}✓ Docker контейнеры запущены${NC}"
    docker ps
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.7 ====================
setup_lamp_app() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.7 - LAMP веб-приложение на HQ-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка LAMP
    apt-get install -y lamp-server
    systemctl enable --now mariadb
    systemctl enable --now httpd2
    
    # Поиск Additional.iso
    mkdir -p /mnt
    mount /dev/sr0 /mnt 2>/dev/null
    WEB_PATH="/mnt/web"
    
    if [[ ! -d "$WEB_PATH" ]]; then
        echo -e "${YELLOW}Диск с Additional.iso не найден${NC}"
        read -p "Укажи путь к файлам web: " WEB_PATH
    fi
    
    # Копирование файлов
    cp $WEB_PATH/index.php /var/www/html/
    cp $WEB_PATH/logo.png /var/www/html/ 2>/dev/null
    
    # Настройка БД
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS webdb;
DROP USER IF EXISTS 'webc'@'localhost';
CREATE USER 'webc'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    
    # Импорт дампа
    mariadb -u webc -pP@ssw0rd -D webdb < $WEB_PATH/dump.sql 2>/dev/null
    
    # Настройка index.php
    sed -i "s/'dbname' => '[^']*'/'dbname' => 'webdb'/g" /var/www/html/index.php
    sed -i "s/'user' => '[^']*'/'user' => 'webc'/g" /var/www/html/index.php
    sed -i "s/'password' => '[^']*'/'password' => 'P@ssw0rd'/g" /var/www/html/index.php
    
    echo -e "${GREEN}✓ LAMP веб-приложение настроено${NC}"
    echo -e "URL: http://$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)/"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.9 ====================
setup_reverse_proxy() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.9 - Nginx reverse proxy на ISP${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "ISP" ]]; then
        echo -e "${RED}Этот скрипт предназначен для ISP!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка Nginx
    apt-get install -y nginx
    
    # Настройка reverse proxy
    cat > /etc/nginx/sites-available.d/default.conf <<EOF
server {
    listen 80;
    server_name web.au-team.irpo;
    location / {
        proxy_pass http://192.168.100.2:80;
        proxy_set_header Host \$host;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;
    location / {
        proxy_pass http://192.168.0.2:8080;
        proxy_set_header Host \$host;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/
    systemctl enable --now nginx
    systemctl restart nginx
    
    echo -e "${GREEN}✓ Nginx reverse proxy настроен${NC}"
    echo -e "  web.au-team.irpo -> 192.168.100.2:80"
    echo -e "  docker.au-team.irpo -> 192.168.0.2:8080"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.10 ====================
setup_nginx_auth() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.10 - Web-based аутентификация${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "ISP" ]]; then
        echo -e "${RED}Этот скрипт предназначен для ISP!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # Установка htpasswd
    apt-get install -y apache2-htpasswd
    
    # Создание файла паролей
    mkdir -p /etc/nginx
    htpasswd -cb /etc/nginx/.htpasswd WEB P@ssw0rd
    
    # Обновление конфигурации
    cat > /etc/nginx/sites-available.d/default.conf <<EOF
server {
    listen 80;
    server_name web.au-team.irpo;
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    location / {
        proxy_pass http://192.168.100.2:80;
        proxy_set_header Host \$host;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;
    location / {
        proxy_pass http://192.168.0.2:8080;
        proxy_set_header Host \$host;
    }
}
EOF
    
    nginx -t && systemctl restart nginx
    
    echo -e "${GREEN}✓ Web-based аутентификация настроена${NC}"
    echo -e "Логин: WEB, пароль: P@ssw0rd"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2.11 ====================
setup_yandex_browser() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2.11 - Яндекс Браузер на HQ-CLI${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    apt-get update
    apt-get install -y yandex-browser-stable
    
    if command -v yandex-browser &>/dev/null; then
        echo -e "${GREEN}✓ Яндекс Браузер установлен${NC}"
        yandex-browser --version
    else
        echo -e "${RED}✗ Ошибка установки${NC}"
    fi
    
    read -p "Нажми Enter для продолжения..."
}

# ==================== DNS НАСТРОЙКА ДЛЯ HQ-CLI ====================
setup_dns_for_hq_cli() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Настройка DNS для доменов на HQ-CLI${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    ISP_IP="172.16.1.1"
    
    echo -e "${YELLOW}Какой IP у ISP (reverse proxy)?${NC}"
    echo "1) 172.16.1.1"
    echo "2) 172.16.2.1"
    read -p "Выбери (1-2): " ip_choice
    
    case $ip_choice in
        1) ISP_IP="172.16.1.1" ;;
        2) ISP_IP="172.16.2.1" ;;
    esac
    
    # Добавление записей в /etc/hosts
    cp /etc/hosts /etc/hosts.backup
    sed -i "/web.au-team.irpo/d" /etc/hosts
    sed -i "/docker.au-team.irpo/d" /etc/hosts
    cat >> /etc/hosts <<EOF
$ISP_IP    web.au-team.irpo
$ISP_IP    docker.au-team.irpo
EOF
    
    echo -e "${GREEN}✓ DNS записи добавлены в /etc/hosts${NC}"
    echo -e "${YELLOW}Проверка:${NC}"
    ping -c 1 web.au-team.irpo
    read -p "Нажми Enter для продолжения..."
}

# ==================== ВВОД В ДОМЕН HQ-CLI ====================
join_domain() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Ввод HQ-CLI в домен au-team.irpo${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    BR_SRV_IP="192.168.0.2"
    
    # Настройка DNS
    select_interface || return 1
    cat > /etc/net/ifaces/$INTERFACE/resolv.conf <<EOF
search au-team.irpo
nameserver $BR_SRV_IP
EOF
    systemctl restart network
    
    # Установка пакета
    apt-get install -y task-auth-ad-sssd
    
    # Ввод в домен
    echo -e "${YELLOW}Ввод в домен...${NC}"
    realm join --verbose au-team.irpo --user=administrator
    
    # Настройка sudo для группы hq
    apt-get install -y libnss-role
    roleadd hq wheel
    echo "%hq ALL=(ALL) NOPASSWD: /bin/cat, /bin/grep, /usr/bin/id" >> /etc/sudoers
    
    echo -e "${GREEN}✓ HQ-CLI введен в домен${NC}"
    realm list
    read -p "Нажми Enter для продолжения..."
}

# ==================== ГЛАВНОЕ МЕНЮ ====================
show_main_menu() {
    clear
    detect_device
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 МОДУЛЬ 2 - ALT LINUX НАСТРОЙКА                ║${NC}"
    echo -e "${CYAN}║           Сетевое и системное администрирование              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Текущее устройство:${NC} $CURRENT_DEVICE ($CURRENT_DEVICE_TYPE)"
    echo ""
    echo -e "${GREEN}┌────────────── ЗАДАНИЯ МОДУЛЯ 2 ──────────────┐${NC}"
    echo -e "${GREEN}│  1) Задание 2.1  - Samba DC (BR-SRV)         │${NC}"
    echo -e "${GREEN}│  2) Задание 2.2  - RAID 0 (HQ-SRV)           │${NC}"
    echo -e "${GREEN}│  3) Задание 2.3  - NFS сервер (HQ-SRV)       │${NC}"
    echo -e "${GREEN}│  4) Задание 2.3  - NFS клиент (HQ-CLI)       │${NC}"
    echo -e "${GREEN}│  5) Задание 2.4  - NTP сервер (ISP)          │${NC}"
    echo -e "${GREEN}│  6) Задание 2.4  - NTP клиент               │${NC}"
    echo -e "${GREEN}│  7) Задание 2.5  - Ansible (BR-SRV)          │${NC}"
    echo -e "${GREEN}│  8) Задание 2.6  - Docker testapp (BR-SRV)   │${NC}"
    echo -e "${GREEN}│  9) Задание 2.7  - LAMP приложение (HQ-SRV)  │${NC}"
    echo -e "${GREEN}│ 10) Задание 2.9  - Reverse proxy (ISP)       │${NC}"
    echo -e "${GREEN}│ 11) Задание 2.10 - Web аутентификация (ISP)  │${NC}"
    echo -e "${GREEN}│ 12) Задание 2.11 - Яндекс Браузер (HQ-CLI)   │${NC}"
    echo -e "${GREEN}│ 13) Доп. настройка DNS для HQ-CLI            │${NC}"
    echo -e "${GREEN}│ 14) Ввод HQ-CLI в домен                      │${NC}"
    echo -e "${GREEN}│ 15) Выход                                    │${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Совет: Запускай скрипт на нужном устройстве:${NC}"
    echo -e "  - BR-SRV:  пункты 1, 7, 8"
    echo -e "  - HQ-SRV:  пункты 2, 3, 9"
    echo -e "  - HQ-CLI:  пункты 4, 6, 12, 13, 14"
    echo -e "  - ISP:     пункты 5, 6, 10, 11"
    echo ""
    read -p "Выбери пункт меню (1-15): " choice
}

# ==================== ОСНОВНОЙ ЦИКЛ ====================
while true; do
    show_main_menu
    case $choice in
        1) setup_samba_dc ;;
        2) setup_raid0 ;;
        3) setup_nfs_server ;;
        4) setup_nfs_client ;;
        5) setup_ntp_server ;;
        6) setup_ntp_client ;;
        7) setup_ansible ;;
        8) setup_docker_testapp ;;
        9) setup_lamp_app ;;
        10) setup_reverse_proxy ;;
        11) setup_nginx_auth ;;
        12) setup_yandex_browser ;;
        13) setup_dns_for_hq_cli ;;
        14) join_domain ;;
        15) echo -e "${GREEN}Выход...${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
    esac
done