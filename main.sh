#!/bin/bash

# =============================================
# УНИВЕРСАЛЬНЫЙ СКРИПТ НАСТРОЙКИ ALT LINUX
# Специальность: Сетевое и системное администрирование
# Модули: 1, 2, 3
# Все параметры запрашиваются интерактивно!
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
    echo "Пример: sudo ./main_setup.sh"
    exit 1
fi

# Глобальные переменные (будут заполняться интерактивно)
INTERFACE=""
IP_ADDR=""
CIDR=""
GATEWAY=""
DNS_SERVERS=""
DOMAIN=""
HOSTNAME=""
NTP_SERVER=""
ANSIBLE_PASSWORD=""
DB_PASSWORD=""
PRINTER_SERVER=""
CA_DAYS=""

# ==================== ФУНКЦИЯ ЗАПРОСА ПАРАМЕТРОВ ====================
get_common_params() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              ВВЕДИТЕ ОБЩИЕ ПАРАМЕТРЫ СЕТИ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    echo ""
    read -p "Введите имя сетевого интерфейса: " INTERFACE
    
    echo -e "${YELLOW}Введите параметры IP-адресации:${NC}"
    read -p "IP-адрес (например, 192.168.1.10): " IP_ADDR
    read -p "Маска подсети в CIDR (например, 24): " CIDR
    read -p "Шлюз по умолчанию: " GATEWAY
    read -p "DNS-серверы через пробел (например, 8.8.8.8 1.1.1.1): " DNS_SERVERS
    read -p "Доменное имя (например, au-team.irpo): " DOMAIN
    read -p "Имя хоста (FQDN, например, hq-srv.au-team.irpo): " HOSTNAME
    echo ""
}

# ==================== МОДУЛЬ 1 ====================
module1_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                       МОДУЛЬ 1 - СЕТЬ                         ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1) Настройка имени хоста и статического IP"
        echo "2) Настройка DHCP-клиента"
        echo "3) Настройка DNS-резолвера"
        echo "4) Настройка VLAN на интерфейсе"
        echo "5) Настройка безопасного SSH (порт 2026, баннер)"
        echo "6) Настройка DHCP-сервера (только команды для EcoRouter)"
        echo "7) Настройка DNS-сервера BIND"
        echo "8) Настройка часового пояса"
        echo "9) Создание локальных пользователей"
        echo "10) Настройка NAT и IP forwarding"
        echo "11) Вернуться в главное меню"
        echo ""
        read -p "Выберите пункт: " choice
        
        case $choice in
            1) setup_hostname_ip ;;
            2) setup_dhcp_client ;;
            3) setup_resolv_conf ;;
            4) setup_vlan ;;
            5) setup_secure_ssh ;;
            6) setup_dhcp_server_commands ;;
            7) setup_dns_server ;;
            8) setup_timezone ;;
            9) setup_local_users ;;
            10) setup_nat_forwarding ;;
            11) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

setup_hostname_ip() {
    clear
    echo -e "${BLUE}=== Настройка имени хоста и статического IP ===${NC}"
    echo ""
    
    get_common_params
    
    echo -e "${BLUE}[1/3] Настройка имени хоста...${NC}"
    hostnamectl set-hostname "$HOSTNAME"
    echo "HOSTNAME=$HOSTNAME" > /etc/sysconfig/network
    echo -e "${GREEN}✓ Имя хоста: $HOSTNAME${NC}"
    
    echo -e "${BLUE}[2/3] Настройка статического IP...${NC}"
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    echo "$IP_ADDR/$CIDR" > /etc/net/ifaces/$INTERFACE/ipv4address
    echo "default via $GATEWAY" > /etc/net/ifaces/$INTERFACE/ipv4route
    
    echo -e "${BLUE}[3/3] Перезапуск сети...${NC}"
    systemctl restart network
    
    echo -e "${GREEN}✓ Настройка завершена!${NC}"
    ip a show $INTERFACE | grep inet
    read -p "Нажми Enter..."
}

setup_dhcp_client() {
    clear
    echo -e "${BLUE}=== Настройка DHCP-клиента ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    read -p "Введите имя интерфейса для DHCP: " INTERFACE
    
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/options <<EOF
TYPE=eth
BOOTPROTO=dhcp
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    rm -f /etc/net/ifaces/$INTERFACE/ipv4address 2>/dev/null
    rm -f /etc/net/ifaces/$INTERFACE/ipv4route 2>/dev/null
    
    systemctl restart network
    echo -e "${GREEN}✓ Интерфейс $INTERFACE настроен на DHCP${NC}"
    ip a show $INTERFACE | grep inet
    read -p "Нажми Enter..."
}

