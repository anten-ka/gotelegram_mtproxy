#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
ALIAS_NAME="gotelegram"
BINARY_PATH="/usr/local/bin/gotelegram"
TIP_LINK="https://pay.cloudtips.ru/p/7410814f"
PROMO_LINK="https://vk.cc/ct29NQ"

# --- ЦВЕТА ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- ПРОВЕРКИ И ПОДГОТОВКА ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Ошибка: Запустите скрипт через sudo!${NC}"
        exit 1
    fi
}

install_deps() {
    echo -e "${YELLOW}[*] Проверка зависимостей...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[*] Установка Docker...${NC}"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}[*] Установка qrencode...${NC}"
        apt-get update && apt-get install -y qrencode || yum install -y qrencode
    fi
    
    # Регистрация команды в системе
    if [ "$0" != "$BINARY_PATH" ]; then
        cp "$0" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        ln -sf "$BINARY_PATH" "/usr/local/bin/GoTelegram"
    fi
}

get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com)
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

get_current_port() {
    local port
    port=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
    echo "${port:-443}"
}

# --- ОСНОВНЫЕ ФУНКЦИИ ---
show_config() {
    clear
    if ! docker ps | grep -q "mtproto-proxy"; then
        echo -e "${RED}Прокси не запущен! Сначала выберите пункт 1.${NC}"
        return
    fi
    
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    IP=$(get_ip)
    PORT=$(get_current_port)
    CONF_LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    echo -e "${GREEN}=== ПАНЕЛЬ ДАННЫХ ===${NC}"
    echo -e "IP: ${CYAN}$IP${NC} | Порт: ${CYAN}$PORT${NC}"
    echo -e "Secret: ${CYAN}$SECRET${NC}"
    echo -e "\n${YELLOW}Ссылка для Telegram:${NC}"
    echo -e "${MAGENTA}$CONF_LINK${NC}\n"
    
    qrencode -t ANSIUTF8 "$CONF_LINK"
    echo -e "${YELLOW}Сканируйте QR-код для быстрого подключения${NC}"
}

run_container() {
    local domain=$1
    local port=$2
    
    echo -e "${YELLOW}[*] Генерация ключа для $domain...${NC}"
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$domain")
    
    docker stop mtproto-proxy &>/dev/null
    docker rm mtproto-proxy &>/dev/null
    
    docker run -d --name mtproto-proxy --restart always -p "$port":"$port" \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:"$port" "$SECRET" > /dev/null
    
    if [ $? -eq 0 ]; then
        show_config
    else
        echo -e "${RED}Ошибка запуска! Возможно, порт $port занят другим процессом.${NC}"
    fi
}

# --- МЕНЮ ---
menu_install() {
    clear
    echo -e "${CYAN}--- Выберите домен для маскировки (Fake TLS) ---${NC}"
    options=("habr.com" "google.com" "wikipedia.org" "rbc.ru" "Свой домен")
    for i in "${!options[@]}"; do echo -e "$((i+1))) ${options[$i]}"; done
    read -p "Выбор: " d_idx
    
    case $d_idx in
        5) read -p "Введите домен: " DOMAIN ;;
        *) DOMAIN=${options[$((d_idx-1))]} ;;
    esac
    [[ -z "$DOMAIN" ]] && DOMAIN="habr.com"

    echo -e "\n${CYAN}--- Выберите порт ---${NC}"
    echo -e "1) 443 (Стандарт)"
    echo -e "2) 8443"
    echo -e "3) Свой порт"
    read -p "Выбор: " p_idx
    case $p_idx in
        2) PORT=8443 ;;
        3) read -p "Введите порт: " PORT ;;
        *) PORT=443 ;;
    esac
    
    run_container "$DOMAIN" "$PORT"
}

change_port() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не найден!${NC}"; return; fi
    # Получаем текущий секрет, чтобы не менять его
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    read -p "Введите новый порт: " NEW_PORT
    run_container "dummy.com" "$NEW_PORT" # Домен не важен при готовом секрете
}

# --- ВЫХОД С QR ---
show_exit() {
    clear
    echo -e "${MAGENTA}💰 ПОДДЕРЖКА АВТОРА (CloudTips)${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "Ссылка: $TIP_LINK"
    echo -e "${YELLOW}Спасибо за использование!${NC}"
}

# --- ГЛАВНЫЙ ЦИКЛ ---
check_root
install_deps

while true; do
    echo -e "\n${MAGENTA}=== GoTelegram Manager ===${NC}"
    echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
    echo -e "2) Показать QR и данные подключения"
    echo -e "3) ${CYAN}Изменить порт${NC}"
    echo -e "4) ${RED}Удалить прокси${NC}"
    echo -e "0) Выход"
    read -p "Выберите пункт: " main_idx
    
    case $main_idx in
        1) menu_install ;;
        2) show_config ;;
        3) change_port ;;
        4) docker stop mtproto-proxy && docker rm mtproto-proxy && echo "Удалено" ;;
        0) show_exit; exit 0 ;;
        *) echo "Неверный выбор" ;;
    esac
done
