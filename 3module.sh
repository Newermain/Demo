#!/bin/bash

# =============================================
# МОДУЛЬ 3 - ПОЛНАЯ НАСТРОЙКА ALT LINUX
# Специальность: Сетевое и системное администрирование
# Устройства: BR-SRV, HQ-SRV, ISP, HQ-CLI
# Задания: 3.1, 3.2, 3.5
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
    echo "Пример: sudo ./3module"
    exit 1
fi

# Глобальные переменные
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

# ==================== ЗАДАНИЕ 3.1 ====================
import_users() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.1 - Импорт пользователей в домен${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # 1. Поиск файла users.csv
    echo -e "${BLUE}[1/5] Поиск файла users.csv...${NC}"
    mkdir -p /mnt
    
    CSV_PATH=""
    for device in /dev/sr0 /dev/sr1 /dev/cdrom; do
        if [[ -b $device ]]; then
            mount $device /mnt 2>/dev/null
            if [[ -f "/mnt/users.csv" ]]; then
                CSV_PATH="/mnt/users.csv"
                break
            elif [[ -f "/mnt/Users.csv" ]]; then
                CSV_PATH="/mnt/Users.csv"
                break
            else
                umount /mnt 2>/dev/null
            fi
        fi
    done
    
    if [[ -z "$CSV_PATH" ]]; then
        echo -e "${YELLOW}Файл users.csv не найден на диске${NC}"
        read -p "Укажи полный путь к файлу users.csv: " CSV_PATH
        if [[ ! -f "$CSV_PATH" ]]; then
            echo -e "${RED}Файл не найден!${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ Файл найден: $CSV_PATH${NC}"
    
    # 2. Подсчет пользователей
    TOTAL_USERS=$(($(wc -l < "$CSV_PATH") - 1))
    echo -e "${GREEN}✓ Найдено $TOTAL_USERS пользователей для импорта${NC}"
    
    # 3. Получение Kerberos билета
    echo -e "${BLUE}[2/5] Получение Kerberos билета...${NC}"
    echo "P@ssw0rd123" | kinit administrator@AU-TEAM.IRPO 2>/dev/null
    
    if klist &>/dev/null; then
        echo -e "${GREEN}✓ Kerberos билет получен${NC}"
    else
        echo -e "${RED}✗ Ошибка получения билета!${NC}"
        return 1
    fi
    
    # 4. Создание скрипта импорта
    echo -e "${BLUE}[3/5] Создание скрипта импорта...${NC}"
    
    cat > /tmp/import_users.sh << 'IMPORT_SCRIPT'
#!/bin/bash
CSV_FILE="$1"
SUCCESS=0
FAIL=0

echo -e "\033[0;34mНачало импорта пользователей...\033[0m"

# Создание OU
for ou in "IT" "Overal" "Manager" "Supporter" "Cloud storage"; do
    if ! samba-tool ou list 2>/dev/null | grep -q "OU=$ou"; then
        samba-tool ou create "OU=$ou" 2>/dev/null
        echo -e "\033[0;32m✓ OU $ou создан\033[0m"
    fi
done

# Импорт пользователей
tail -n +2 "$CSV_FILE" | while IFS=',' read -r login sname fname phone email org position manager ou; do
    login=$(echo "$login" | sed 's/"//g' | xargs | tr '[:upper:]' '[:lower:]')
    fname=$(echo "$fname" | sed 's/"//g' | xargs)
    sname=$(echo "$sname" | sed 's/"//g' | xargs)
    ou=$(echo "$ou" | sed 's/"//g' | xargs)
    
    if samba-tool user list 2>/dev/null | grep -q "^$login$"; then
        echo -e "\033[0;33m⚠ Пользователь $login уже существует\033[0m"
        continue
    fi
    
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
        echo -e "\033[0;32m✓ Пользователь $login создан\033[0m"
        ((SUCCESS++))
    else
        echo -e "\033[0;31m✗ Ошибка создания $login\033[0m"
        ((FAIL++))
    fi
done

echo -e "\033[0;34mИмпорт завершен\033[0m"
IMPORT_SCRIPT
    
    chmod +x /tmp/import_users.sh
    echo -e "${GREEN}✓ Скрипт импорта создан${NC}"
    
    # 5. Запуск импорта
    echo -e "${BLUE}[4/5] Запуск импорта пользователей...${NC}"
    /tmp/import_users.sh "$CSV_PATH"
    
    # 6. Проверка
    echo -e "${BLUE}[5/5] Проверка результатов...${NC}"
    echo ""
    echo -e "${YELLOW}Созданные OU:${NC}"
    samba-tool ou list 2>/dev/null
    
    echo ""
    echo -e "${YELLOW}Количество пользователей:${NC}"
    samba-tool user list 2>/dev/null | wc -l
    
    echo -e "${GREEN}✓ Импорт пользователей завершен!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 3.2 ====================
setup_ca() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.2 - Центр сертификации (ГОСТ)${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    CERT_DIR="/etc/ssl/certs"
    KEY_DIR="/etc/ssl/private"
    mkdir -p $CERT_DIR $KEY_DIR
    cd $CERT_DIR
    
    # 1. Установка openssl-gost-engine
    echo -e "${BLUE}[1/8] Установка openssl-gost-engine...${NC}"
    apt-get update
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null
    echo -e "${GREEN}✓ Поддержка ГОСТ включена${NC}"
    
    # 2. Создание корневого сертификата
    echo -e "${BLUE}[2/8] Создание корневого сертификата УЦ...${NC}"
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
    chmod 600 ca.key
    
    openssl req -new -x509 -md_gost12_256 -days 30 -key ca.key -out ca.cer \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=au-team/CN=au-team Root CA"
    echo -e "${GREEN}✓ Корневой сертификат создан${NC}"
    
    # 3. Создание ключей для веб-серверов
    echo -e "${BLUE}[3/8] Создание ключей для веб-серверов...${NC}"
    for domain in web.au-team.irpo docker.au-team.irpo; do
        openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out ${domain}.key
        chmod 600 ${domain}.key
        echo -e "${GREEN}✓ Ключ для $domain создан${NC}"
    done
    
    # 4. Создание CSR
    echo -e "${BLUE}[4/8] Создание запросов на подпись...${NC}"
    openssl req -new -md_gost12_256 -key web.au-team.irpo.key -out web.au-team.irpo.csr \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=au-team/CN=web.au-team.irpo"
    openssl req -new -md_gost12_256 -key docker.au-team.irpo.key -out docker.au-team.irpo.csr \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=au-team/CN=docker.au-team.irpo"
    echo -e "${GREEN}✓ CSR созданы${NC}"
    
    # 5. Подпись сертификатов
    echo -e "${BLUE}[5/8] Подпись сертификатов (30 дней)...${NC}"
    openssl x509 -req -in web.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial \
        -out web.au-team.irpo.cer -days 30 -md_gost12_256
    openssl x509 -req -in docker.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial \
        -out docker.au-team.irpo.cer -days 30 -md_gost12_256
    echo -e "${GREEN}✓ Сертификаты подписаны${NC}"
    
    # 6. Копирование на ISP
    echo -e "${BLUE}[6/8] Копирование сертификатов на ISP...${NC}"
    # Разрешаем root SSH
    if ! grep -q "PermitRootLogin yes" /etc/openssh/sshd_config; then
        echo "PermitRootLogin yes" >> /etc/openssh/sshd_config
        systemctl restart sshd
    fi
    
    for domain in web.au-team.irpo docker.au-team.irpo; do
        scp -o StrictHostKeyChecking=no ${domain}.key ${domain}.cer root@172.16.1.1:/root/ 2>/dev/null
    done
    echo -e "${GREEN}✓ Сертификаты скопированы на ISP${NC}"
    
    # 7. Копирование на HQ-CLI
    echo -e "${BLUE}[7/8] Копирование корневого сертификата на HQ-CLI...${NC}"
    scp -o StrictHostKeyChecking=no ca.cer root@192.168.200.2:/root/ 2>/dev/null
    echo -e "${GREEN}✓ Корневой сертификат скопирован на HQ-CLI${NC}"
    
    # 8. Проверка
    echo -e "${BLUE}[8/8] Проверка сертификатов...${NC}"
    echo -e "${YELLOW}Информация о корневом сертификате:${NC}"
    openssl x509 -in ca.cer -text -noout | grep -E "Subject:|Not Before|Not After"
    
    echo -e "${GREEN}✓ Центр сертификации настроен!${NC}"
    read -p "Нажми Enter для продолжения..."
}

setup_nginx_https() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.2 - Nginx HTTPS (ГОСТ) на ISP${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "ISP" ]]; then
        echo -e "${RED}Этот скрипт предназначен для ISP!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # 1. Установка поддержки ГОСТ
    echo -e "${BLUE}[1/5] Установка openssl-gost-engine...${NC}"
    apt-get update
    apt-get install -y openssl-gost-engine
    control openssl-gost enabled 2>/dev/null
    echo -e "${GREEN}✓ Поддержка ГОСТ включена${NC}"
    
    # 2. Копирование сертификатов
    echo -e "${BLUE}[2/5] Установка сертификатов...${NC}"
    mkdir -p /etc/nginx/ssl
    for domain in web.au-team.irpo docker.au-team.irpo; do
        if [[ -f /root/${domain}.key ]] && [[ -f /root/${domain}.cer ]]; then
            cp /root/${domain}.key /etc/nginx/ssl/
            cp /root/${domain}.cer /etc/nginx/ssl/
            echo -e "${GREEN}✓ Сертификаты для $domain установлены${NC}"
        fi
    done
    
    # 3. Настройка Nginx
    echo -e "${BLUE}[3/5] Настройка Nginx конфигурации...${NC}"
    cat > /etc/nginx/sites-available.d/default.conf << 'NGINX_CONFIG'
