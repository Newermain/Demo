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
        echo -e "${CYAN}║                       МОДУЛЬ 1 - СЕТЬ                        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1) Настройка ISP"
        echo "2) Базовые настройки самых крутых роутеров (HQ-RTR и BR-RTR)"
        echo "3) Настройка DHCP-клиента (клиент)"
        echo "4) Настройка DNS-резолвера (HQ-SRV)"
        echo "5) Настройка VLAN на интерфейсе (BR и HQ RTRы)"
        echo "6) Настройка безопасного SSH (порт 2026, баннер) (HQ-SRV/BR-SRV)"
        echo "7) Настройка DHCP-сервера (только команды для EcoRouter) (BR и HQ RTRы)"
        echo "8) Настройка DNS-сервера BIND (HQ-SRV)"
        echo "9) Настройка часового пояса (все хосты)"
        echo "10) Создание локальных пользователей (HQ и BR SRVы и RTRы)"
        echo "11) Настройка NAT и IP forwarding (HQ и BR RTRы)"
        echo "12) Настройка DHCP-сервера (EcoRouter клон 6 пункта) (BR и HQ RTRы)"
        echo "13) Вернуться в главное меню"
        echo ""
        read -p "Выберите пункт: " choice
        
        case $choice in
            1) setup_full_isp ;;
            2) setup_basic_routers ;;
            3) setup_dhcp_client ;;
            4) setup_resolv_conf ;;
            5) setup_vlan ;;
            6) setup_secure_ssh ;;
            7) setup_dhcp_server_commands ;;
            8) setup_dns_server ;;
            9) setup_timezone ;;
            10) setup_local_users ;;
            11) setup_nat_forwarding ;;
            12) setup_dhcp_server ;;
            13) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

setup_full_isp() {
    echo -e "${BLUE}=== Настройка ISP ===${NC}"
    echo ""

    echo -e "${YELLOW}[1/5] Назначение хостнейма...${NC}"
    hostnamectl set-hostname isp
    sed -i "s/^HOSTNAME=.*/HOSTNAME=isp/" /etc/sysconfig/network
    echo -e "${GREEN}✓ Имя хоста: isp${NC}"

    read -p "Нажмите Enter для продолжения..."
    echo "IP-адреса ВТОРОЙ ПОДГРУППЫ: 172.16.70.0/28 к HQ-RTR;; 172.16.80.0/28 к BR-RTR"
    echo -e -n "${CYAN}Введите IP-адрес, смотрящий в сторону HQ-RTR (пример, 172.16.1.1/28):${NC} "
    read IP_ADDR_HQ_RTR
    echo -e -n "${CYAN}Введите IP-адрес, смотрящий в сторону BR-RTR (пример, 172.16.2.1/28):${NC} "
    read IP_ADDR_BR_RTR

    echo -e "${YELLOW}[2/5] Автоматическая настройка адаптеров сети...${NC}"
    echo -e "${CYAN}Определяем интерфейсы внутри машины по порядку...${NC}"

    # Определение интерфейсов
    echo -e "${CYAN}Найденные интерфейсы системой:${NC}"

    ip -c --br a
    
    echo -e -n "${CYAN}Укажите необходимые интерфесы для конфигурирования через пробел. (например, ens19 ens20):${NC}" 
    read INTERFACES

    for interface in $INTERFACES; do
        echo -e "${YELLOW}[3/5] Настройка интерфейса $interface...${NC}"
        mkdir -p /etc/net/ifaces/$interface
        touch /etc/net/ifaces/$interface/options

        echo "TYPE=eth" > /etc/net/ifaces/$interface/options
        echo "BOOTPROTO=static" >> /etc/net/ifaces/$interface/options
        echo "CONFIG_IPV4=yes" >> /etc/net/ifaces/$interface/options
        echo "CONFIG_IPV6=no" >> /etc/net/ifaces/$interface/options
        echo "DISABLED=no" >> /etc/net/ifaces/$interface/options
        echo "NM_CONTROLLED=no" >> /etc/net/ifaces/$interface/options
        echo "SYSTEMD_CONTROLLED=no" >> /etc/net/ifaces/$interface/options

        read -p "Выберите какой IP-адрес назначить на интерфейс $interface (1 - HQ-RTR, 2 - BR-RTR): " choice
        if [[ $choice == "1" ]]; then
            echo "$IP_ADDR_HQ_RTR" > /etc/net/ifaces/$interface/ipv4address
        elif [[ $choice == "2" ]]; then
            echo "$IP_ADDR_BR_RTR" > /etc/net/ifaces/$interface/ipv4address
        fi
    done

    echo -e "${GREEN}✓ IP-адресация настроена!${NC}"
    echo -e "${YELLOW} [4/5] Замена sysctl - параметр ${CYAN}net.ipv4.ip_forward${NC}"

    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
    echo -e "${CYAN}Перезагрузка основного сервиса сети...${NC}"
    systemctl restart network

    echo -e "${GREEN}✓ sysctl изменен!${NC}"
    echo -e "${YELLOW}[5/5] Установка и настройка iptables${NC}"

    echo -e ""
    # Установка iptables
    apt-get install -y iptables
    
    # Очистка старых правил
    iptables -t nat -F
    iptables -F
    
    echo -e -n "${CYAN}Укажите сети в сторону роутеров HQ и BR в соответствии с адресацией указанные выше через пробел (пример, 172.16.1.0/28 172.16.2.0/28):${NC} "
    read INTERNAL_NETS

    ip -c --br -4 a
    echo -e -n "${CYAN}Укажите ОСНОВНОЙ ИНТЕРФЕЙС, который показывает на WAN (Интернет) ${NC} "
    read EXT_IF

    # Добавление правил MASQUERADE
    for net in $INTERNAL_NETS; do
        iptables -t nat -A POSTROUTING -s $net -o $EXT_IF -j MASQUERADE
        echo -e "${GREEN}✓ Добавлен NAT для сети $net${NC}"
    done
   
    # Сохранение
    mkdir -p /etc/sysconfig
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables 2>/dev/null
    
    echo -e "${GREEN}✓ Первоначальные настройки ISP выполнены, можно приступать к дальнейшему выполнению!${NC}"
    read -p "Нажми Enter..." 
} 