setup_resolv_conf() {
    clear
    echo -e "${BLUE}=== Настройка DNS-резолвера ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    read -p "Введите имя интерфейса: " INTERFACE
    read -p "Введите DNS-серверы через пробел: " DNS_SERVERS
    read -p "Введите домен поиска: " DOMAIN
    
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/resolv.conf <<EOF
search $DOMAIN
domain $DOMAIN
EOF
    for dns in $DNS_SERVERS; do
        echo "nameserver $dns" >> /etc/net/ifaces/$INTERFACE/resolv.conf
    done
    
    cp /etc/net/ifaces/$INTERFACE/resolv.conf /etc/resolv.conf
    systemctl restart network
    
    echo -e "${GREEN}✓ DNS настроен${NC}"
    cat /etc/resolv.conf
    read -p "Нажми Enter..."
}

setup_vlan() {
    clear
    echo -e "${BLUE}=== Настройка VLAN ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    read -p "Введите физический интерфейс: " PHYS_IF
    read -p "Введите VLAN ID (например, 100): " VID
    read -p "Введите IP-адрес с маской для VLAN (например, 192.168.100.2/24): " VLAN_IP
    read -p "Введите шлюз для VLAN: " VLAN_GW
    
    apt-get update
    apt-get install -y vlan
    modprobe 8021q
    echo "8021q" >> /etc/modules-load.d/vlan.conf
    
    mkdir -p /etc/net/ifaces/$PHYS_IF.$VID
    cat > /etc/net/ifaces/$PHYS_IF.$VID/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
VLAN=yes
VID=$VID
EOF
    echo "$VLAN_IP" > /etc/net/ifaces/$PHYS_IF.$VID/ipv4address
    echo "default via $VLAN_GW" > /etc/net/ifaces/$PHYS_IF.$VID/ipv4route
    
    systemctl restart network
    
    echo -e "${GREEN}✓ VLAN $VID настроен${NC}"
    ip a show $PHYS_IF.$VID
    read -p "Нажми Enter..."
}

setup_secure_ssh() {
    clear
    echo -e "${BLUE}=== Настройка безопасного SSH ===${NC}"
    echo ""
    
    read -p "Введите порт SSH (рекомендуется 2026): " SSH_PORT
    read -p "Введите имя пользователя для разрешения (AllowUsers): " ALLOW_USER
    read -p "Введите максимальное количество попыток входа: " MAX_TRIES
    read -p "Введите текст баннера (например, Authorized access only): " BANNER_TEXT
    
    # Резервная копия
    cp /etc/openssh/sshd_config /etc/openssh/sshd_config.backup
    
    # Настройка
    sed -i "s/^Port .*/Port $SSH_PORT/" /etc/openssh/sshd_config 2>/dev/null || echo "Port $SSH_PORT" >> /etc/openssh/sshd_config
    sed -i "s/^AllowUsers .*/AllowUsers $ALLOW_USER/" /etc/openssh/sshd_config 2>/dev/null || echo "AllowUsers $ALLOW_USER" >> /etc/openssh/sshd_config
    sed -i "s/^MaxAuthTries .*/MaxAuthTries $MAX_TRIES/" /etc/openssh/sshd_config 2>/dev/null || echo "MaxAuthTries $MAX_TRIES" >> /etc/openssh/sshd_config
    echo "Banner /etc/openssh/banner" >> /etc/openssh/sshd_config
    
    echo "$BANNER_TEXT" > /etc/openssh/banner
    
    systemctl restart sshd
    echo -e "${GREEN}✓ SSH настроен на порт $SSH_PORT${NC}"
    read -p "Нажми Enter..."
}

setup_dhcp_server_commands() {
    clear
    echo -e "${BLUE}=== Команды для настройки DHCP-сервера на EcoRouter ===${NC}"
    echo ""
    
    read -p "Введите имя пула адресов (например, VLAN200): " POOL_NAME
    read -p "Введите диапазон адресов (например, 192.168.200.2-192.168.200.254): " POOL_RANGE
    read -p "Введите маску подсети: " MASK
    read -p "Введите адрес шлюза: " GW
    read -p "Введите DNS-сервер: " DNS
    read -p "Введите доменное имя (DNS-суффикс): " DOMAIN
    read -p "Введите номер DHCP-сервера: " SERVER_NUM
    read -p "Введите интерфейс для привязки (например, vl200): " VLAN_IF
    
    echo ""
    echo -e "${YELLOW}=== ВЫПОЛНИТЕ КОМАНДЫ НА ECO-ROUTER ===${NC}"
    echo "----------------------------------------"
    echo "enable"
    echo "configure terminal"
    echo "ip pool $POOL_NAME $POOL_RANGE"
    echo "dhcp-server $SERVER_NUM"
    echo "pool $POOL_NAME $SERVER_NUM"
    echo "mask $MASK"
    echo "gateway $GW"
    echo "dns $DNS"
    echo "domain-name $DOMAIN"
    echo "exit"
    echo "exit"
    echo "interface $VLAN_IF"
    echo "dhcp-server $SERVER_NUM"
    echo "exit"
    echo "write memory"
    echo "exit"
    echo "----------------------------------------"
    read -p "Нажми Enter..."
}

