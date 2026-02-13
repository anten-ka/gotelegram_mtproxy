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
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- СИСТЕМНЫЕ ПРОВЕРКИ ---
check_root() {
    if [ "$EUID" -ne 0 ]; then echo -e "${RED}Ошибка: запустите через sudo!${NC}"; exit 1; fi
}

install_deps() {
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
    if ! command -v qrencode &> /dev/null; then
        apt-get update && apt-get install -y qrencode || yum install -y qrencode
    fi
    # Регистрация команды
    cp "$0" "$BINARY_PATH" && chmod +x "$BINARY_PATH"
}

get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com || echo "0.0.0.0")
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

# --- 1) ФУНКЦИЯ ПРОМОКОДОВ ---
show_promo() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          ХОСТИНГ, КОТОРЫЙ РАБОТАЕТ СО СКИДКОЙ ДО -60%         ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}  >>> Ссылка: $PROMO_LINK ${NC}"
    echo -e "\n${MAGENTA}❖ •••••••••••••••••• АКТУАЛЬНЫЕ ПРОМОКОДЫ •••••••••••••••••• ❖${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "OFF60" "Скидка 60% на ПЕРВЫЙ МЕСЯЦ"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka20" "Буст 20% + 3% (при оплате за 3 МЕС)"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka6" "Буст 15% + 5% (при оплате за 6 МЕС)"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka12" "Буст 5% + 5% (при оплате за 12 МЕС)"
    echo -e "${MAGENTA}❖ •••••••••••••••••••••••••••••••••••••••••••••••••••••••••• ❖${NC}"
    echo -e "\n${YELLOW}[*] Генерация QR-кода на скидку...${NC}"
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    echo -e "${GREEN}Сканируйте камерой для скидки!${NC}"
    echo -e "------------------------------------------------------"
    read -p "ПРОЧИТАЛИ? Нажмите [ENTER] для перехода к настройке..."
}

# --- ВЫВОД ПАНЕЛИ ДАННЫХ ---
show_config() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не найден!${NC}"; return; fi
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    IP=$(get_ip)
    PORT=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
    PORT=${PORT:-443}
    LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    echo -e "\n${GREEN}=== ПАНЕЛЬ ДАННЫХ (RU) ===${NC}"
    echo -e "IP: $IP | Port: $PORT"
    echo -e "Secret: $SECRET"
    echo -e "Link: ${BLUE}$LINK${NC}"
    qrencode -t ANSIUTF8 "$LINK"
}

# --- 2) УСТАНОВКА БЕЗ ОШИБОК ---
menu_install() {
    show_promo # Сначала промокоды и пауза
    
    clear
    echo -e "${CYAN}--- Настройка Fake TLS ---${NC}"
    options=("habr.com" "google.com" "wikipedia.org" "rbc.ru")
    for i in "${!options[@]}"; do echo -e "$((i+1))) ${options[$i]}"; done
    read -p "Выберите домен [1]: " d_idx
    DOMAIN=${options[$((d_idx-1))]}
    DOMAIN=${DOMAIN:-habr.com}

    read -p "Введите порт [443]: " PORT
    PORT=${PORT:-443}
    
    echo -e "${YELLOW}[*] Запуск прокси...${NC}"
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$DOMAIN")
    docker stop mtproto-proxy &>/dev/null
    docker rm mtproto-proxy &>/dev/null
    
    docker run -d --name mtproto-proxy --restart always -p "$PORT":"$PORT" \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:"$PORT" "$SECRET" > /dev/null
    
    clear
    show_config
    read -p "Нажмите Enter для возврата в меню..."
}

# --- ВЫХОД С ТИПСАМИ ---
show_exit() {
    clear
    show_config # Показываем данные перед уходом
    echo -e "\n${MAGENTA}💰 ПОДДЕРЖКА АВТОРА (CloudTips)${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "Донат: $TIP_LINK"
    exit 0
}

# --- ГЛАВНЫЙ ЦИКЛ ---
check_root
install_deps

while true; do
    echo -e "\n${MAGENTA}=== GoTelegram Manager (by anten-ka) ===${NC}"
    echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
    echo -e "2) Показать данные подключения${NC}"
    echo -e "3) ${YELLOW}Показать PROMO (Скидки)${NC}"
    echo -e "4) ${RED}Удалить прокси${NC}"
    echo -e "0) Выход${NC}"
    read -p "Пункт: " m_idx
    case $m_idx in
        1) menu_install ;;
        2) clear; show_config; read -p "Нажмите Enter..." ;;
        3) show_promo ;;
        4) docker stop mtproto-proxy && docker rm mtproto-proxy && echo "Удалено" ;;
        0) show_exit ;;
        *) echo "Неверный выбор" ;;
    esac
done