setup_basic_routers() {
    clear

    echo -e "${BLUE}=== Настройки роутеров HQ-RTR и BR-RTR === ${NC}"
    echo ""

    read -p "Введите первый VLAN ID для HQ-RTR в сторону HQ-SRV (пример, 100): " HQ_VLAN_1
    read -p "Введите второй VLAN ID для HQ-RTR в сторону HQ-CLI (пример, 200): " HQ_VLAN_2
    read -p "Введите третий VLAN ID для HQ (управление) (пример, 99): " HQ_VLAN_3

    read -p "Введите первый IP-адрес подсети вместе с маской (пример, 192.168.100.1/27) для HQ-RTR в сторону HQ-SRV: " HQ_IP_RTR_1
    read -p "Введите первый IP-адрес подсети вместе с маской (пример, 192.168.200.1/24) для HQ-RTR в сторону HQ-CLI: " HQ_IP_RTR_2
    read -p "Введите первый IP-адрес подсети вместе с маской (пример, 192.168.99.1/29) для HQ (управление): " HQ_IP_RTR_3

    HQ_NET_1="${HQ_IP_RTR_1/\.[0-9]*\//.0/}"
    HQ_NET_2="${HQ_IP_RTR_2/\.[0-9]*\//.0/}"
    HQ_NET_3="${HQ_IP_RTR_3/\.[0-9]*\//.0/}"

    read -p "Введите первый IP-адрес подсети BR-Net (пример, 192.168.0.1/28): " BR_IP_NET_1
    BR_NET_1="${BR_IP_NET_1/\.[0-9]*\//.0/}"

    echo -e "${YELLOW}Напоминалка сети для HQ-RTR в сторону ISP: 172.16.70.0/28"
    echo -e "${YELLOW}Напоминалка сети для BR-RTR в сторону ISP: 172.16.80.0/28"

    read -p "Вбейте второй IP-адрес подсети вместе с маской (пример, 172.16.70.2/28) для HQ-RTR в сторону ISP: " ISP_IP_RTR_1
    read -p "Вбейте второй IP-адрес подсети вместе с маской (пример, 172.16.80.2/28) для BR-RTR в сторону ISP: " ISP_IP_RTR_2

    read -p "Вбейте адрес ISP от 172.16.70.0/28 (пример, 172.16.70.1): " ISP_IP_1
    read -p "Вбейте адрес ISP от 172.16.80.0/28 (пример, 172.16.80.1): " ISP_IP_2

    echo -e "${YELLOW}Все выполняемые команды необходимо ввести вручную (либо Ctrl+C и Ctrl+V если xterm.js терминал)!${NC}"
    read -p "Нажми Enter, если готов размять пальцы..."

    echo ""
    echo -e "${CYAN}============ HQ-RTR ============${NC}"
    echo ""

    echo "ecorouter>enable"
    echo "ecorouter#configure terminal"
    echo "ecorouter(config)#hostname hq-rtr"
    echo "hq-rtr(config)#ip domain-name au-team.irpo (ИЛИ СВОЙ ДОМЕН НА ВЫБОР КОМИССИИ)"
    echo "hq-rtr(config)#write memory"

    echo -e "${YELLOW}ПРОВЕРКА: show hostname и/или show running-config | include domain-name${NC}"

    echo "hq-rtr(config)#interface vl${HQ_VLAN_1}"
    echo "hq-rtr(config-if)#description VLAN${HQ_VLAN_1}"
    echo "hq-rtr(config-if)#ip address ${HQ_IP_RTR_1}"
    echo "hq-rtr(config-if)#exit"

    echo "hq-rtr(config)#interface vl${HQ_VLAN_2}"
    echo "hq-rtr(config-if)#description VLAN${HQ_VLAN_2}"
    echo "hq-rtr(config-if)#ip address ${HQ_IP_RTR_2}"
    echo "hq-rtr(config-if)#exit"

    echo "hq-rtr(config)#interface vl${HQ_VLAN_3}"
    echo "hq-rtr(config-if)#description VLAN${HQ_VLAN_3}"
    echo "hq-rtr(config-if)#ip address ${HQ_IP_RTR_3}"
    echo "hq-rtr(config-if)#exit"

    echo "hq-rtr(config)#write memory"

    echo "hq-rtr(config)#interface isp"
    echo "hq-rtr(config-if)#desciption ISP"
    echo "hq-rtr(config-if)#ip address ${ISP_IP_RTR_1}"
    echo "hq-rtr(config-if)#exit"

    echo "hq-rtr(config)#ip route 0.0.0.0/0 ${ISP_IP_1}"
    echo "hq-rtr(config)#port te0"
    echo "hq-rtr(config)#service-instance te0/isp"
    echo "hq-rtr(config-service-instance)#encapsulation untagged"
    echo "hq-rtr(config-service-instance)#connect ip interface isp"
    echo "hq-rtr(config-service-instance)#exit"
    echo "hq-rtr(config)#write memory"

    echo -e "${CYAN}Создаем сервисные инстансы в сторону каждого созданного VLAN-интерфейса...${NC}"
    echo -e "hq-rtr(config)#port te1"
    echo -e "hq-rtr(config-port)#service-instance te1/vl${HQ_VLAN_1}"
    echo -e "hq-rtr(config-service-instance)#encapsulation dot1q ${HQ_VLAN_1} exact"
    echo -e "hq-rtr(config-service-instance)#rewrite pop 1"
    echo -e "hq-rtr(config-service-instance)#connect ip interface vl${HQ_VLAN_1}"
    echo -e "hq-rtr(config-service-instance)#exit"

    echo -e "hq-rtr(config-port)#service-instance te1/vl${HQ_VLAN_2}"
    echo -e "hq-rtr(config-service-instance)#encapsulation dot1q ${HQ_VLAN_2} exact"
    echo -e "hq-rtr(config-service-instance)#rewrite pop 1"
    echo -e "hq-rtr(config-service-instance)#connect ip interface vl${HQ_VLAN_2}"
    echo -e "hq-rtr(config-service-instance)#exit"

    echo -e "hq-rtr(config-port)#service-instance te1/vl${HQ_VLAN_3}"
    echo -e "hq-rtr(config-service-instance)#encapsulation dot1q ${HQ_VLAN_3} exact"
    echo -e "hq-rtr(config-service-instance)#rewrite pop 1"
    echo -e "hq-rtr(config-service-instance)#connect ip interface vl${HQ_VLAN_3}"
    echo -e "hq-rtr(config-service-instance)#exit"

    echo -e "hq-rtr(config-port)#exit"
    echo -e "hq-rtr(config)#write memory"

    echo "hq-rtr(config)#username net_admin"
    echo "hq-rtr(config-user)#password P@ssw0rd"
    echo "hq-rtr(config-user)#role admin"
    echo "hq-rtr(config-user)#exit"
    echo "hq-rtr(config)#write memory"

    echo "hq-rtr(config)#interface tunnel.0"
    echo "hq-rtr(config-if-tunnel)#description GRE"
    echo "hq-rtr(config-if-tunnel)#ip address 10.10.10.1/30"
    echo "hq-rtr(config-if-tunnel)#ip tunnel ${ISP_IP_RTR_1} ${ISP_IP_RTR_2} mode gre"
    echo "hq-rtr(config-if-tunnel)#exit"
    echo "hq-rtr(config)#write memory"

    echo "hq-rtr(config)#router ospf 1"
    echo "hq-rtr(config-router)#ospf router-id 10.10.10.1"
    echo "hq-rtr(config-router)#passive-interface default"
    echo "hq-rtr(config-router)#no passive-interface tunnel.0"
    echo "hq-rtr(config-router)#network 10.10.10.0/30 area 0"
    echo "hq-rtr(config-router)#network ${HQ_NET_1} area 0"
    echo "hq-rtr(config-router)#network ${HQ_NET_2} area 0"
    echo "hq-rtr(config-router)#network ${HQ_NET_3} area 0"
    echo "hq-rtr(config-router)#exit"
    echo "hq-rtr(config)#interface tunnel.0"
    echo "hq-rtr(config-if-tunnel)#ip ospf authentication message-digest"
    echo "hq-rtr(config-if-tunnel)#ip ospf message-digest-key 1 md5 P@ssw0rd"
    echo "hq-rtr(config-if-tunnel)#exit"
    echo "hq-rtr(config)#write memory"

    echo "hq-rtr(config)#interface isp"
    echo "hq-rtr(config-if)#ip nat outside"
    echo "hq-rtr(config-if)#exit"
    echo "hq-rtr(config)#interface vl${HQ_VLAN_1}"
    echo "hq-rtr(config-if)#ip nat inside"
    echo "hq-rtr(config-if)#exit"
    echo "hq-rtr(config)#interface vl${HQ_VLAN_2}"
    echo "hq-rtr(config-if)#ip nat inside"
    echo "hq-rtr(config-if)#exit"
    echo "hq-rtr(config)#interface vl${HQ_VLAN_3}"
    echo "hq-rtr(config-if)#ip nat inside"
    echo "hq-rtr(config-if)#exit"

    read -p "Введите пул адресов для VLAN${HQ_VLAN_1}: (пример, 192.168.100.1-192.168.100.30) " HQ_POOL_1
    read -p "Введите пул адресов для VLAN${HQ_VLAN_2}: (пример, 192.168.200.1-192.168.200.254) " HQ_POOL_2
    read -p "Введите пул адресов для VLAN${HQ_VLAN_3}: (пример, 192.168.99.1-192.168.99.6)" HQ_POOL_3

    echo "hq-rtr(config)#ip nat pool VLAN${HQ_VLAN_1} ${HQ_POOL_1}"
    echo "hq-rtr(config)#ip nat pool VLAN${HQ_VLAN_2} ${HQ_POOL_2}"
    echo "hq-rtr(config)#ip nat pool VLAN${HQ_VLAN_3} ${HQ_POOL_3}"
    
    echo "hq-rtr(config)#ip nat source dynamic inside-to-outside pool VLAN${HQ_VLAN_1} overload interface isp"
    echo "hq-rtr(config)#ip nat source dynamic inside-to-outside pool VLAN${HQ_VLAN_2} overload interface isp"
    echo "hq-rtr(config)#ip nat source dynamic inside-to-outside pool VLAN${HQ_VLAN_3} overload interface isp"
    echo "hq-rtr(config)#exit"
    echo "hq-rtr(config)#write memory"

    echo "---- КОНФИГУР DHCP:"
    echo "hq-rtr(config)#ip pool VLAN${HQ_VLAN_2} ${HQ_POOL_2}"
    echo "hq-rtr(config)#dhcp-server 1"
    echo "hq-rtr(config-dhcp-server)#pool VLAN${HQ_VLAN_2} 1"
    echo "hq-rtr(config-dhcp-server-pool)#mask 24"
    echo "hq-rtr(config-dhcp-server-pool)#gateway $HQ_IP_RTR_2"
    echo "hq-rtr(config-dhcp-server-pool)#dns 192.168.100.2 (ну там другой ип)"
    echo "hq-rtr(config-dhcp-server-pool)#domain-name au-team.irpo" 
    echo "hq-rtr(config-dhcp-server-pool)#exit"
    echo "hq-rtr(config-dhcp-server)#exit"

    echo "hq-rtr(config)#interface vl${HQ_VLAN_2}"
    echo "hq-rtr(config-if)#dhcp-server 1"
    echo "hq-rtr(config-if)#exit"

    echo "hq-rtr(config)#write memory"

    echo ""
    echo -e "${CYAN}============ HQ-RTR ============${NC}"

    read -p "Нажми Enter, чтобы перейти к BR-RTR..."

    echo ""
    echo -e "${CYAN}============ BR-RTR ============${NC}"
    echo ""

    echo "ecorouter>enable"
    echo "ecorouter#conf t"
    echo "ecorouter(config)#hostname br-rtr"
    echo "br-rtr(config)#ip domain-name au-team.irpo (ИЛИ СВОЙ ДОМЕН НА ВЫБОР КОМИССИИ)"
    echo "br-rtr(config)#write memory"

    echo -e "${YELLOW}ПРОВЕРКА: show hostname и/или show running-config | include domain-name${NC}"

    echo "br-rtr(config)#interface int1 (или любой произвольный)"
    echo "br-rtr(config-if)#description BR-Net (или любой произвольный)"
    echo "br-rtr(config-if)#ip address ${BR_IP_RTR_1}"
    echo "br-rtr(config-if)#exit"

    echo -e "${CYAN}Создаем сервисный инстанс в сторону созданного интерфейса...${NC}"
    echo -e "br-rtr(config)#port te1"
    echo -e "br-rtr(config-port)#service-instance te1/int1"
    echo -e "br-rtr(config-service-instance)#encapsulation untagged"
    echo -e "br-rtr(config-service-instance)#connect ip interface int1"
    echo -e "br-rtr(config-service-instance)#exit"
    echo -e "br-rtr(config-port)#exit"
    echo -e "br-rtr(config)#write memory"

    echo "br-rtr(config)#interface isp"
    echo "br-rtr(config-if)#desciption ISP"
    echo "br-rtr(config-if)#ip address ${ISP_IP_RTR_2}"
    echo "br-rtr(config-if)#exit"

    echo "br-rtr(config)#ip route 0.0.0.0/0 ${ISP_IP_2}"
    echo "br-rtr(config)#port te0"
    echo "br-rtr(config)#service-instance te0/isp"
    echo "br-rtr(config-service-instance)#encapsulation untagged"
    echo "br-rtr(config-service-instance)#connect ip interface isp"
    echo "br-rtr(config-service-instance)#exit"
    echo "br-rtr(config)#write memory"

    echo "br-rtr(config)#username net_admin"
    echo "br-rtr(config-user)#password P@ssw0rd"
    echo "br-rtr(config-user)#role admin"
    echo "br-rtr(config-user)#exit"
    echo "br-rtr(config)#write memory"

    echo "br-rtr(config)#interface tunnel.0"
    echo "br-rtr(config-if-tunnel)#description GRE"
    echo "br-rtr(config-if-tunnel)#ip address 10.10.10.2/30"
    echo "br-rtr(config-if-tunnel)#ip tunnel ${ISP_IP_RTR_2} ${ISP_IP_RTR_1} mode gre"
    echo "br-rtr(config-if-tunnel)#exit"
    echo "br-rtr(config)#write memory"    

    echo "br-rtr(config)#router ospf 1"
    echo "br-rtr(config-router)#ospf router-id 10.10.10.2"
    echo "br-rtr(config-router)#passive-interface default"
    echo "br-rtr(config-router)#no passive-interface tunnel.0"
    echo "br-rtr(config-router)#network ${BR_NET_1} area 0"
    echo "br-rtr(config-router)#network 10.10.10.0/30 area 0"
    echo "br-rtr(config-router)#exit"
    echo "br-rtr(config)#interface tunnel.0"
    echo "br-rtr(config-if-tunnel)#ip ospf authentication message-digest"
    echo "br-rtr(config-if-tunnel)#ip ospf message-digest-key 1 md5 P@ssw0rd"
    echo "br-rtr(config-if-tunnel)#exit"
    echo "br-rtr(config)#write memory"

    echo "br-rtr(config)#interface isp"
    echo "br-rtr(config-if)#ip nat outside"
    echo "br-rtr(config-if)#exit"

    echo "br-rtr(config)#interface int1"
    echo "br-rtr(config-if)#ip nat inside"
    echo "br-rtr(config-if)#exit"

    read -p "Введите пул адресов для BR-Net: (пример, 192.168.0.1-192.168.0.14)" BR_POOL_1

    echo "br-rtr(config)#ip nat pool br-net ${BR_POOL_1}"
    echo "br-rtr(config)#ip nat source dynamic inside-to-outside pool br-net overload interface isp"
    echo "br-rtr(config)#exit"

    echo "br-rtr(config)#write memory"

    echo ""
    echo -e "${CYAN}============ BR-RTR ============${NC}"

    echo ""
    echo -e "${GREEN}✓ Роутеры настроены${NC}"
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

    echo -e "${BLUE}Пример обратной зоны: 100.168.192.in-addr.arpa. (ВБИТЬ ТОЛЬКО НАЧАЛО, IP-адрес)${NC}"
    read -p "Введите обратный IP-адрес первой зоны, если она есть (если нет Enter): " ZONE1_IP
    read -p "Введите обратный IP-адрес второй зоны, если она есть (если нет Enter): " ZONE2_IP
    
    apt-get update
    apt-get install -y bind bind-utils
    
    # Настройка options.conf
    cat > /var/lib/bind/etc/options.conf <<EOF
options {
    version "unknown";
    directory "/etc/bind/zone";
    dump-file "/var/run/named/named_dump.db";
    statistics-file "/var/run/named/named.stats";
    recursing-file "/var/run/named/named.recursing";
    secroots-file "/var/run/named/named.secroots";

    pid-file none;

    listen-on { any; };
    listen-on-v6 { none; };
    forwarders { 77.88.8.8; };

    allow-query { any; };
};

EOF
    
    # Добавление зоны
    cat >> /var/lib/bind/etc/rfc1912.conf <<EOF
zone "$ZONE" {
    type master;
    file "$ZONE";
};

zone "$ZONE1_IP.in-addr.arpa" {
    type master;
    file "$ZONE1_IP.in-addr.arpa";
};

zone "$ZONE2_IP.in-addr.arpa" {
    type master;
    file "$ZONE2_IP.in-addr.arpa";
};
EOF

    cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/$ZONE
    cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/$ZONE1_IP.in-addr.arpa
    cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/$ZONE2_IP.in-addr.arpa

    ZONE_FILE="/var/lib/bind/etc/zone/$ZONE"
    cat > "$ZONE_FILE" << EOF
    \$TTL 86400
    @   IN  SOA ${HOSTNAME}. root.${DOMAIN}. (
            $(date +%Y%m%d00) ; serial
            3600       ; refresh
            900        ; retry
            604800     ; expire
            86400 )    ; minimum
    @   IN  NS  ${HOSTNAME}.
    @   IN  A   $DNS_IP
EOF

    echo "--------------------------------------------------------"
    echo -e "${BLUE}Теперь введите хосты (A-записи). Для завершения введите 'exit'${NC}"
    echo -e "${BLUE}Пример ввода: hq-srv 192.168.100.2 ...${NC}"
    echo "--------------------------------------------------------"    

    while true; do
        read -p "Хост и IP (через пробел): " HOST IP
        
        # Если пользователь ввел exit, останавливаем цикл
        if [ "$HOST" = "exit" ] || [ -z "$HOST" ]; then
            break
        fi
        
        # Если IP не введен, просим повторить
        if [ -z "$IP" ]; then
            echo -e "${RED}Ошибка: Вы не ввели IP для хоста $HOST. Попробуйте еще раз.${NC}"
            continue
        fi
        
        # Дописываем строку в файл зоны с форматированием (табуляцией)
        printf "%-7s IN      A       %s\n" "$HOST" "$IP" >> "$ZONE_FILE"
    done

    echo "---"
    echo -e "${GREEN}Готово! Файл зоны успешно создан и заполнен: $ZONE_FILE ...${NC}"
    echo -e "${BLUE}Вот его содержимое:${NC}"
    cat "$ZONE_FILE"

    echo -e "${BLUE}Создание обратной зоны для $ZONE1_IP.in-addr.arpa...${NC}"

    ZONE1_FILE="/var/lib/bind/etc/zone/$ZONE1_IP.in-addr.arpa"
    ZONE1_IP_FULL="$ZONE1_IP.in-addr.arpa"
    SERIAL1=$(date +%Y%m%d00)

    echo -e "${BLUE}Настраиваем SOA и NS записи...${NC}"
    sed -i "s/localhost\./${ZONE}./g" "$ZONE1_FILE"
    sed -i "s/root\.${ZONE}\./root.${ZONE}./g" "$ZONE1_FILE" # На всякий случай корректируем root
    sed -i "s/2025110500/${SERIAL1}/" "$ZONE1_FILE"

    echo "--------------------------------------------------------"
    echo -e "${BLUE}Теперь введите PTR-записи. Для завершения введите 'exit'${NC}"
    echo -e "${CYAN}Пример ввода:${NC}"
    echo -e "${CYAN}Последний октет IP: 1${NC}"
    echo -e "${CYAN}Хостнейм: hq-rtr${NC}"
    echo "--------------------------------------------------------"

    while true; do
        # 1. Запрашиваем последний октет IP-адреса (например, 1 или 2 из твоего скриншота)
        read -p "Последний октет IP (цифра): " IP_OCTET
        
        # Если ввели exit или ничего, выходим
        if [ "$IP_OCTET" = "exit" ] || [ -z "$IP_OCTET" ]; then
            break
        fi
        
        # 2. Запрашиваем только имя хоста (например, hq-srv)
        read -p "Хостнейм (без домена): " HOST_NAME
        
        if [ -z "$HOST_NAME" ]; then
            echo -e "${RED}Ошибка: имя хоста не может быть пустым.${NC}"
            continue
        fi
        
        # Формируем полную FQDN запись с точкой на конце, используя доменную зону из начала скрипта
        # Переменная $ZONE_NAME должна быть объявлена ранее (например, au-team.irpo)
        FULL_FQDN="${HOST_NAME}.${ZONE}."
        
        # Дописываем строку в файл обратной зоны с красивым выравниванием
        printf "%-8s IN      PTR     %s\n" "$IP_OCTET" "$FULL_FQDN" >> "$ZONE1_FILE"
        
        echo -e  "${GREEN}Запись добавлена: $IP_OCTET IN PTR $FULL_FQDN ...${NC}"
        echo "---"
    done

    echo -e "${BLUE}Создание обратной зоны для $ZONE2_IP.in-addr.arpa...${NC}"

    ZONE2_FILE="/var/lib/bind/etc/zone/$ZONE2_IP.in-addr.arpa"
    ZONE2_IP_FULL="$ZONE2_IP.in-addr.arpa"
    SERIAL2=$(date +%Y%m%d00)

    echo -e "${BLUE}Настраиваем SOA и NS записи...${NC}"
    sed -i "s/localhost\./${ZONE}./g" "$ZONE2_FILE"
    sed -i "s/root\.${ZONE}\./root.${ZONE}./g" "$ZONE2_FILE" # На всякий случай корректируем root
    sed -i "s/2025110500/${SERIAL2}/" "$ZONE2_FILE"

    echo "--------------------------------------------------------"
    echo -e "${CYAN}Теперь введите PTR-записи. Для завершения введите 'exit'${NC}"
    echo -e "${CYAN}Пример ввода:${NC}"
    echo -e "${CYAN}Последний октет IP: 1 ...${NC}"
    echo -e "${CYAN}Хостнейм: hq-rtr${NC}"
    echo "--------------------------------------------------------"

    while true; do
        # 1. Запрашиваем последний октет IP-адреса (например, 1 или 2 из твоего скриншота)
        read -p "Последний октет IP (цифра): " IP_OCTET
        
        # Если ввели exit или ничего, выходим
        if [ "$IP_OCTET" = "exit" ] || [ -z "$IP_OCTET" ]; then
            break
        fi
        
        # 2. Запрашиваем только имя хоста (например, hq-srv)
        read -p "Хостнейм (без домена): " HOST_NAME
        
        if [ -z "$HOST_NAME" ]; then
            echo -e "${RED}Ошибка: имя хоста не может быть пустым.${NC}"
            continue
        fi
        
        # Формируем полную FQDN запись с точкой на конце, используя доменную зону из начала скрипта
        # Переменная $ZONE_NAME должна быть объявлена ранее (например, au-team.irpo)
        FULL_FQDN="${HOST_NAME}.${ZONE}."
        
        # Дописываем строку в файл обратной зоны с красивым выравниванием
        printf "%-8s IN      PTR     %s\n" "$IP_OCTET" "$FULL_FQDN" >> "$ZONE2_FILE"
        
        echo -e "${GREEN}Запись добавлена: $IP_OCTET IN PTR $FULL_FQDN ...${NC}"
        echo "---"
    done

    rndc-confgen > /var/lib/bind/etc/rndc.key
    sed -i '6,$d' /var/lib/bind/etc/rndc.key
    chown -R root:named /etc/bind/zone/*

    systemctl enable --now bind.service
    if systemctl status bind.service --no-pager | grep -q "active (running)"; then
        echo -e "${GREEN}✓ DNS-сервер настроен${NC}"
        read -p "Нажми Enter..."
    else
        echo -e "${RED}✗ DNS-сервер не настроен${NC}"
        read -p "Нажми Enter..."
    fi    
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
    

    echo -e -n "${CYAN}Введите имя пользователя:${NC} "
    read USERNAME
    echo -e -n "${CYAN}Введите UID для пользователя: ${NC} "
    read USER_UID
    echo -e -n "${CYAN}Введите пароль для пользователя: ${NC}"
    read USER_PASS
    echo -e -n "${CYAN}Подтвердите пароль: ${NC}"
    read USER_PASS_CONFIRM
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

setup_dhcp_server() {
    clear
    echo -e "${BLUE}=== Настройка DHCP сервера ===${NC}"
    echo ""
    
    echo "На HQ-RTR:"
    echo "conf t"
    read -p "Введите номер VLAN и пул адресов (например, 100 192.168.100.100-192.168.100.200): " VLAN_NUMBER VLAN_POOL
    echo "ip pool VLAN$VLAN_NUMBER $VLAN_POOL"
    echo "dhcp-server 1"
    echo "pool VLAN200 1"
    echo "mask 24"
    echo "gateway [IP адрес шлюза / HQ-RTR]"
    echo "dns [IP адрес DNS-сервера / HQ-SRV]"
    echo "domain-name [DNS-суффикс / домен]"
    echo "exit и еще раз exit"
    echo "interface [ИНТЕРФЕЙС ПОД $VLAN_NUMBER]"
    echo "dhcp-server 1"
    echo "exit"
    echo "write memory"

    echo -e "${GREEN}✓ DHCP сервер настроен${NC}"
    echo "Не забудьте на клиенте включить DHCP (HQ-CLI)"
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
        echo "1) Настройка Samba Domain Controller (BR-SRV)"
        echo "2) Настройка RAID 0 (HQ-SRV)"
        echo "3) Настройка NFS сервера (HQ-SRV)"
        echo "4) Настройка NFS клиента (HQ-CLI)"
        echo "5) Настройка NTP сервера (chrony) (ISP)"
        echo "6) Настройка NTP клиента (все тачки)"
        echo "7) Настройка Ansible (BR-SRV)"
        echo "8) Настройка Docker + testapp (BR-SRV)"
        echo "9) Настройка LAMP веб-приложения (HQ-SRV)"
        echo "10) Настройка Nginx reverse proxy (ISP)"
        echo "11) Web-based аутентификация (ISP)"
        echo "12) Настройка Яндекс Браузера (HQ-CLI)"
        echo "13) Вернуться в главное меню"
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
            11) setup_web_based ;;
            12) setup_yandex_browser ;;
            13) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

setup_samba_dc() {
    clear
    echo -e "${BLUE}=== Настройка Samba Domain Controller ===${NC}"
    echo ""
    
    read -p "Введите домен (например, AU-TEAM): " DOMAIN
    read -p "Введите также полное наименование домена в нижнем регистре (например, au-team.irpo): " DOMAIN_FULL
    read -p "Введите Realm (в верхнем регистре, например, AU-TEAM.IRPO): " REALM
    read -p "Введите пароль администратора домена: " ADMIN_PASS
    read -p "Введите DNS forwarder (например, 8.8.8.8): " FORWARDER
    read -p "Введите адаптер, смотрящий в сторону основной сети (например, ens19 или enp7s1): " EXT_IF
    
    apt-get update
    apt-get install -y task-samba-dc
    
    for service in smb nmb krb5kdc slapd bind; do
        systemctl disable $service --now 2>/dev/null
    done
    
    rm -f /etc/samba/smb.conf && rm -rf /var/lib/samba && rm -rf /var/cache/samba
    mkdir -p /var/lib/samba/sysvol
    
    # Неинтерактивная настройка
    samba-tool domain provision \
        --use-rfc2307 \
        --realm="$REALM" \
        --domain="$DOMAIN" \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL \
        --option="dns forwarder = $FORWARDER" \
        --adminpass="$ADMIN_PASS"
        
    systemctl enable --now samba

    cp /etc/krb5.conf /var/lib/samba/private/krb5.conf
    systemctl restart samba

    echo "search $DOMAIN_FULL" > /etc/net/ifaces/$EXT_IF/resolv.conf
    echo "nameserver 127.0.0.1" >> /etc/net/ifaces/$EXT_IF/resolv.conf
    systemctl restart network

    echo -e "${CYAN}Проверяем конфигурацию...${NC}"
    if samba-tool domain info 127.0.0.1 | grep -q "Domain"; then
        echo -e "${GREEN}✓ Конфигурация проверена${NC}"
    fi

    kinit administrator@$REALM

    samba-tool group add hq
    if samba-tool group list | grep -q "hq"; then
        echo -e "${GREEN}✓ Группа hq создана${NC}"
    fi

    for i in {1..5}; do
        samba-tool user add hquser$i P@ssw0rd;
        samba-tool user setexpiry hquser$i --noexpiry;
        samba-tool group addmembers "hq" hquser$i;
    done

    if samba-tool group list | grep -q "hq"; then
        echo -e "${GREEN}✓ Пользователи hquser1-hquser5 созданы и добавлены в группу hq${NC}"
    fi
    
    echo -e "${GREEN}✓ Samba DC настроен (домен: $DOMAIN)${NC}"
    echo ""
    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    echo "На клиенте не забудьте установить пакет авторизации: apt-get update && apt-get install -y task-auth-ad-sssd"
    echo ""
    echo "ПЕРЕД ЭТИМ БЛЯЯЯЯЯЯ, НАПИШИ В /etc/resolv.conf пж 192.168.0.2 (DNS-сервер BIND)"
    echo "потому что в рот я ебал ALT! ну и потом, ВОЙДИТЕ НАХУЙ В ДОМЕН"
    echo ""
    echo "Также, можно поставить управляющий: apt-get install -y libnss-role"
    echo "Необходимо добавить wheel к группе hq: roleadd hq wheel"

    echo "Отредактируйте файл /etc/sudoers, взяв строчку:"
    echo "Cmnd_Alias    SHELLCMD = /bin/cat, /bin/grep, /usr/bin/id"
    echo "Также сделайте строчку: WHEEL_USERS ALL=(ALL:ALL) SHELLCMD"

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

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
    
    echo "$SERVER_IP:$NFS_DIR $MOUNT_POINT nfs defaults 0 0" >> /etc/fstab
    mount -av
    
    echo -e "${GREEN}✓ NFS клиент настроен, смонтирован в $MOUNT_POINT${NC}"
    df -h | grep nfs
    read -p "Нажми Enter..."
}

setup_ntp_server() {
    clear
    echo -e "${BLUE}=== Настройка NTP сервера (chrony) ===${NC}"
    echo ""
    
    apt-get install -y chrony
    
    cat > /etc/chrony.conf <<EOF
server ntp1.vniiftri.ru iburst prefer minstratum 4
local stratum 5
allow 0.0.0.0/0

driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
EOF
    
    systemctl enable --now chronyd
    
    echo -e "${GREEN}✓ NTP сервер настроен (стратум 5)${NC}"
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
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
EOF
    
    systemctl enable --now chronyd
    
    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    echo ""

    echo "На HQ и BR RTRах прописать: ntp server [IP-адрес ISP]"

    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"
    
    echo ""
    
    echo -e "${GREEN}✓ NTP клиент настроен на сервер $NTP_SERVER${NC}"
    
    chronyc sources
    read -p "Нажми Enter..."
}

setup_ansible() {
    clear
    echo -e "${BLUE}=== Настройка Ansible ===${NC}"
    echo ""
    
    read -p "Введите пароль для подключения к хостам: " ANSIBLE_PASS
    
    apt-get update && apt-get install -y ansible sshpass python3-module-pip
    pip3 install ansible-pylibssh
    
    INVENTORY_FILE=/etc/ansible/hosts

    echo "=== Настройка инвентаря Ansible ==="
    read -p "IP для HQ-SRV [192.168.100.2]: " HQ_SRV_IP
    HQ_SRV_IP=${HQ_SRV_IP:-192.168.100.2}

    read -p "IP для HQ-RTR [10.10.10.1]: " HQ_RTR_IP
    HQ_RTR_IP=${HQ_RTR_IP:-10.10.10.1}

    read -p "IP для BR-RTR [192.168.0.1]: " BR_RTR_IP
    BR_RTR_IP=${BR_RTR_IP:-192.168.0.1}

    read -p "IP для HQ-CLI [192.168.200.2]: " HQ_CLI_IP
    HQ_CLI_IP=${HQ_CLI_IP:-192.168.200.2}

    # Запрашиваем общие пароли
    read -p "Основной пароль (для Servers/Routers) [P@ssw0rd]: " MAIN_PASS
    MAIN_PASS=${MAIN_PASS:-P@ssw0rd}

    read -p "Порт SSH для серверов [2026]: " SRV_PORT
    SRV_PORT=${SRV_PORT:-2026}

    mkdir -p /etc/ansible
    cat << EOF > "$INVENTORY_FILE"
    [Servers]
    HQ-SRV ansible_host=${HQ_SRV_IP}

    [Routers]
    HQ-RTR ansible_host=${HQ_RTR_IP}
    BR-RTR ansible_host=${BR_RTR_IP}

    [Clients]
    HQ-CLI ansible_host=${HQ_CLI_IP}

    [Servers:vars]
    ansible_user=sshuser
    ansible_password=${MAIN_PASS}
    ansible_port=${SRV_PORT}

    [Routers:vars]
    ansible_user=net_admin
    ansible_password=${MAIN_PASS}
    ansible_connection=network_cli
    ansible_network_os=ios

    [Clients:vars]
    ansible_user=user
    ansible_password=resu

    [all:vars]
    ansible_python_interpreter=/usr/bin/python3
EOF

    echo "---"
    echo -e "${GREEN}Файл инвентаря успешно сгенерирован: $INVENTORY_FILE ...${NC}"
    read -p "Нажми Enter..."

    CONFIG_FILE="/etc/ansible/ansible.cfg"

    # --- 1. Настройка параметра INVENTORY ---
    if grep -q "^inventory" "$CONFIG_FILE"; then
        # Строка есть и активна — жестко правим значение
        sed -i "s|^inventory\s*=.*|inventory = /etc/ansible/hosts|" "$CONFIG_FILE"
    elif grep -q "^#\s*inventory" "$CONFIG_FILE"; then
        # Строка есть, но закомментирована — раскомментируем и правим
        sed -i "s|^#\s*inventory\s*=.*|inventory = /etc/ansible/hosts|" "$CONFIG_FILE"
    else
        # Строки вообще нет — вставляем строго под [defaults]
        sed -i "/^\[defaults\]/a inventory = /etc/ansible/hosts" "$CONFIG_FILE"
    fi

    # --- 2. Настройка параметра HOST_KEY_CHECKING ---
    if grep -q "^host_key_checking" "$CONFIG_FILE"; then
        # Строка есть и активна — жестко правим значение
        sed -i "s|^host_key_checking\s*=.*|host_key_checking = False|" "$CONFIG_FILE"
    elif grep -q "^#\s*host_key_checking" "$CONFIG_FILE"; then
        # Строка есть, но закомментирована — раскомментируем и правим
        sed -i "s|^#\s*host_key_checking\s*=.*|host_key_checking = False|" "$CONFIG_FILE"
    else
        # Строки вообще нет — вставляем строго под [defaults]
        sed -i "/^\[defaults\]/a host_key_checking = False" "$CONFIG_FILE"
    fi    

    echo -e "${GREEN}Конфигурация Ansible настроена${NC}"

    ansible-galaxy collection install ansible.netcommon
    ansible-galaxy collection install cisco.ios

    echo -e "${GREEN}Пакеты для управления EcoRouter (BR и HQ RTRы) установлены${NC}"

    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    echo -e "Не забудьте на HQ-RTR и BR-RTR зайти в ${CYAN}conf t${NC} и ввести ${CYAN}security none${NC}"

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"
}


setup_docker() {
    clear
    echo -e "${BLUE}=== Настройка Docker + testapp ===${NC}"
    echo ""
    
    apt-get install -y docker-engine docker-compose-v2
    systemctl enable --now docker.service

    mount /dev/sr0 /mnt/ 2>/dev/null
    
    docker load < /mnt/docker/site_latest.tar
    docker load < /mnt/docker/mariadb_latest.tar

    if docker image ls | grep "mariadb"; then
        echo -e "${GREEN}✓ Образ MariaDB загружен${NC}"
    fi

    if docker image ls | grep "site"; then
        echo -e "${GREEN}✓ Образ testapp загружен${NC}"
    fi
    
    read -p "Введите IP-адрес хоста, где находится база данных (local-touch): " DB_HOST

    cat > docker-compose.yaml <<EOF
services:
  db:
    image: mariadb:10.11
    container_name: db
    restart: always
    environment:
      MARIADB_ROOT_PASSWORD: "toor"
      MARIADB_DATABASE: "testdb"
      MARIADB_USER: "testc"
      MARIADB_PASSWORD: "P@ssw0rd"
    ports:
      - "3306:3306"

  testapp:
    image: site:latest
    container_name: testapp
    restart: always
    ports:
      - "8080:8000"
    environment:
      DB_HOST: "$DB_HOST"
      DB_PORT: "3306"
      DB_TYPE: "maria"
      DB_NAME: "testdb"
      DB_USER: "testc"
      DB_PASS: "P@ssw0rd"
    depends_on:
      - db
EOF
    
    docker compose up -d
    
    echo -e "${GREEN}✓ Docker контейнеры запущены на порту 8080${NC}"
    docker ps
    read -p "Нажми Enter..."
}

setup_lamp() {
    clear
    echo -e "${BLUE}=== Настройка LAMP веб-приложения ===${NC}"
    echo ""
    
    apt-get install -y lamp-server

    mount /dev/sr0 /mnt/ 2>/dev/null

    cp /mnt/web/index.php /var/www/html
    cp /mnt/web/logo.png /var/www/html

    echo "=== Настройка подключения к БД (PHP) ==="

    # 1. Запрашиваем данные у пользователя
    read -p "Имя пользователя БД [webc]: " DB_USER
    DB_USER=${DB_USER:-webc}

    read -p "Пароль БД [P@ssw0rd]: " DB_PASS
    DB_PASS=${DB_PASS:-P@ssw0rd}

    read -p "Имя базы данных [webdb]: " DB_NAME
    DB_NAME=${DB_NAME:-webdb}
    
    PHP_FILE="/var/www/html/index.php"

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"
    
    echo ""
    
    echo "ДОБАВИТЬ В ФАЙЛ /var/www/html/index.php СЛЕДУЮЩИЕ СТРОКИ"
    
    echo ""
    
    echo "$dbname="webdb"; $password="P@ssw0rd"; $username = "webc";"
    
    echo ""
    
    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"
    
    systemctl enable --now mariadb

    sleep 5

    # 1. Засылаем пачку команд под рутом
    mariadb -u root <<EOF
    CREATE DATABASE webdb;
    CREATE USER 'webc'@'localhost' IDENTIFIED BY 'P@ssw0rd';
    GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
EOF

    sleep 5

    # 2. Заливаем дамп
    mariadb -u webc -p'P@ssw0rd' -D webdb < /mnt/web/dump.sql    
    
    echo -e "${GREEN}✓ LAMP веб-приложение настроено${NC}"
    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    echo ""

    echo "ТАКЖЕ! Нужно настроить на HQ-RTR и BR-RTR трансляцию портов:"
    
    echo "ip nat source static tcp <IP-АДРЕС_УСТРОЙСТВА_ЛОКАЛЬНОЙ_СЕТИ> <ПОРТ_УСТРОЙСТВА_ЛОКАЛЬНОЙ_СЕТИ> <ВНЕШНИЙ_IP-АДРЕС_УСТРОЙСТВА> <ПОРТ_ДЛЯ_ОБРАЩЕНИЯ_ИЗ_ВНЕШНЕЙ_СЕТИ>"
    
    echo "Прокидывается IP-адрес HQ-SRV с портом 80 на порт 8080 у HQ-RTR:"
    
    echo "ip nat source static tcp [IP-АДРЕС_HQ-SRV] 80 [IP-АДРЕС_HQ-RTR-GLOBAL (к ISP)] 8080"
    
    echo "Прокидывается IP-адрес HQ-SRV с портом 2026 на порт 2026 у HQ-RTR:"
    
    echo "ip nat source static tcp [IP-АДРЕС_HQ-SRV] 2026 [IP-АДРЕС_HQ-RTR-GLOBAL (к ISP)] 2026"
    
    echo "Прокидывается IP-адрес BR-SRV с портом 8080 на порт 8080 у BR-RTR:"
    
    echo "ip nat source static tcp [IP-АДРЕС_BR-SRV] 8080 [IP-АДРЕС_BR-RTR-GLOBAL (к ISP)] 8080"
    
    echo "Прокидывается IP-адрес BR-SRV с портом 2026 на порт 2026 у BR-RTR:"
    
    echo "ip nat source static tcp [IP-АДРЕС_BR-SRV] 2026 [IP-АДРЕС_BR-RTR-GLOBAL (к ISP)] 2026"

    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    systemctl enable --now httpd2

    read -p "Нажми Enter..."
}

setup_reverse_proxy() {
    clear
    echo -e "${BLUE}=== Настройка Nginx reverse proxy ===${NC}"
    echo ""
    
    apt-get install -y nginx

    while true; do
        read -p "Введите доменное имя (пример, web.au-team.irpo или docker.au-team.irpo) (или Enter для завершения): " DOMAIN_NAME
        [[ -z "$DOMAIN_NAME" ]] && break
        read -p "Введите IP-адрес бекенда (172.16.1.2 или 172.16.2.2): " BACKEND_IP
        read -p "Введите порт бекенда (8080): " BACKEND_PORT
        
        cat >> /etc/nginx/sites-available.d/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://$BACKEND_IP:$BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

EOF
    done
    
    ln -sf /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/
    nginx -t && systemctl enable --now nginx
    
    echo -e "${GREEN}✓ Nginx reverse proxy настроен${NC}"
    read -p "Нажми Enter..."
}

setup_web_based () {
    clear
    echo -e "${BLUE}=== ISP. Настройка Web-Based аутентификация ===${NC}"
    echo ""

    apt-get install -y apache2-htpasswd

    htpasswd -bc /etc/nginx/.htpasswd WEB P@ssw0rd

    echo -e "${GREEN}✓ Web-Based аутентификация настроена${NC}"
    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"

    echo -e "Необходимо добавить в файл ${CYAN}/etc/nginx/sites-available.d/default.conf${NC}:"
    echo "auth_basic "Restricted Access";"
    echo "auth_basic_user_file /etc/nginx/.htpasswd;"
    echo "Добавляйте там, где необходимо! См. задание 2.10"

    echo ""

    echo -e "${YELLOW}============ ВАЖНЫЙ МЕССЕЙДЖ!!!!====================${NC}"


    if nginx -t >/dev/null; then
        echo -e "${GREEN}✓ Nginx настроен${NC}"
    else
        echo -e "${RED}✗ Ошибка настройки Nginx${NC}"
    fi

    systemctl restart nginx
    
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
        echo "1) Импорт пользователей из CSV в домен (BR-SRV)"
        echo "2) Настройка центра сертификации (ГОСТ) (HQ-SRV)"
        echo "3) Настройка Nginx HTTPS с ГОСТ (ISP)"
        echo "4) Установка корневого сертификата (HQ-CLI)"
        echo "5) Настройка CUPS принт-сервера (HQ-SRV)"
        echo "6) Настройка CUPS клиента (клиент, но необяз, СКИПНУТЬ)"
        echo "7) Настройка IP-туннеля до уровня шифрования (HQ и BR RTRы)"
        echo "8) Вернуться в главное меню"
        echo ""
        read -p "Выберите пункт: " choice
        
        case $choice in
            1) import_users_csv ;;
            2) setup_ca_gost ;;
            3) setup_nginx_https_gost ;;
            4) install_root_certificate ;;
            5) setup_cups_server_v3 ;;
            6) setup_cups_client_v3 ;;
            7) setup_ipsec_vpn ;;
            8) break ;;
            *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
        esac
    done
}

import_users_csv() {
    clear
    echo -e "${BLUE}=== Импорт пользователей из CSV в домен ===${NC}"
    echo ""
    
    mount /dev/sr0 /mnt/ 2>/dev/null

    read -p "Введите путь к CSV файлу (например, /mnt/Users.csv): " CSV_FILE
    read -p "Введите пароль администратора домена: " ADMIN_PASS
    read -p "Введите Realm (например, AU-TEAM.IRPO): " REALM

    read -p "Введите первое значение домена перед точкой (например, au-team при полном домене au-team.irpo): " DOMAIN
    read -p "Введите второе значение домена после точки (например, irpo при полном домене au-team.irpo): " DOMAIN2
    
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Ошибка: Файл $CSV_FILE не найден! ЛОХ ЕБАННЫЙ ${NC}"
        echo -e "${YELLOW}Подсказка: проверь монтирование командой mount (${CYAN}mount /dev/sr0 /mnt/${NC}) ${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}[1/3] Создание уникальных OU..${NC}"

    OU_LIST=$(awk -F ';' 'NR>1 {print $5}' "$CSV_FILE" | sort | uniq)
    echo "$OU_LIST" | while read -r ou; do
        if [ -z "$ou" ]; then continue; fi
        samba-tool ou add "OU=$ou,DC=$DOMAIN,DC=$DOMAIN2"
    done

    echo -e "${BLUE}[2/3] Создание и импорт пользователей..${NC}"
    while IFS=";" read -r firstName lastName role phone ou street zip city country password; do
        if [ "$firstName" = "First Name" ] || [ -z "$firstName" ]; then
            continue
        fi
        username="${firstName,,}.${lastName,,}"
        echo "Добавляем пользователя: $username (OU: $ou)"
        samba-tool user add "$username" P@ssw0rd1 \
            --given-name="$firstName" \
            --surname="$lastName" \
            --telephone-number="$phone" \
            --job-title="$role" \
            --userou="OU=$ou"
        
        samba-tool user setexpiry "$username" --noexpiry
    
    done < "$CSV_FILE"

    echo -e "${BLUE}[3/3] Проверка проведенного процесса..${NC}"
    if samba-tool ou list | grep "Cloud storage" &>/dev/null; then
        echo -e "${GREEN}✓ OU импортированы${NC}"
    else
        echo -e "${RED}✗ Ошибка импорта OU${NC}"
    fi

    echo -e "${GREEN}✓ Импорт завершен${NC}"
    read -p "Нажми Enter..."
}

setup_ca_gost() {
    clear
    echo -e "${BLUE}=== Настройка центра сертификации (ГОСТ) ===${NC}"
    echo ""
    
    echo -e -n "${CYAN}Введите IP адрес ISP для копирования сертификатов: ${NC}"
    rehad ISP_IP
    echo -e -n "${CYAN}Введите IP адрес HQ-CLI для копирования сертификатов: ${NC}"
    read CLI_IP
    echo -e -n "${CYAN}Введите хостнеймы сервисов через пробел каждый (например, web.au-team.irpo docker.au-team.irpo):${NC} " 
    read HOSTNAMES
    
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null
    
    mkdir -p /etc/ssl/certs /etc/ssl/private
    cd /etc/ssl/certs

    echo -e "${BLUE}Создание закрытого ключа ГОСТ-2012${NC}"    
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
    echo -e "${BLUE}Создание корневого сертификата сертификата на 30 дней${NC}"
    echo -e "${YELLOW}При запросе CN: RU, OrgName = au-team.irpo, Common Name - хостнейм сервера полностью${NC}"
    openssl req -new -x509 -md_gost12_256 -days 30 -key ca.key -out ca.cer
    
    for hostname_domain in $HOSTNAMES; do
        echo -e "${BLUE}Генерация ключа и сертификата для $hostname_domain ...${NC}"
        openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out ${hostname_domain}.key
        echo -e "${YELLOW}CN - ЭТО ХОСТНЕЙМ СЕРВИСА ПОЛНОСТЬЮ С ДОМЕНОМ, ПРИМЕР: web.au-team.irpo)${NC}"
        openssl req -new -md_gost12_256 -key ${hostname_domain}.key -out ${hostname_domain}.csr

        openssl x509 -req -in ${hostname_domain}.csr -CA ca.cer -CAkey ca.key -CAcreateserial \
            -out ${hostname_domain}.cer -days 30
    done

    echo ""

    echo -e "${YELLOW}======= ЕЩЕ ОДИН ВАЖНЫЙ МЕССЕЙДЖ ======== {$NC}"

    echo ""

    echo "Внимание! Не забудьте включить доступ по ssh для пользователя root на ISP:"
    echo "vim /etc/openssh/sshd_config и PermitRootLogin yes, затем перезапустить systemctl restart sshd"

    echo ""

    echo -e "${YELLOW}======= ЕЩЕ ОДИН ВАЖНЫЙ МЕССЕЙДЖ ======== {$NC}"

    read -p "Как только все сделали, нажмите Enter, чтобы продолжить..."

    echo -e "${BLUE}Копирование сертификатов на ISP...${NC}"

    for hostname_domain in $HOSTNAMES; do
        scp ${hostname_domain}.key root@${ISP_IP}:/root/
        scp ${hostname_domain}.cer root@${ISP_IP}:/root/
    done
    
    echo -e "${GREEN}✓ Центр сертификации настроен (сертификаты на 30 дней)${NC}"
    read -p "Нажми Enter..."
}

setup_nginx_https_gost() {
    clear
    echo -e "${BLUE}=== Настройка Nginx HTTPS с ГОСТ ===${NC}"
    echo ""
    
    echo -e -n "${CYAN}Введите первый сервис (например, web.au-team.irpo)${NC} "
    read WEB_BACKEND
    echo -e -n "${CYAN}Введите второй сервис (например, docker.au-team.irpo)${NC} "
    read DOCKER_BACKEND
    echo -e -n "${CYAN}Введите IP-адрес для первого сервиса (например, 172.16.1.1): ${NC}"
    read WEB_BACKEND_IP
    echo -e -n "${CYAN}Введите IP-адрес для второго сервиса (например, 172.16.2.2): ${NC}"
    read DOCKER_BACKEND_IP
    
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null

    mkdir /etc/nginx/ssl
    for domain in $WEB_BACKEND $DOCKER_BACKEND; do
        if [[ -f /root/${domain}.key ]]; then
            cp ${domain}.key /etc/nginx/ssl/
            cp ${domain}.cer /etc/nginx/ssl/
        fi
    done
    
    cat > /etc/nginx/sites-available.d/default.conf <<EOF
server {
    listen 443 ssl;
    server_name $WEB_BACKEND;
    ssl_certificate /etc/nginx/ssl/$WEB_BACKEND.cer;
    ssl_certificate_key /etc/nginx/ssl/$WEB_BACKEND.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    location / { 
        proxy_pass http://$WEB_BACKEND_IP:80; 
        proxy_set_header Host \$host; 
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 443 ssl;
    server_name $DOCKER_BACKEND;
    ssl_certificate /etc/nginx/ssl/$DOCKER_BACKEND.cer;
    ssl_certificate_key /etc/nginx/ssl/$DOCKER_BACKEND.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    location / { 
        proxy_pass http://$DOCKER_BACKEND_IP:8080; 
        proxy_set_header Host \$host; 
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
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

    echo -e "${YELLOW}======= ВАЖНЫЙ КОМЕНТИК ======== {$NC}"
    
    echo ""
    
    echo "ЕСЛИ ПРОТОКОЛ НЕ ПОДДЕРЖИВАЕТСЯ, КОГДА ВЫ ЗАШЛИ НА КЛИЕНТЕ:"
    
    echo "Заходим на сайт cryptopro.ru на HQ-CLI"
    
    echo "Выбираем Продукты -> КриптоПро CSP -> Скачать КриптоПро CSP"
    
    echo "Заполняем данные, выбираем скачать для Linux RPM"
    
    echo "Запускаем, в наборе для установки пометить <Импортировать корневые сертификаты из ОС>"

    echo -e "${YELLOW}======= ВАЖНЫЙ КОМЕНТИК ======== {$NC}"
    read -p "Нажми Enter..."
}

setup_cups_server_v3() {
    clear
    echo -e "${BLUE}=== Настройка CUPS принт-сервера (HQ-SRV) ===${NC}"
    echo ""

    apt-get install -y cups cups-pdf
    systemctl enable --now cups
    cupsctl --share-printers --remote-any

    echo -e "${YELLOW}======= ВАЖНЫЙ КОМЕНТИК ======== {$NC}"
    echo ""
    echo "На HQ-CLI прописать в /etc/hosts сервак HQ-SRV, ну либо с помощью samba-tool на BR-SRV прописать DNS запись:"
    echo "samba-tool domain dns record add hq-srv.au-team.irpo"

    echo "Также на HQ-CLI залетаем в Настройки, Принтеры и добавляем принтер блин. Делаем пробную печать."
    echo "По итогу, на HQ-SRV в ls -l /var/spool/cups/ создаются файлы-пробники"

    echo ""
    echo -e "${YELLOW}======= ВАЖНЫЙ КОМЕНТИК ======== {$NC}"
    echo ""
    echo -e "${GREEN}✓ CUPS принт-сервер настроен."
    read -p "Нажми Enter..."
}

setup_cups_client_v3() {
    clear
    echo -e "${BLUE}=== Настройка CUPS клиента ===${NC}"
    echo ""
    
    echo -e -n "${CYAN}Введите IP-адрес CUPS сервера: ${NC} "
    read SERVER_IP
    echo -e -n "${CYAN}Введите имя принтера на сервере: ${NC} "
    read PRINTER_NAME
    echo -e -n "${CYAN}Введите локальное имя принтера: ${NC} "
    read LOCAL_PRINTER
    
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

setup_ipsec_vpn() {
    clear
    echo -e "${BLUE}=== Настройка IKE VPN ===${NC}"
    echo ""

    echo -e "${YELLOW}================ HQ-RTR ================= ${NC}"
    echo ""
    echo "conf t"
    echo "hq-rtr(config)#crypto-ipsec ike enable"
    echo "hq-rtr(config)#crypto-ipsec profile CIPROFILE ike-v2"
    echo "hq-rtr(config-ipsec-ikev2)#mode tunnel"
    echo "hq-rtr(config-ipsec-ikev2)#ike-phase1"
    echo "hq-rtr(config-ipsec-ikev2-ph1)#proposal aes256-sha256-modp2048"
    echo "hq-rtr(config-ipsec-ikev2-ph1)#auth pre-shared-key P@ssw0rd"
    echo "hq-rtr(config-ipsec-ikev2-ph1)#exit"
    echo "hq-rtr(config-ipsec-ikev2)#ike-phase2"
    echo "hq-rtr(config-ipsec-ikev2-ph2)#protocol esp"
    echo "hq-rtr(config-ipsec-ikev2-ph2)#proposal aes256-sha256"
    echo "hq-rtr(config-ipsec-ikev2-ph2)#local-ts [IP-адрес HQ-RTR]"
    echo "hq-rtr(config-ipsec-ikev2-ph2)#remote-ts [IP-адрес BR-RTR]"
    echo "hq-rtr(config-ipsec-ikev2-ph2)#exit"
    echo "hq-rtr(config-ipsec-ikev2)#exit"
    echo "hq-rtr(config)#crypto-map CMAP 10"
    echo "hq-rtr(config-crypto-map)#match peer [IP-адрес BR-RTR]"
    echo "hq-rtr(config-crypto-map)#set crypto-ipsec profile CIPROFILE"
    echo "hq-rtr(config)#filter-map ipv4 FMAP 5"
    echo "hq-rtr(config-filter-map-ipv4)#match gre host [IP-адрес HQ-RTR] host [IP-адрес BR-RTR]"
    echo "hq-rtr(config-filter-map-ipv4)#set crypto-map CMAP peer [IP-адрес BR-RTR]"
    echo "hq-rtr(config-filter-map-ipv4)#exit"
    echo "hq-rtr(config)#filter-map ipv4 FMAP 10"
    echo "hq-rtr(config-filter-map-ipv4)#match udp host [IP-адрес BR-RTR] eq 4500 host [IP-адрес HQ-RTR] eq 4500"
    echo "hq-rtr(config-filter-map-ipv4)#set crypto-map CMAP peer [IP-адрес BR-RTR]"
    echo "hq-rtr(config-filter-map-ipv4)#exit"
    echo "hq-rtr(config)#filter-map ipv4 FMAP 15"
    echo "hq-rtr(config-filter-map-ipv4)#match any any any"
    echo "hq-rtr(config-filter-map-ipv4)#set accept"
    echo "hq-rtr(config-filter-map-ipv4)#exit"
    echo "hq-rtr(config)#interface isp"
    echo "hq-rtr(config-if)#set filter-map in FMAP 10"
    echo "hq-rtr(config-if)#exit"
    echo "hq-rtr(config)#interface tunnel.0"
    echo "hq-rtr(config-if-tunnel)#set filter-map in FMAP 10"
    echo "hq-rtr(config-if-tunnel)#exit"
    echo "hq-rtr(config)#write memory"
    
    echo ""
    echo -e "${YELLOW}================ HQ-RTR ================= ${NC}"
    echo ""

    echo -e "${YELLOW}============= BR-RTR: ================ ${NC}"
    echo ""
    echo "br-rtr(config)#crypto-ipsec ike enable"
    echo "br-rtr(config)#crypto-ipsec profile CIPROFILE ike-v2"
    echo "br-rtr(config-ipsec-ikev2)#mode tunnel"
    echo "br-rtr(config-ipsec-ikev2)#ike-phase1"
    echo "br-rtr(config-ipsec-ikev2-ph1)#proposal aes256-sha256-modp2048"
    echo "br-rtr(config-ipsec-ikev2-ph1)#auth pre-shared-key P@ssw0rd"
    echo "br-rtr(config-ipsec-ikev2-ph1)#exit"
    echo "br-rtr(config-ipsec-ikev2)#"
    echo "br-rtr(config-ipsec-ikev2)#ike-phase2"
    echo "br-rtr(config-ipsec-ikev2-ph2)#protocol esp"
    echo "br-rtr(config-ipsec-ikev2-ph2)#proposal aes256-sha256"
    echo "br-rtr(config-ipsec-ikev2-ph2)#local-ts [IP-адрес BR-RTR]"
    echo "br-rtr(config-ipsec-ikev2-ph2)#remote-ts [IP-адрес HQ-RTR]"
    echo "br-rtr(config-ipsec-ikev2-ph2)#exit"
    echo "br-rtr(config-ipsec-ikev2)#exit"
    echo "br-rtr(config)#crypto-map CMAP 10"
    echo "br-rtr(config-crypto-map)#match peer [IP-адрес HQ-RTR]"
    echo "br-rtr(config-crypto-map)#set crypto-ipsec profile CIPROFILE"
    echo "br-rtr(config-crypto-map)#exit"
    echo "br-rtr(config)#filter-map ipv4 FMAP 5"
    echo "br-rtr(config-filter-map-ipv4)#match gre host [IP-адрес BR-RTR] host [IP-адрес HQ-RTR]"
    echo "br-rtr(config-filter-map-ipv4)#set crypto-map CMAP peer [IP-адрес HQ-RTR]"
    echo "br-rtr(config-filter-map-ipv4)#exit"
    echo "br-rtr(config)#filter-map ipv4 FMAP 10"
    echo "br-rtr(config-filter-map-ipv4)#match udp host [IP-адрес HQ-RTR] eq 4500 host [IP-адрес BR-RTR] eq 4500"
    echo "br-rtr(config-filter-map-ipv4)#set crypto-map CMAP peer [IP-адрес HQ-RTR]"
    echo "br-rtr(config-filter-map-ipv4)#exit"
    echo "br-rtr(config)#filter-map ipv4 FMAP 15"
    echo "br-rtr(config-filter-map-ipv4)#match any any any"
    echo "br-rtr(config-filter-map-ipv4)#set accept"
    echo "br-rtr(config-filter-map-ipv4)#exit"
    echo "br-rtr(config)#interface isp"
    echo "br-rtr(config-if)#set filter-map in FMAP 10"
    echo "br-rtr(config-if)#exit"
    echo "br-rtr(config)#interface tunnel.0"
    echo "br-rtr(config-if-tunnel)#set filter-map in FMAP 10"
    echo "br-rtr(config-if-tunnel)#exit"
    echo "br-rtr(config)#write memory"    

    echo ""

    echo -e "${YELLOW}============= BR-RTR: ================ ${NC}"

    echo ""
    echo -e "${GREEN} Введите все команды, указанные выше.${NC}"
    echo ""

    read -p "Нажми Enter..."
}

# ==================== ГЛАВНОЕ МЕНЮ ====================
show_main_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    УНИВЕРСАЛЬНЫЙ СКРИПТ НАСТРОЙКИ                    ║${NC}"
    echo -e "${CYAN}║                      ALT LINUX / Сис АДМИН                           ║${NC}"
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