setup_dns_server() {
    clear
    echo -e "${BLUE}=== Настройка DNS-сервера BIND ===${NC}"
    echo ""
    
    read -p "Введите IP-адрес DNS-сервера (на котором настраиваем): " DNS_IP
    read -p "Введите доменную зону (например, au-team.irpo): " ZONE
    read -p "Введите DNS-серверы пересылки (forwarders) через пробел: " FORWARDERS
    
    apt-get update
    apt-get install -y bind bind-utils
    
    # Настройка options.conf
    cat > /var/lib/bind/etc/options.conf <<EOF
options {
    directory "/var/lib/bind";
    listen-on { $DNS_IP; 127.0.0.1; };
    listen-on-v6 { none; };
    allow-query { any; };
    forwarders { $FORWARDERS; };
    recursion yes;
    dnssec-validation no;
};
EOF
    
    # Добавление зоны
    cat >> /var/lib/bind/etc/rfc1912.conf <<EOF
zone "$ZONE" {
    type master;
    file "zone/$ZONE";
};
EOF
    
    mkdir -p /var/lib/bind/etc/zone
    cat > /var/lib/bind/etc/zone/$ZONE <<EOF
\$TTL 86400
@   IN  SOA ns1.$ZONE. admin.$ZONE. (2025122601 3600 1800 604800 86400)
@       IN  NS  ns1.$ZONE.
ns1     IN  A   $DNS_IP
EOF
    
    chgrp -R named /var/lib/bind/etc/zone/
    systemctl enable --now bind
    
    echo -e "${GREEN}✓ DNS-сервер настроен${NC}"
    read -p "Нажми Enter..."
}

setup_timezone() {
    clear
    echo -e "${BLUE}=== Настройка часового пояса ===${NC}"
    echo ""
    
    echo "Доступные часовые пояса:"
    echo "1) Europe/Moscow (MSK, UTC+3)"
    echo "2) Europe/Samara (SAMT, UTC+4)"
    echo "3) Asia/Yekaterinburg (YEKT, UTC+5)"
    echo "4) Asia/Novosibirsk (NOVT, UTC+7)"
    echo "5) Asia/Vladivostok (VLAT, UTC+10)"
    echo "6) Ввести вручную"
    read -p "Выберите часовой пояс (1-6): " TZ_CHOICE
    
    case $TZ_CHOICE in
        1) TIMEZONE="Europe/Moscow" ;;
        2) TIMEZONE="Europe/Samara" ;;
        3) TIMEZONE="Asia/Yekaterinburg" ;;
        4) TIMEZONE="Asia/Novosibirsk" ;;
        5) TIMEZONE="Asia/Vladivostok" ;;
        6) read -p "Введите часовой пояс: " TIMEZONE ;;
        *) TIMEZONE="Europe/Moscow" ;;
    esac
    
    apt-get install -y tzdata
    timedatectl set-timezone "$TIMEZONE"
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    
    echo -e "${GREEN}✓ Часовой пояс установлен: $TIMEZONE${NC}"
    echo "Текущее время: $(date)"
    read -p "Нажми Enter..."
}

setup_local_users() {
    clear
    echo -e "${BLUE}=== Создание локальных пользователей ===${NC}"
    echo ""
    
    read -p "Введите имя пользователя: " USERNAME
    read -p "Введите UID для пользователя: " USER_UID
    read -p "Введите пароль для пользователя: " USER_PASS
    read -s -p "Подтвердите пароль: " USER_PASS_CONFIRM
    echo ""
    
    if [[ "$USER_PASS" != "$USER_PASS_CONFIRM" ]]; then
        echo -e "${RED}Пароли не совпадают!${NC}"
        read -p "Нажми Enter..."
        return
    fi
    
    useradd "$USERNAME" -u "$USER_UID" -m -s /bin/bash 2>/dev/null
    echo "$USERNAME:$USER_PASS" | chpasswd
    usermod -aG wheel "$USERNAME"
    
    # sudo без пароля
    if ! grep -q "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    echo -e "${GREEN}✓ Пользователь $USERNAME создан (UID: $USER_UID)${NC}"
    read -p "Нажми Enter..."
}

setup_nat_forwarding() {
    clear
    echo -e "${BLUE}=== Настройка NAT и IP forwarding ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    read -p "Введите внешний интерфейс (выход в интернет): " EXT_IF
    read -p "Введите внутренние сети для NAT (через пробел, например, 192.168.1.0/24 10.0.0.0/8): " INTERNAL_NETS
    
    # Включение forwarding
    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1
    
    # Установка iptables
    apt-get install -y iptables
    
    # Очистка старых правил
    iptables -t nat -F
    iptables -F
    
    # Добавление правил MASQUERADE
    for net in $INTERNAL_NETS; do
        iptables -t nat -A POSTROUTING -s $net -o $EXT_IF -j MASQUERADE
        echo -e "${GREEN}✓ Добавлен NAT для сети $net${NC}"
    done
    
    # Сохранение
    mkdir -p /etc/sysconfig
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables 2>/dev/null || systemctl enable --now netfilter 2>/dev/null
    
    echo -e "${GREEN}✓ IP forwarding и NAT настроены${NC}"
    read -p "Нажми Enter..."
}

