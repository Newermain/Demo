#!/bin/bash

# =============================================
# МОДУЛЬ 1 - ПОЛНАЯ НАСТРОЙКА ALT LINUX
# Специальность: Сетевое и системное администрирование
# Устройства: ISP, HQ-SRV, BR-SRV, HQ-CLI
# Задания: 1, 2, 1.3, 1.4, 1.5, 1.9, 1.10, 1.11
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
    echo "Пример: sudo ./1module"
    exit 1
fi

# Глобальные переменные
INTERFACE=""
CURRENT_DEVICE=""

# Функция определения текущего устройства
detect_device() {
    HOSTNAME=$(hostname)
    if [[ "$HOSTNAME" == "hq-srv.au-team.irpo" ]]; then
        CURRENT_DEVICE="HQ-SRV"
    elif [[ "$HOSTNAME" == "br-srv.au-team.irpo" ]]; then
        CURRENT_DEVICE="BR-SRV"
    elif [[ "$HOSTNAME" == "hq-cli.au-team.irpo" ]]; then
        CURRENT_DEVICE="HQ-CLI"
    elif [[ "$HOSTNAME" == "isp" ]]; then
        CURRENT_DEVICE="ISP"
    else
        CURRENT_DEVICE="UNKNOWN"
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

# ==================== ЗАДАНИЕ 1 ====================
setup_hq_srv() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1: Настройка HQ-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    select_interface || return 1
    
    # Настройка имени хоста
    echo -e "${BLUE}[1/4] Настройка имени хоста...${NC}"
    hostnamectl set-hostname hq-srv.au-team.irpo
    echo "HOSTNAME=hq-srv.au-team.irpo" > /etc/sysconfig/network
    echo -e "${GREEN}✓ Имя хоста: hq-srv.au-team.irpo${NC}"
    
    # Настройка сети
    echo -e "${BLUE}[2/4] Настройка сети...${NC}"
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    echo "192.168.100.2/27" > /etc/net/ifaces/$INTERFACE/ipv4address
    echo "default via 192.168.100.1" > /etc/net/ifaces/$INTERFACE/ipv4route
    
    # DNS временно для установки пакетов
    echo "nameserver 77.88.8.8" > /etc/net/ifaces/$INTERFACE/resolv.conf
    
    echo -e "${BLUE}[3/4] Перезапуск сети...${NC}"
    systemctl restart network
    
    echo -e "${BLUE}[4/4] Проверка...${NC}"
    echo -e "${GREEN}✓ HQ-SRV настроен:${NC}"
    ip a show $INTERFACE | grep inet
    echo ""
    echo -e "${GREEN}Задание 1 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

setup_br_srv() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1: Настройка BR-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    select_interface || return 1
    
    # Настройка имени хоста
    echo -e "${BLUE}[1/4] Настройка имени хоста...${NC}"
    hostnamectl set-hostname br-srv.au-team.irpo
    echo "HOSTNAME=br-srv.au-team.irpo" > /etc/sysconfig/network
    echo -e "${GREEN}✓ Имя хоста: br-srv.au-team.irpo${NC}"
    
    # Настройка сети
    echo -e "${BLUE}[2/4] Настройка сети...${NC}"
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    echo "192.168.0.2/28" > /etc/net/ifaces/$INTERFACE/ipv4address
    echo "default via 192.168.0.1" > /etc/net/ifaces/$INTERFACE/ipv4route
    echo "nameserver 77.88.8.8" > /etc/net/ifaces/$INTERFACE/resolv.conf
    
    echo -e "${BLUE}[3/4] Перезапуск сети...${NC}"
    systemctl restart network
    
    echo -e "${BLUE}[4/4] Проверка...${NC}"
    echo -e "${GREEN}✓ BR-SRV настроен:${NC}"
    ip a show $INTERFACE | grep inet
    
    # Проверка доступности шлюза
    if ping -c 2 192.168.0.1 &>/dev/null; then
        echo -e "${GREEN}✓ Шлюз 192.168.0.1 доступен${NC}"
    else
        echo -e "${YELLOW}⚠ Шлюз не доступен (BR-RTR может быть не настроен)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Задание 1 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 2 ====================
setup_isp() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 2: Настройка ISP${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}Доступные интерфейсы:${NC}"
    ls /sys/class/net/ | grep -v lo
    echo ""
    
    read -p "Внешний интерфейс (DHCP, к провайдеру): " EXT_IF
    read -p "Интерфейс к HQ-RTR (172.16.1.0/28): " HQ_IF
    read -p "Интерфейс к BR-RTR (172.16.2.0/28): " BR_IF
    
    # 1. Внешний интерфейс (DHCP)
    echo -e "${BLUE}[1/6] Настройка внешнего интерфейса $EXT_IF (DHCP)...${NC}"
    mkdir -p /etc/net/ifaces/$EXT_IF
    cat > /etc/net/ifaces/$EXT_IF/options <<EOF
TYPE=eth
BOOTPROTO=dhcp
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    
    # 2. Интерфейс к HQ-RTR
    echo -e "${BLUE}[2/6] Настройка интерфейса к HQ-RTR $HQ_IF...${NC}"
    mkdir -p /etc/net/ifaces/$HQ_IF
    cat > /etc/net/ifaces/$HQ_IF/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    echo "172.16.1.1/28" > /etc/net/ifaces/$HQ_IF/ipv4address
    
    # 3. Интерфейс к BR-RTR
    echo -e "${BLUE}[3/6] Настройка интерфейса к BR-RTR $BR_IF...${NC}"
    mkdir -p /etc/net/ifaces/$BR_IF
    cat > /etc/net/ifaces/$BR_IF/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    echo "172.16.2.1/28" > /etc/net/ifaces/$BR_IF/ipv4address
    
    # 4. Включение IP forwarding
    echo -e "${BLUE}[4/6] Включение IP forwarding...${NC}"
    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1
    
    # 5. Настройка NAT
    echo -e "${BLUE}[5/6] Настройка NAT...${NC}"
    apt-get update
    apt-get install -y iptables
    
    iptables -t nat -F
    iptables -F
    iptables -t nat -A POSTROUTING -s 172.16.1.0/28 -o $EXT_IF -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 172.16.2.0/28 -o $EXT_IF -j MASQUERADE
    
    mkdir -p /etc/sysconfig
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables 2>/dev/null || systemctl enable --now netfilter
    
    # 6. Перезапуск и проверка
    echo -e "${BLUE}[6/6] Перезапуск сети и проверка...${NC}"
    systemctl restart network
    
    echo ""
    echo -e "${GREEN}✓ ISP настроен:${NC}"
    echo "  - $EXT_IF: DHCP"
    echo "  - $HQ_IF: 172.16.1.1/28"
    echo "  - $BR_IF: 172.16.2.1/28"
    echo "  - IP forwarding: включен"
    echo "  - NAT: настроен для сетей 172.16.1.0/28 и 172.16.2.0/28"
    
    echo ""
    echo -e "${GREEN}Задание 2 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.3 ====================
setup_users() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.3: Создание пользователей${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Создание пользователя sshuser
    echo -e "${BLUE}[1/3] Создание пользователя sshuser (UID 2026)...${NC}"
    if id "sshuser" &>/dev/null; then
        echo -e "${YELLOW}Пользователь уже существует, удаляем...${NC}"
        userdel -r sshuser 2>/dev/null
    fi
    
    useradd sshuser -u 2026 -m -s /bin/bash
    echo "sshuser:P@ssw0rd" | chpasswd
    echo -e "${GREEN}✓ Пользователь sshuser создан (UID: $(id -u sshuser))${NC}"
    
    # Настройка sudo без пароля
    echo -e "${BLUE}[2/3] Настройка sudo без пароля...${NC}"
    usermod -aG wheel sshuser
    
    if ! grep -q "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    echo -e "${GREEN}✓ sudo без пароля настроен${NC}"
    
    # Проверка
    echo -e "${BLUE}[3/3] Проверка...${NC}"
    echo ""
    echo -e "${YELLOW}Информация о пользователе:${NC}"
    id sshuser
    echo ""
    
    if sudo -u sshuser sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓ sudo работает без пароля${NC}"
    else
        echo -e "${RED}✗ Ошибка: sudo требует пароль${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Задание 1.3 выполнено!${NC}"
    echo -e "${YELLOW}Пароль пользователя sshuser: P@ssw0rd${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.4 ====================
setup_vlan_hq_srv() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.4: Настройка VLAN на HQ-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    select_interface || return 1
    
    echo -e "${BLUE}[1/4] Установка пакета vlan...${NC}"
    apt-get update
    apt-get install -y vlan
    
    echo -e "${BLUE}[2/4] Загрузка модуля 8021q...${NC}"
    modprobe 8021q
    echo "8021q" >> /etc/modules-load.d/vlan.conf
    
    echo -e "${BLUE}[3/4] Создание VLAN интерфейса $INTERFACE.100...${NC}"
    mkdir -p /etc/net/ifaces/$INTERFACE.100
    cat > /etc/net/ifaces/$INTERFACE.100/options <<EOF
TYPE=eth
BOOTPROTO=static
DISABLED=no
VLAN=yes
VID=100
EOF
    echo "192.168.100.2/27" > /etc/net/ifaces/$INTERFACE.100/ipv4address
    echo "default via 192.168.100.1" > /etc/net/ifaces/$INTERFACE.100/ipv4route
    
    echo -e "${BLUE}[4/4] Перезапуск сети...${NC}"
    systemctl restart network
    
    echo -e "${GREEN}✓ VLAN 100 настроен на HQ-SRV${NC}"
    echo ""
    echo -e "${YELLOW}Проверка:${NC}"
    ip a show $INTERFACE.100 2>/dev/null || echo "Интерфейс $INTERFACE.100 создается..."
    
    echo ""
    echo -e "${GREEN}Задание 1.4 выполнено!${NC}"
    echo -e "${YELLOW}Не забудь настроить VLAN на гипервизоре PVE и EcoRouter!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.5 ====================
setup_secure_ssh() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.5: Безопасный SSH доступ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Проверка наличия пользователя sshuser
    if ! id "sshuser" &>/dev/null; then
        echo -e "${RED}Ошибка: Пользователь sshuser не существует!${NC}"
        echo -e "${YELLOW}Сначала выполни задание 1.3${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    echo -e "${BLUE}[1/5] Создание резервной копии sshd_config...${NC}"
    cp /etc/openssh/sshd_config /etc/openssh/sshd_config.backup
    
    echo -e "${BLUE}[2/5] Настройка параметров SSH...${NC}"
    # Удаляем старые параметры
    sed -i '/^Port /d' /etc/openssh/sshd_config
    sed -i '/^AllowUsers /d' /etc/openssh/sshd_config
    sed -i '/^MaxAuthTries /d' /etc/openssh/sshd_config
    sed -i '/^Banner /d' /etc/openssh/sshd_config
    
    # Добавляем новые
    cat >> /etc/openssh/sshd_config <<EOF
Port 2026
AllowUsers sshuser
MaxAuthTries 2
Banner /etc/openssh/banner
EOF
    
    echo -e "${BLUE}[3/5] Создание баннера...${NC}"
    echo "Authorized access only" > /etc/openssh/banner
    
    echo -e "${BLUE}[4/5] Проверка конфигурации...${NC}"
    if sshd -t 2>/dev/null; then
        echo -e "${GREEN}✓ Конфигурация верна${NC}"
    else
        echo -e "${RED}✗ Ошибка в конфигурации! Восстанавливаем...${NC}"
        cp /etc/openssh/sshd_config.backup /etc/openssh/sshd_config
        systemctl restart sshd
        return 1
    fi
    
    echo -e "${BLUE}[5/5] Перезапуск SSH...${NC}"
    systemctl restart sshd
    
    echo ""
    echo -e "${GREEN}✓ SSH настроен:${NC}"
    echo "  - Порт: 2026"
    echo "  - Разрешены: sshuser"
    echo "  - Максимум попыток: 2"
    echo "  - Баннер: Authorized access only"
    echo ""
    echo -e "${GREEN}Задание 1.5 выполнено!${NC}"
    echo -e "${YELLOW}Подключение: ssh sshuser@$(hostname -I | awk '{print $1}') -p 2026${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.9 ====================
setup_dhcp_client() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.9: Настройка DHCP-клиента${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    select_interface || return 1
    
    echo -e "${BLUE}[1/3] Настройка интерфейса $INTERFACE на DHCP...${NC}"
    mkdir -p /etc/net/ifaces/$INTERFACE
    cat > /etc/net/ifaces/$INTERFACE/options <<EOF
TYPE=eth
BOOTPROTO=dhcp
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
    
    # Удаляем статические настройки
    rm -f /etc/net/ifaces/$INTERFACE/ipv4address
    rm -f /etc/net/ifaces/$INTERFACE/ipv4route
    
    echo -e "${BLUE}[2/3] Перезапуск сети...${NC}"
    systemctl restart network
    
    echo -e "${BLUE}[3/3] Проверка полученных параметров...${NC}"
    sleep 3
    
    echo ""
    echo -e "${YELLOW}Полученные параметры:${NC}"
    IP_ADDR=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' 2>/dev/null)
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -1)
    
    echo -e "IP-адрес: ${GREEN}$IP_ADDR${NC}"
    echo -e "Шлюз: ${GREEN}$GATEWAY${NC}"
    echo -e "DNS: ${GREEN}$DNS${NC}"
    
    echo ""
    echo -e "${GREEN}Задание 1.9 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.10 ====================
setup_dns_server() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.10: Настройка DNS-сервера${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Проверка, что это HQ-SRV
    if [[ $(hostname) != "hq-srv.au-team.irpo" ]]; then
        echo -e "${RED}DNS-сервер настраивается ТОЛЬКО на HQ-SRV!${NC}"
        echo -e "${YELLOW}Текущее имя: $(hostname)${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    echo -e "${BLUE}[1/8] Установка BIND...${NC}"
    apt-get update
    apt-get install -y bind bind-utils
    
    echo -e "${BLUE}[2/8] Настройка options.conf...${NC}"
    cat > /var/lib/bind/etc/options.conf <<EOF
options {
    directory "/var/lib/bind";
    listen-on { 192.168.100.2; 127.0.0.1; };
    listen-on-v6 { none; };
    allow-query { 192.168.100.0/27; 192.168.200.0/24; 127.0.0.0/8; };
    allow-transfer { none; };
    forwarders {
        77.88.8.7;
        77.88.8.3;
        8.8.8.8;
    };
    recursion yes;
    dnssec-validation no;
};
EOF
    
    echo -e "${BLUE}[3/8] Добавление зон в rfc1912.conf...${NC}"
    sed -i '/zone "au-team.irpo"/d' /var/lib/bind/etc/rfc1912.conf
    sed -i '/zone "100.168.192.in-addr.arpa"/d' /var/lib/bind/etc/rfc1912.conf
    sed -i '/zone "200.168.192.in-addr.arpa"/d' /var/lib/bind/etc/rfc1912.conf
    
    cat >> /var/lib/bind/etc/rfc1912.conf <<EOF

zone "au-team.irpo" {
    type master;
    file "zone/au-team.irpo";
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "zone/100.168.192.in-addr.arpa";
};

zone "200.168.192.in-addr.arpa" {
    type master;
    file "zone/200.168.192.in-addr.arpa";
};
EOF
    
    echo -e "${BLUE}[4/8] Создание файлов зон...${NC}"
    mkdir -p /var/lib/bind/etc/zone
    
    # Прямая зона
    cat > /var/lib/bind/etc/zone/au-team.irpo <<EOF
\$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
    2025122601  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@       IN  NS  hq-srv.au-team.irpo.

hq-srv    IN  A   192.168.100.2
hq-rtr    IN  A   192.168.100.1
hq-cli    IN  A   192.168.200.2
br-srv    IN  A   192.168.0.2
br-rtr    IN  A   172.16.2.2
docker    IN  A   172.16.1.2
web       IN  A   172.16.2.2
EOF
    
    # Обратная зона для 192.168.100.0/27
    cat > /var/lib/bind/etc/zone/100.168.192.in-addr.arpa <<EOF
\$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
    2025122601  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@       IN  NS  hq-srv.au-team.irpo.

2       IN  PTR hq-srv.au-team.irpo.
1       IN  PTR hq-rtr.au-team.irpo.
EOF
    
    # Обратная зона для 192.168.200.0/24
    cat > /var/lib/bind/etc/zone/200.168.192.in-addr.arpa <<EOF
\$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
    2025122601  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@       IN  NS  hq-srv.au-team.irpo.

2       IN  PTR hq-cli.au-team.irpo.
EOF
    
    echo -e "${BLUE}[5/8] Настройка прав...${NC}"
    chgrp -R named /var/lib/bind/etc/zone/
    chmod 640 /var/lib/bind/etc/zone/*
    
    echo -e "${BLUE}[6/8] Генерация rndc ключа...${NC}"
    rndc-confgen > /var/lib/bind/etc/rndc.key
    sed -i '6,$d' /var/lib/bind/etc/rndc.key
    chown root:named /var/lib/bind/etc/rndc.key
    chmod 640 /var/lib/bind/etc/rndc.key
    
    echo -e "${BLUE}[7/8] Проверка конфигурации...${NC}"
    if named-checkconf; then
        echo -e "${GREEN}✓ Конфигурация верна${NC}"
    else
        echo -e "${RED}✗ Ошибка в конфигурации!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[8/8] Запуск BIND...${NC}"
    systemctl enable --now bind
    systemctl restart bind
    
    # Настройка DNS резолвера
    cat > /etc/net/ifaces/lo/resolv.conf <<EOF
nameserver 127.0.0.1
domain au-team.irpo
search au-team.irpo
EOF
    systemctl restart network
    
    echo ""
    echo -e "${GREEN}✓ DNS-сервер настроен!${NC}"
    echo ""
    echo -e "${YELLOW}Проверка A записей:${NC}"
    host hq-srv.au-team.irpo localhost
    host hq-rtr.au-team.irpo localhost
    host hq-cli.au-team.irpo localhost
    
    echo ""
    echo -e "${GREEN}Задание 1.10 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 1.11 ====================
setup_timezone() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 1.11: Настройка часового пояса${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}Выбери часовой пояс:${NC}"
    echo "1) Europe/Moscow (UTC+3) - Москва"
    echo "2) Europe/Samara (UTC+4) - Самара"
    echo "3) Asia/Yekaterinburg (UTC+5) - Екатеринбург"
    echo "4) Asia/Novosibirsk (UTC+7) - Новосибирск"
    echo "5) Asia/Vladivostok (UTC+10) - Владивосток"
    read -p "Выбери (1-5): " tz_choice
    
    case $tz_choice in
        1) TIMEZONE="Europe/Moscow" ;;
        2) TIMEZONE="Europe/Samara" ;;
        3) TIMEZONE="Asia/Yekaterinburg" ;;
        4) TIMEZONE="Asia/Novosibirsk" ;;
        5) TIMEZONE="Asia/Vladivostok" ;;
        *) TIMEZONE="Europe/Moscow" ;;
    esac
    
    echo -e "${BLUE}[1/3] Установка tzdata...${NC}"
    apt-get update
    apt-get install -y tzdata
    
    echo -e "${BLUE}[2/3] Установка часового пояса $TIMEZONE...${NC}"
    timedatectl set-timezone $TIMEZONE
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    
    echo -e "${BLUE}[3/3] Синхронизация аппаратного времени...${NC}"
    hwclock --systohc
    
    echo ""
    echo -e "${GREEN}✓ Часовой пояс установлен: $TIMEZONE${NC}"
    echo -e "${GREEN}✓ Текущее время: $(date)${NC}"
    echo ""
    echo -e "${GREEN}Задание 1.11 выполнено!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ГЛАВНОЕ МЕНЮ ====================
show_main_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 МОДУЛЬ 1 - ALT LINUX НАСТРОЙКА                ║${NC}"
    echo -e "${CYAN}║           Сетевое и системное администрирование              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Текущее устройство:${NC} $(hostname)"
    echo ""
    echo -e "${GREEN}┌────────────── ЗАДАНИЯ МОДУЛЯ 1 ──────────────┐${NC}"
    echo -e "${GREEN}│  1) Задание 1    - Настройка HQ-SRV         │${NC}"
    echo -e "${GREEN}│  2) Задание 1    - Настройка BR-SRV         │${NC}"
    echo -e "${GREEN}│  3) Задание 2    - Настройка ISP            │${NC}"
    echo -e "${GREEN}│  4) Задание 1.3  - Создание пользователей   │${NC}"
    echo -e "${GREEN}│  5) Задание 1.4  - Настройка VLAN (HQ-SRV)  │${NC}"
    echo -e "${GREEN}│  6) Задание 1.5  - Безопасный SSH           │${NC}"
    echo -e "${GREEN}│  7) Задание 1.9  - DHCP-клиент (HQ-CLI)     │${NC}"
    echo -e "${GREEN}│  8) Задание 1.10 - DNS-сервер (HQ-SRV)      │${NC}"
    echo -e "${GREEN}│  9) Задание 1.11 - Настройка часового пояса │${NC}"
    echo -e "${GREEN}│ 10) Выход                                    │${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Совет: Запускай скрипт на нужном устройстве:${NC}"
    echo -e "  - HQ-SRV:  пункты 1, 4, 5, 6, 8, 9"
    echo -e "  - BR-SRV:  пункты 2, 4, 6, 9"
    echo -e "  - ISP:     пункт 3, 9"
    echo -e "  - HQ-CLI:  пункты 4, 6, 7, 9"
    echo ""
    read -p "Выбери пункт меню (1-10): " choice
}

# ==================== ОСНОВНОЙ ЦИКЛ ====================
while true; do
    show_main_menu
    case $choice in
        1) setup_hq_srv ;;
        2) setup_br_srv ;;
        3) setup_isp ;;
        4) setup_users ;;
        5) setup_vlan_hq_srv ;;
        6) setup_secure_ssh ;;
        7) setup_dhcp_client ;;
        8) setup_dns_server ;;
        9) setup_timezone ;;
        10) echo -e "${GREEN}Выход...${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
    esac
done