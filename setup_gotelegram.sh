#!/bin/bash

# --- ЦВЕТА ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ссылки
TIP_LINK="https://pay.cloudtips.ru/p/7410814f"
PROMO_LINK="https://vk.cc/ct29NQ"

# --- ПОЛУЧЕНИЕ IP (БРОНЕБОЙНОЕ) ---
get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com || curl -s -4 --max-time 5 https://checkip.amazonaws.com)
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

# --- ПОЛУЧЕНИЕ ПОРТА ИЗ DOCKER ---
get_current_port() {
    local port
    port=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
    echo "${port:-443}"
}

# --- ВЫВОД КОНФИГУРАЦИИ ---
show_current_config() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не запущен.${NC}"; return; fi
    
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    IP=$(get_ip)
    PORT=$(get_current_port)
    
    CONF_LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"
    
    echo -e "${GREEN}=== ПАНЕЛЬ ДАННЫХ (RU) ===${NC}"
    echo -e "IP: $IP | Port: $PORT"
    echo -e "Secret: $SECRET"
    echo -e "\n${BLUE}$CONF_LINK${NC}\n"
    qrencode -t ANSIUTF8 "$CONF_LINK"
    
    echo -e "------------------------------------------------------"
    echo -e "${YELLOW}КАК ИМПОРТИРОВАТЬ ПРОКСИ:${NC}"
    echo -e "${WHITE}1)${NC} Нажмите на ссылку выше или перешлите её в Telegram."
    echo -e "${WHITE}2)${NC} Сосканируйте QR-код камерой телефона."
    echo -e "------------------------------------------------------"
}

# --- ВЫБОР ПОРТА ---
ask_port() {
    echo -e "\n${CYAN}Выберите порт для работы:${NC}"
    echo -e "1) 443 (Рекомендуется)"
    echo -e "2) 8443"
    echo -e "3) Ввести свой порт"
    read -p "Ваш выбор [1]: " p_choice
    case $p_choice in
        2) PORT=8443 ;;
        3) read -p "Введите порт: " PORT ;;
        *) PORT=443 ;;
    esac
}

# --- ЗАПУСК/ПЕРЕЗАПУСК КОНТЕЙНЕРА ---
run_proxy_container() {
    local secret=$1
    local port=$2
    
    docker stop mtproto-proxy >/dev/null 2>&1
    docker rm mtproto-proxy >/dev/null 2>&1
    
    docker run -d --name mtproto-proxy --restart always -p "$port":"$port" \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:"$port" "$secret" > /dev/null
    
    if [ "$(docker inspect -f '{{.State.Running}}' mtproto-proxy)" == "true" ]; then
        clear; show_current_config;
    else
        echo -e "${RED}Ошибка запуска! Возможно, порт $port занят.${NC}"
    fi
}

# --- УСТАНОВКА ---
manage_proxy() {
    local DOMAINS=("habr.com" "rbc.ru" "lenta.ru" "wikipedia.org" "google.com")
    clear
    echo -e "${CYAN}--- Настройка маскировки (Fake TLS) ---${NC}"
    for i in "${!DOMAINS[@]}"; do
        printf "${YELLOW}%2d)${NC} %s\n" "$((i+1))" "${DOMAINS[$i]}"
    done
    echo -e "${YELLOW} 0)${NC} Свой домен"
    read -p "Выбор домена: " d_choice
    [[ "$d_choice" -eq 0 ]] && read -p "Домен: " SELECTED_DOMAIN || SELECTED_DOMAIN=${DOMAINS[$((d_choice-1))]}
    [[ -z "$SELECTED_DOMAIN" ]] && SELECTED_DOMAIN="habr.com"
    
    ask_port
    
    echo -e "${YELLOW}Генерация секретного ключа...${NC}"
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$SELECTED_DOMAIN")
    
    run_proxy_container "$SECRET" "$PORT"
    read -p "Enter для возврата в меню..."
}

# --- СМЕНА ПОРТА ---
change_port() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Сначала установите прокси (пункт 1).${NC}"; sleep 2; return; fi
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    ask_port
    echo -e "${YELLOW}Перезапуск на порту $PORT...${NC}"
    run_proxy_container "$SECRET" "$PORT"
    read -p "Порт изменен! Enter..."
}

# --- ПРОМО И ПРОЧЕЕ (СОКРАЩЕНО ДЛЯ КРАТКОСТИ) ---
show_promo() {
    clear
    echo -e "${MAGENTA}=== PROMO: $PROMO_LINK ===${NC}"
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    read -p "Enter..."
}

show_tips() {
    clear
    echo -e "${MAGENTA}💰 ПОДДЕРЖКА АВТОРА${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "CloudTips: $TIP_LINK"
}

# --- МЕНЮ ---
show_menu() {
    while true; do
        clear
        echo -e "${MAGENTA}******************************************************"
        echo "           GoTelegram MTProxy Manager"
        echo -e "******************************************************${NC}"
        echo -e "1) ${GREEN}Установить / Полная переустановка${NC}"
        echo -e "2) Показать QR и ссылку прокси"
        echo -e "3) ${RED}Удалить прокси${NC}"
        echo -e "4) ${YELLOW}Показать PROMO (Скидки на VPS)${NC}"
        echo -e "5) ${CYAN}Изменить только ПОРТ${NC}"
        echo -e "0) Выход"
        echo -e "------------------------------------------------------"
        read -p "Ваш выбор: " choice
        case $choice in
            1) manage_proxy ;;
            2) clear; show_current_config; read -p "Enter..." ;;
            3) docker stop mtproto-proxy && docker rm mtproto-proxy && echo "Удалено" && sleep 1 ;;
            4) show_promo ;;
            5) change_port ;;
            0) exit 0 ;;
        esac
    done
}

# Трап на выход (показывает QR доната)
trap show_tips EXIT

# Запуск меню
show_menu