# ==================== МОДУЛЬ 2 ====================
module2_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                     МОДУЛЬ 2 - СЕРВИСЫ                        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1) Настройка Samba Domain Controller"
        echo "2) Настройка RAID 0"
        echo "3) Настройка NFS сервера"
        echo "4) Настройка NFS клиента"
        echo "5) Настройка NTP сервера (chrony)"
        echo "6) Настройка NTP клиента"
        echo "7) Настройка Ansible"
        echo "8) Настройка Docker + testapp"
        echo "9) Настройка LAMP веб-приложения"
        echo "10) Настройка Nginx reverse proxy"
        echo "11) Настройка Яндекс Браузера"
        echo "12) Вернуться в главное меню"
        echo ""
        read -p "Выберите пункт: " choice
        
        case $choice in
            1) setup_samba_dc ;;
            2) setup_raid ;;
            3) setup_nfs_server ;;
            4) setup_nfs_client ;;
            5) setup_ntp_server ;;
            6) setup_ntp_client ;;
            7) setup_ansible ;;
            8) setup_docker ;;
            9) setup_lamp ;;
            10) setup_reverse_proxy ;;
            11) setup_yandex_browser ;;
            12) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

setup_samba_dc() {
    clear
    echo -e "${BLUE}=== Настройка Samba Domain Controller ===${NC}"
    echo ""
    
    read -p "Введите домен (например, au-team.irpo): " DOMAIN
    read -p "Введите Realm (в верхнем регистре, например, AU-TEAM.IRPO): " REALM
    read -p "Введите пароль администратора домена: " ADMIN_PASS
    read -p "Введите DNS forwarder (например, 8.8.8.8): " FORWARDER
    read -p "Введите интерфейс для DNS (например, ens19): " INTERFACE
    
    apt-get update
    apt-get install -y task-samba-dc
    
    for service in smb nmb krb5kdc slapd bind; do
        systemctl disable $service --now 2>/dev/null
    done
    
    rm -f /etc/samba/smb.conf
    rm -rf /var/lib/samba
    mkdir -p /var/lib/samba/sysvol
    
    # Неинтерактивная настройка
    samba-tool domain provision --use-rfc2307 \
        --domain="$DOMAIN" \
        --realm="$REALM" \
        --adminpass="$ADMIN_PASS" \
        --dns-forwarder="$FORWARDER" \
        --server-role=dc
        
    cat > /etc/net/ifaces/$INTERFACE/resolv.conf <<EOF
search $DOMAIN
nameserver 127.0.0.1
EOF
    systemctl restart network
    
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    systemctl enable --now samba
    
    echo -e "${GREEN}✓ Samba DC настроен (домен: $DOMAIN)${NC}"
    read -p "Нажми Enter..."
}

setup_raid() {
    clear
    echo -e "${BLUE}=== Настройка RAID 0 ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные диски:${NC}"
    lsblk | grep -E "NAME|sd|vd|hd"
    echo ""
    
    read -p "Введите первый диск (например, sdb): " DISK1
    read -p "Введите второй диск (например, sdc): " DISK2
    read -p "Введите имя RAID устройства (например, md0): " MD_DEV
    read -p "Введите точку монтирования (например, /raid): " MOUNT_POINT
    
    echo -e "${RED}Все данные на /dev/$DISK1 и /dev/$DISK2 будут уничтожены!${NC}"
    read -p "Продолжить? (y/n): " confirm
    [[ $confirm != "y" ]] && return
    
    apt-get install -y mdadm
    
    mdadm --zero-superblock --force /dev/$DISK1 /dev/$DISK2 2>/dev/null
    wipefs -a /dev/$DISK1 /dev/$DISK2 2>/dev/null
    mdadm --create --verbose /dev/$MD_DEV -l 0 -n 2 /dev/$DISK1 /dev/$DISK2
    
    mkdir -p /etc/mdadm
    mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf
    
    mkfs.ext4 -F /dev/$MD_DEV
    mkdir -p $MOUNT_POINT
    echo "/dev/$MD_DEV $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab
    mount -av
    
    echo -e "${GREEN}✓ RAID 0 настроен, смонтирован в $MOUNT_POINT${NC}"
    df -h $MOUNT_POINT
    read -p "Нажми Enter..."
}