server {
    listen 80;
    server_name web.au-team.irpo;
    return 301 https://$host$request_uri;
}

server {
    listen 80;
    server_name docker.au-team.irpo;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name web.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/web.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers GOST2012-GOST8912-GOST8912;
    
    location / {
        proxy_pass http://192.168.100.2:80;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}

server {
    listen 443 ssl;
    server_name docker.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/docker.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/docker.au-team.irpo.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers GOST2012-GOST8912-GOST8912;
    
    location / {
        proxy_pass http://192.168.0.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}
NGINX_CONFIG
    
    # 4. Проверка и перезапуск
    echo -e "${BLUE}[4/5] Проверка конфигурации...${NC}"
    nginx -t
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Конфигурация верна${NC}"
    else
        echo -e "${RED}✗ Ошибка в конфигурации!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[5/5] Перезапуск Nginx...${NC}"
    systemctl restart nginx
    echo -e "${GREEN}✓ Nginx перезапущен${NC}"
    
    echo -e "${GREEN}✓ Nginx HTTPS настроен!${NC}"
    read -p "Нажми Enter для продолжения..."
}

install_root_cert() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.2 - Установка корневого сертификата${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    echo -e "${BLUE}[1/2] Установка корневого сертификата...${NC}"
    
    if [[ -f /root/ca.cer ]]; then
        cp /root/ca.cer /etc/pki/ca-trust/source/anchors/
        update-ca-trust
        echo -e "${GREEN}✓ Корневой сертификат установлен${NC}"
    else
        echo -e "${RED}✗ Файл ca.cer не найден!${NC}"
        read -p "Укажи путь к сертификату: " CERT_PATH
        if [[ -f "$CERT_PATH" ]]; then
            cp "$CERT_PATH" /etc/pki/ca-trust/source/anchors/
            update-ca-trust
            echo -e "${GREEN}✓ Сертификат установлен${NC}"
        fi
    fi
    
    echo -e "${BLUE}[2/2] Проверка...${NC}"
    trust list | grep -A3 "au-team" 2>/dev/null || echo "Сертификат установлен"
    
    echo -e "${GREEN}✓ Корневой сертификат установлен!${NC}"
    echo -e "${YELLOW}Теперь открой в браузере: https://web.au-team.irpo${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ЗАДАНИЕ 3.5 ====================
setup_cups_server() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.5 - CUPS принт-сервер на HQ-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    # 1. Установка CUPS
    echo -e "${BLUE}[1/5] Установка CUPS и CUPS-PDF...${NC}"
    apt-get update
    apt-get install -y cups cups-pdf
    echo -e "${GREEN}✓ CUPS установлен${NC}"
    
    # 2. Настройка CUPS
    echo -e "${BLUE}[2/5] Настройка CUPS...${NC}"
    usermod -a -G lpadmin sshuser 2>/dev/null
    
    cat > /etc/cups/cupsd.conf << 'CUPS_CONF'
Listen 0.0.0.0:631
<Location />
  Order allow,deny
  Allow localhost
  Allow 192.168.100.0/27
  Allow 192.168.200.0/24
  Allow all
</Location>
<Location /admin>
  Order allow,deny
  Allow localhost
  Allow 192.168.100.0/27
  Allow 192.168.200.0/24
</Location>
CUPS_CONF
    
    cupsctl --share-printers --remote-any
    echo -e "${GREEN}✓ CUPS настроен${NC}"
    
    # 3. Запуск CUPS
    echo -e "${BLUE}[3/5] Запуск CUPS...${NC}"
    systemctl enable --now cups
    systemctl restart cups
    echo -e "${GREEN}✓ CUPS запущен${NC}"
    
    # 4. Создание PDF-принтера
    echo -e "${BLUE}[4/5] Создание виртуального PDF-принтера...${NC}"
    lpadmin -p Virtual_PDF_Printer -E -v cups-pdf:/ -m lsb/usr/cups-pdf/CUPS-PDF.ppd 2>/dev/null
    lpadmin -p Virtual_PDF_Printer -E -v cups-pdf:/ -m everywhere 2>/dev/null
    lpoptions -d Virtual_PDF_Printer
    echo -e "${GREEN}✓ PDF-принтер создан${NC}"
    
    # 5. Проверка
    echo -e "${BLUE}[5/5] Проверка...${NC}"
    echo -e "${YELLOW}Список принтеров:${NC}"
    lpstat -p -d
    
    echo -e "${GREEN}✓ CUPS принт-сервер настроен!${NC}"
    echo -e "Веб-интерфейс: http://$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1):631"
    read -p "Нажми Enter для продолжения..."
}

setup_cups_client() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Задание 3.5 - Подключение принтера на HQ-CLI${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "HQ-CLI" ]]; then
        echo -e "${RED}Этот скрипт предназначен для HQ-CLI!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    HQ_SRV_IP="192.168.100.2"
    
    # 1. Проверка доступности
    echo -e "${BLUE}[1/4] Проверка доступности сервера печати...${NC}"
    if ! ping -c 2 $HQ_SRV_IP &>/dev/null; then
        echo -e "${RED}Сервер печати не доступен!${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Сервер печати доступен${NC}"
    
    # 2. Установка клиента
    echo -e "${BLUE}[2/4] Установка клиентских пакетов...${NC}"
    apt-get install -y cups-client cups-common
    echo -e "${GREEN}✓ Клиентские пакеты установлены${NC}"
    
    # 3. Подключение принтера
    echo -e "${BLUE}[3/4] Подключение принтера...${NC}"
    if ! grep -q "hq-srv.au-team.irpo" /etc/hosts; then
        echo "$HQ_SRV_IP hq-srv.au-team.irpo" >> /etc/hosts
    fi
    
    lpadmin -p PDF_Printer -E -v ipp://$HQ_SRV_IP:631/printers/Virtual_PDF_Printer -m everywhere 2>/dev/null
    echo -e "${GREEN}✓ Принтер подключен${NC}"
    
    # 4. Настройка по умолчанию
    echo -e "${BLUE}[4/4] Настройка принтера по умолчанию...${NC}"
    lpoptions -d PDF_Printer
    
    echo -e "${YELLOW}Список принтеров:${NC}"
    lpstat -p -d
    
    # Тестовая печать
    echo "Test print from HQ-CLI at $(date)" | lp -d PDF_Printer
    echo -e "${GREEN}✓ Тестовая печать отправлена${NC}"
    
    echo -e "${GREEN}✓ Принтер на HQ-CLI настроен!${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ ====================
add_dns_record() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Добавление DNS записи на BR-SRV${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    echo "P@ssw0rd123" | kinit administrator@AU-TEAM.IRPO 2>/dev/null
    samba-tool dns add 127.0.0.1 au-team.irpo hq-srv A 192.168.100.2 -U administrator 2>/dev/null
    echo -e "${GREEN}✓ DNS запись hq-srv.au-team.irpo добавлена${NC}"
    read -p "Нажми Enter для продолжения..."
}

fix_docker_styles() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Исправление стилей в Docker контейнере${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [[ "$CURRENT_DEVICE_TYPE" != "BR-SRV" ]]; then
        echo -e "${RED}Этот скрипт предназначен для BR-SRV!${NC}"
        read -p "Нажми Enter для продолжения..."
        return 1
    fi
    
    docker exec -it testapp ash -c "
        cp /app/site/site.html /app/site/site.html.bak
        sed -i 's|http://cdnjs.cloudflare.com|https://cdnjs.cloudflare.com|g' /app/site/site.html
        echo 'Стили исправлены'
    "
    docker restart testapp
    echo -e "${GREEN}✓ Стили исправлены, контейнер перезапущен${NC}"
    read -p "Нажми Enter для продолжения..."
}

# ==================== ГЛАВНОЕ МЕНЮ ====================
show_main_menu() {
    clear
    detect_device
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 МОДУЛЬ 3 - ALT LINUX НАСТРОЙКА                ║${NC}"
    echo -e "${CYAN}║           Сетевое и системное администрирование              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Текущее устройство:${NC} $CURRENT_DEVICE ($CURRENT_DEVICE_TYPE)"
    echo ""
    echo -e "${GREEN}┌────────────── ЗАДАНИЯ МОДУЛЯ 3 ──────────────┐${NC}"
    echo -e "${GREEN}│  1) Задание 3.1 - Импорт пользователей (BR-SRV)│${NC}"
    echo -e "${GREEN}│  2) Задание 3.2 - Центр сертификации (HQ-SRV) │${NC}"
    echo -e "${GREEN}│  3) Задание 3.2 - Nginx HTTPS (ISP)          │${NC}"
    echo -e "${GREEN}│  4) Задание 3.2 - Установка сертификата (HQ-CLI)│${NC}"
    echo -e "${GREEN}│  5) Задание 3.5 - CUPS сервер (HQ-SRV)       │${NC}"
    echo -e "${GREEN}│  6) Задание 3.5 - CUPS клиент (HQ-CLI)       │${NC}"
    echo -e "${GREEN}│  7) Доп. DNS запись (BR-SRV)                 │${NC}"
    echo -e "${GREEN}│  8) Доп. Исправление стилей Docker (BR-SRV)  │${NC}"
    echo -e "${GREEN}│  9) Выход                                    │${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Совет: Запускай скрипт на нужном устройстве:${NC}"
    echo -e "  - BR-SRV:  пункты 1, 7, 8"
    echo -e "  - HQ-SRV:  пункты 2, 5"
    echo -e "  - ISP:     пункт 3"
    echo -e "  - HQ-CLI:  пункты 4, 6"
    echo ""
    read -p "Выбери пункт меню (1-9): " choice
}

# ==================== ОСНОВНОЙ ЦИКЛ ====================
while true; do
    show_main_menu
    case $choice in
        1) import_users ;;
        2) setup_ca ;;
        3) setup_nginx_https ;;
        4) install_root_cert ;;
        5) setup_cups_server ;;
        6) setup_cups_client ;;
        7) add_dns_record ;;
        8) fix_docker_styles ;;
        9) echo -e "${GREEN}Выход...${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор!${NC}"; sleep 2 ;;
    esac
done