setup_nfs_server() {
    clear
    echo -e "${BLUE}=== Настройка NFS сервера ===${NC}"
    echo ""
    
    read -p "Введите экспортируемую директорию (например, /raid/nfs): " NFS_DIR
    read -p "Введите сеть для доступа (например, 192.168.200.0/24): " ALLOW_NET
    read -p "Введите права доступа (например, rw,sync,no_root_squash): " PERMS
    
    apt-get install -y nfs-server nfs-utils
    mkdir -p "$NFS_DIR"
    chmod 777 "$NFS_DIR"
    
    echo "$NFS_DIR $ALLOW_NET($PERMS)" >> /etc/exports
    exportfs -arv
    
    systemctl enable --now nfs-server
    
    echo -e "${GREEN}✓ NFS сервер настроен: $NFS_DIR для $ALLOW_NET${NC}"
    read -p "Нажми Enter..."
}

setup_nfs_client() {
    clear
    echo -e "${BLUE}=== Настройка NFS клиента ===${NC}"
    echo ""
    
    read -p "Введите IP-адрес NFS сервера: " SERVER_IP
    read -p "Введите экспортируемую директорию на сервере (например, /raid/nfs): " NFS_DIR
    read -p "Введите локальную точку монтирования (например, /mnt/nfs): " MOUNT_POINT
    
    apt-get install -y nfs-utils nfs-clients
    mkdir -p "$MOUNT_POINT"
    
    mount -t nfs "$SERVER_IP:$NFS_DIR" "$MOUNT_POINT"
    echo "$SERVER_IP:$NFS_DIR $MOUNT_POINT nfs defaults 0 0" >> /etc/fstab
    
    echo -e "${GREEN}✓ NFS клиент настроен, смонтирован в $MOUNT_POINT${NC}"
    df -h | grep nfs
    read -p "Нажми Enter..."
}

setup_ntp_server() {
    clear
    echo -e "${BLUE}=== Настройка NTP сервера (chrony) ===${NC}"
    echo ""
    
    read -p "Введите внешние NTP серверы через пробел (например, ntp.mobik.ru): " EXT_NTP
    read -p "Введите стратум сервера (например, 5): " STRATUM
    echo -e "${YELLOW}Введите сети, которым разрешено использовать NTP (по одной):${NC}"
    
    apt-get install -y chrony
    
    cat > /etc/chrony/chrony.conf <<EOF
# Внешние NTP серверы
EOF
    for ntp in $EXT_NTP; do
        echo "server $ntp iburst" >> /etc/chrony/chrony.conf
    done
    
    echo "local stratum $STRATUM" >> /etc/chrony/chrony.conf
    echo "allow all" >> /etc/chrony/chrony.conf
    echo "deny all" >> /etc/chrony/chrony.conf
    
    while true; do
        read -p "Введите сеть для разрешения (или Enter для завершения): " ALLOW_NET
        [[ -z "$ALLOW_NET" ]] && break
        sed -i "s/deny all/allow $ALLOW_NET\\ndeny all/" /etc/chrony/chrony.conf
    done
    
    cat >> /etc/chrony/chrony.conf <<EOF
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF
    
    systemctl enable --now chronyd
    systemctl restart chronyd
    
    echo -e "${GREEN}✓ NTP сервер настроен (стратум $STRATUM)${NC}"
    chronyc tracking
    read -p "Нажми Enter..."
}

setup_ntp_client() {
    clear
    echo -e "${BLUE}=== Настройка NTP клиента ===${NC}"
    echo ""
    
    read -p "Введите IP-адрес NTP сервера: " NTP_SERVER
    
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
    read -p "Нажми Enter..."
}

setup_ansible() {
    clear
    echo -e "${BLUE}=== Настройка Ansible ===${NC}"
    echo ""
    
    read -p "Введите пароль для подключения к хостам: " ANSIBLE_PASS
    
    apt-get install -y ansible sshpass python3-module-pip
    pip3 install ansible-pylibssh
    
    mkdir -p /etc/ansible
    cat > /etc/ansible/ansible.cfg <<EOF
[defaults]
host_key_checking = False
timeout = 30
forks = 10
[ssh_connection]
pipelining = True
EOF
    
    cat > /etc/ansible/hosts <<EOF
[all:vars]
ansible_user=sshuser
ansible_password=$ANSIBLE_PASS

[alt_servers]
# Добавьте ваши ALT Linux серверы в формате:
# hostname ansible_host=IP_адрес

[ecorouters]
# Добавьте ваши EcoRouter в формате:
# hostname ansible_host=IP_адрес ansible_user=net_admin

[ecorouters:vars]
ansible_connection=network_cli
ansible_network_os=cisco.ios

[alt_servers:vars]
ansible_connection=ssh
ansible_python_interpreter=/usr/bin/python3
EOF
    
    echo -e "${GREEN}✓ Ansible настроен${NC}"
    echo -e "${YELLOW}Отредактируйте /etc/ansible/hosts и добавьте ваши хосты${NC}"
    read -p "Нажми Enter..."
}

setup_docker() {
    clear
    echo -e "${BLUE}=== Настройка Docker + testapp ===${NC}"
    echo ""
    
    read -p "Введите путь к директории с образами (site_latest.tar, mariadb_latest.tar): " IMAGES_PATH
    read -p "Введите порт для приложения (например, 8080): " APP_PORT
    read -p "Введите пароль для базы данных: " DB_PASS
    read -p "Введите имя базы данных: " DB_NAME
    read -p "Введите пользователя БД: " DB_USER
    
    apt-get install -y docker-engine docker-compose-v2
    systemctl enable --now docker
    
    docker load < "$IMAGES_PATH/site_latest.tar"
    docker load < "$IMAGES_PATH/mariadb_latest.tar"
    
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
      MYSQL_ROOT_PASSWORD: $DB_PASS
      MYSQL_DATABASE: $DB_NAME
      MYSQL_USER: $DB_USER
      MYSQL_PASSWORD: $DB_PASS
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - testapp_network

  testapp:
    image: site_latest:latest
    container_name: testapp
    restart: always
    ports:
      - "$APP_PORT:80"
    environment:
      DB_HOST: db
      DB_NAME: $DB_NAME
      DB_USER: $DB_USER
      DB_PASSWORD: $DB_PASS
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
    
    echo -e "${GREEN}✓ Docker контейнеры запущены на порту $APP_PORT${NC}"
    docker ps
    read -p "Нажми Enter..."
}

setup_lamp() {
    clear
    echo -e "${BLUE}=== Настройка LAMP веб-приложения ===${NC}"
    echo ""
    
    read -p "Введите путь к директории с файлами приложения (index.php, dump.sql): " WEB_PATH
    read -p "Введите имя базы данных: " DB_NAME
    read -p "Введите пользователя БД: " DB_USER
    read -p "Введите пароль БД: " DB_PASS
    
    apt-get install -y lamp-server
    systemctl enable --now mariadb
    systemctl enable --now httpd2
    
    cp "$WEB_PATH/index.php" /var/www/html/
    cp "$WEB_PATH/logo.png" /var/www/html/ 2>/dev/null
    
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
DROP USER IF EXISTS '$DB_USER'@'localhost';
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    
    mariadb -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" < "$WEB_PATH/dump.sql" 2>/dev/null
    
    sed -i "s/'dbname' => '[^']*'/'dbname' => '$DB_NAME'/g" /var/www/html/index.php
    sed -i "s/'user' => '[^']*'/'user' => '$DB_USER'/g" /var/www/html/index.php
    sed -i "s/'password' => '[^']*'/'password' => '$DB_PASS'/g" /var/www/html/index.php
    
    echo -e "${GREEN}✓ LAMP веб-приложение настроено${NC}"
    read -p "Нажми Enter..."
}

setup_reverse_proxy() {
    clear
    echo -e "${BLUE}=== Настройка Nginx reverse proxy ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Введите настройки для проксируемых доменов (по одному):${NC}"
    
    apt-get install -y nginx
    
    cat > /etc/nginx/sites-available.d/default.conf <<'EOF'
# Конфигурация будет добавлена
EOF
    
    while true; do
        read -p "Введите доменное имя (или Enter для завершения): " DOMAIN_NAME
        [[ -z "$DOMAIN_NAME" ]] && break
        read -p "Введите IP-адрес бекенда: " BACKEND_IP
        read -p "Введите порт бекенда: " BACKEND_PORT
        
        cat >> /etc/nginx/sites-available.d/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    location / {
        proxy_pass http://$BACKEND_IP:$BACKEND_PORT;
        proxy_set_header Host \$host;
    }
}

EOF
    done
    
    ln -sf /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/
    nginx -t && systemctl restart nginx
    
    echo -e "${GREEN}✓ Nginx reverse proxy настроен${NC}"
    read -p "Нажми Enter..."
}

setup_yandex_browser() {
    clear
    echo -e "${BLUE}=== Установка Яндекс Браузера ===${NC}"
    echo ""
    
    apt-get update
    apt-get install -y yandex-browser-stable
    
    if command -v yandex-browser &>/dev/null; then
        echo -e "${GREEN}✓ Яндекс Браузер установлен${NC}"
        yandex-browser --version
    else
        echo -e "${RED}✗ Ошибка установки${NC}"
    fi
    read -p "Нажми Enter..."
}

# ==================== МОДУЛЬ 3 ====================
module3_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                   МОДУЛЬ 3 - БЕЗОПАСНОСТЬ                    ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1) Импорт пользователей из CSV в домен"
        echo "2) Настройка центра сертификации (ГОСТ)"
        echo "3) Настройка Nginx HTTPS с ГОСТ"
        echo "4) Установка корневого сертификата"
        echo "5) Настройка CUPS принт-сервера"
        echo "6) Настройка CUPS клиента"
        echo "7) Вернуться в главное меню"
        echo ""
        read -p "Выберите пункт: " choice
        
        case $choice in
            1) import_users_csv ;;
            2) setup_ca_gost ;;
            3) setup_nginx_https_gost ;;
            4) install_root_certificate ;;
            5) setup_cups_server_v3 ;;
            6) setup_cups_client_v3 ;;
            7) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

import_users_csv() {
    clear
    echo -e "${BLUE}=== Импорт пользователей из CSV в домен ===${NC}"
    echo ""
    
    read -p "Введите путь к CSV файлу (например, /mnt/users.csv): " CSV_FILE
    read -p "Введите пароль администратора домена: " ADMIN_PASS
    read -p "Введите Realm (например, AU-TEAM.IRPO): " REALM
    
    echo "$ADMIN_PASS" | kinit administrator@$REALM 2>/dev/null
    
    # Создание OU
    echo -e "${YELLOW}Введите названия OU для создания (через пробел):${NC}"
    read -p "OU: " OUS
    
    for ou in $OUS; do
        samba-tool ou create "OU=$ou" 2>/dev/null
        echo -e "${GREEN}✓ OU $ou создан${NC}"
    done
    
    # Импорт
    tail -n +2 "$CSV_FILE" | while IFS=',' read -r login sname fname phone email org position manager ou; do
        login=$(echo "$login" | sed 's/"//g' | xargs | tr '[:upper:]' '[:lower:]')
        fname=$(echo "$fname" | sed 's/"//g' | xargs)
        sname=$(echo "$sname" | sed 's/"//g' | xargs)
        ou=$(echo "$ou" | sed 's/"//g' | xargs)
        
        if [[ -n "$ou" && "$ou" != "-" ]]; then
            samba-tool user create "$login" "P@ssw0rd" \
                --given-name="$fname" \
                --surname="$sname" \
                --userou="OU=$ou" 2>/dev/null
        else
            samba-tool user create "$login" "P@ssw0rd" \
                --given-name="$fname" \
                --surname="$sname" 2>/dev/null
        fi
        
        if [[ $? -eq 0 ]]; then
            samba-tool user setexpiry "$login" --noexpiry 2>/dev/null
            samba-tool user enable "$login" 2>/dev/null
            echo -e "${GREEN}✓ $login импортирован${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ Импорт завершен${NC}"
    read -p "Нажми Enter..."
}

setup_ca_gost() {
    clear
    echo -e "${BLUE}=== Настройка центра сертификации (ГОСТ) ===${NC}"
    echo ""
    
    read -p "Введите количество дней действия сертификатов: " CA_DAYS
    read -p "Введите IP адрес ISP для копирования сертификатов: " ISP_IP
    read -p "Введите IP адрес HQ-CLI для копирования сертификатов: " CLI_IP
    
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null
    
    mkdir -p /etc/ssl/certs /etc/ssl/private
    cd /etc/ssl/certs
    
    # Корневой сертификат
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
    chmod 600 ca.key
    openssl req -new -x509 -md_gost12_256 -days "$CA_DAYS" -key ca.key -out ca.cer \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=au-team/CN=au-team Root CA"
    
    # Сертификаты для доменов
    for domain in web.au-team.irpo docker.au-team.irpo; do
        openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out ${domain}.key
        chmod 600 ${domain}.key
        openssl req -new -md_gost12_256 -key ${domain}.key -out ${domain}.csr \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=au-team/CN=$domain"
        openssl x509 -req -in ${domain}.csr -CA ca.cer -CAkey ca.key -CAcreateserial \
            -out ${domain}.cer -days "$CA_DAYS" -md_gost12_256
        
        # Копирование на ISP
        scp -o StrictHostKeyChecking=no ${domain}.key ${domain}.cer root@$ISP_IP:/root/ 2>/dev/null
    done
    
    # Копирование корневого сертификата на HQ-CLI
    scp -o StrictHostKeyChecking=no ca.cer root@$CLI_IP:/root/ 2>/dev/null
    
    echo -e "${GREEN}✓ Центр сертификации настроен (сертификаты на $CA_DAYS дней)${NC}"
    read -p "Нажми Enter..."
}

setup_nginx_https_gost() {
    clear
    echo -e "${BLUE}=== Настройка Nginx HTTPS с ГОСТ ===${NC}"
    echo ""
    
    read -p "Введите IP адрес бекенда для web.au-team.irpo: " WEB_BACKEND
    read -p "Введите IP адрес бекенда для docker.au-team.irpo: " DOCKER_BACKEND
    
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null
    
    mkdir -p /etc/nginx/ssl
    for domain in web.au-team.irpo docker.au-team.irpo; do
        if [[ -f /root/${domain}.key ]]; then
            cp /root/${domain}.key /etc/nginx/ssl/
            cp /root/${domain}.cer /etc/nginx/ssl/
        fi
    done
    
    cat > /etc/nginx/sites-available.d/default.conf <<EOF
server { listen 80; server_name web.au-team.irpo; return 301 https://\$host\$request_uri; }
server { listen 80; server_name docker.au-team.irpo; return 301 https://\$host\$request_uri; }

server {
    listen 443 ssl;
    server_name web.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/web.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers GOST2012-GOST8912-GOST8912;
    location / { proxy_pass http://$WEB_BACKEND:80; proxy_set_header Host \$host; }
}

server {
    listen 443 ssl;
    server_name docker.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/docker.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/docker.au-team.irpo.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers GOST2012-GOST8912-GOST8912;
    location / { proxy_pass http://$DOCKER_BACKEND:8080; proxy_set_header Host \$host; }
}
EOF
    
    nginx -t && systemctl restart nginx
    echo -e "${GREEN}✓ Nginx HTTPS с ГОСТ настроен${NC}"
    read -p "Нажми Enter..."
}

install_root_certificate() {
    clear
    echo -e "${BLUE}=== Установка корневого сертификата ===${NC}"
    echo ""
    
    read -p "Введите путь к корневому сертификату (ca.cer): " CERT_PATH
    
    if [[ -f "$CERT_PATH" ]]; then
        cp "$CERT_PATH" /etc/pki/ca-trust/source/anchors/
        update-ca-trust
        echo -e "${GREEN}✓ Корневой сертификат установлен${NC}"
    else
        echo -e "${RED}Файл не найден!${NC}"
    fi
    read -p "Нажми Enter..."
}

setup_cups_server_v3() {
    clear
    echo -e "${BLUE}=== Настройка CUPS принт-сервера ===${NC}"
    echo ""
    
    read -p "Введите имя принтера (например, Virtual_PDF_Printer): " PRINTER_NAME
    echo -e "${YELLOW}Введите сети для доступа к принтеру (по одной, Enter для завершения):${NC}"
    
    apt-get install -y cups cups-pdf
    
    cat > /etc/cups/cupsd.conf <<'CUPS_CONF'
Listen 0.0.0.0:631
<Location />
  Order allow,deny
  Allow localhost
CUPS_CONF
    
    while true; do
        read -p "Разрешить сеть (например, 192.168.200.0/24): " ALLOW_NET
        [[ -z "$ALLOW_NET" ]] && break
        echo "  Allow $ALLOW_NET" >> /etc/cups/cupsd.conf
    done
    echo "</Location>" >> /etc/cups/cupsd.conf
    
    cupsctl --share-printers --remote-any
    systemctl enable --now cups
    systemctl restart cups
    
    lpadmin -p "$PRINTER_NAME" -E -v cups-pdf:/ -m everywhere 2>/dev/null
    lpoptions -d "$PRINTER_NAME"
    
    echo -e "${GREEN}✓ CUPS принт-сервер настроен (принтер: $PRINTER_NAME)${NC}"
    read -p "Нажми Enter..."
}

setup_cups_client_v3() {
    clear
    echo -e "${BLUE}=== Настройка CUPS клиента ===${NC}"
    echo ""
    
    read -p "Введите IP-адрес CUPS сервера: " SERVER_IP
    read -p "Введите имя принтера на сервере: " PRINTER_NAME
    read -p "Введите локальное имя принтера: " LOCAL_PRINTER
    
    apt-get install -y cups-client cups-common
    
    if ! grep -q "cups-server" /etc/hosts; then
        echo "$SERVER_IP cups-server" >> /etc/hosts
    fi
    
    lpadmin -p "$LOCAL_PRINTER" -E -v ipp://$SERVER_IP:631/printers/$PRINTER_NAME -m everywhere 2>/dev/null
    lpoptions -d "$LOCAL_PRINTER"
    
    echo -e "${GREEN}✓ Принтер $LOCAL_PRINTER подключен и установлен по умолчанию${NC}"
    lpstat -p -d
    read -p "Нажми Enter..."
}

# ==================== ГЛАВНОЕ МЕНЮ ====================
show_main_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    УНИВЕРСАЛЬНЫЙ СКРИПТ НАСТРОЙКИ                    ║${NC}"
    echo -e "${CYAN}║                      ALT LINUX / Сис АДМИН                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Текущее устройство:${NC} $(hostname)"
    echo ""
    echo -e "${GREEN}┌────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│                         ВЫБЕРИТЕ МОДУЛЬ                            │${NC}"
    echo -e "${GREEN}├────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}│  1) МОДУЛЬ 1 - Настройка сети и базовых сервисов                   │${NC}"
    echo -e "${GREEN}│  2) МОДУЛЬ 2 - Настройка серверных приложений                      │${NC}"
    echo -e "${GREEN}│  3) МОДУЛЬ 3 - Безопасность и сертификаты                          │${NC}"
    echo -e "${GREEN}│  4) Выход                                                          │${NC}"
    echo -e "${GREEN}└────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "Выберите модуль (1-4): " main_choice
}

# ==================== ОСНОВНОЙ ЦИКЛ ====================
while true; do
    show_main_menu
    case $main_choice in
        1) module1_menu ;;
        2) module2_menu ;;
        3) module3_menu ;;
        4) echo -e "${GREEN}Выход...${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
    esac
done