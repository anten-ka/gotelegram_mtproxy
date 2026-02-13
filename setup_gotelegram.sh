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

# --- ПОДГОТОВКА ---
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
    # Самокопирование для работы команды gotelegram
    if [ "$0" != "$BINARY_PATH" ]; then
        cp "$0" "$BINARY_PATH" && chmod +x "$BINARY_PATH"
    fi
}

get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com)
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

# --- ФУНКЦИЯ ПРОМО (ВЫЗЫВАЕТСЯ ПРИ УСТАНОВКЕ) ---
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
    
    echo -e "\n${YELLOW}Генерация QR-кода на скидку...${NC}"
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    echo -e "${GREEN}Сканируйте для получения скидки на сервер!${NC}"
    echo -e "------------------------------------------------------"
    echo -e "${CYAN}ВНИМАНИЕ: Сначала используйте промокод, затем ставьте прокси!${NC}"
    read -p "Нажмите [ENTER], чтобы продолжить установку..."
}

# --- ВЫВОД ДАННЫХ ПАНЕЛИ ---
show_config() {
    clear
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не запущен!${NC}"; return; fi
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    IP=$(get_ip)
    PORT=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
    PORT=${PORT:-443}
    CONF_LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    echo -e "${GREEN}=== ПАНЕЛЬ ДАННЫХ (RU) ===${NC}"
    echo -e "IP: ${CYAN}$IP${NC} | Порт: ${CYAN}$PORT${NC}"
    echo -e "Secret: ${CYAN}$SECRET${NC}"
    echo -e "\n${BLUE}$CONF_LINK${NC}\n"
    qrencode -t ANSIUTF8 "$CONF_LINK"
}

# --- ГЛАВНАЯ УСТАНОВКА ---
menu_install() {
    # 1. ОБЯЗАТЕЛЬНОЕ ПРОМО
    show_promo 
    
    # 2. НАСТРОЙКА ПАРАМЕТРОВ
    clear
    echo -e "${CYAN}--- Настройка маскировки (Fake TLS) ---${NC}"
    options=("habr.com" "google.com" "wikipedia.org" "rbc.ru" "Свой домен")
    for i in "${!options[@]}"; do echo -e "$((i+1))) ${options[$i]}"; done
    read -p "Выбор домена [1]: " d_idx
    case $d_idx in 5) read -p "Домен: " DOMAIN ;; *) DOMAIN=${options[$((d_idx-1))]} ;; esac
    DOMAIN=${DOMAIN:-habr.com}

    read -p "Введите порт [443]: " PORT
    PORT=${PORT:-443}
    
    echo -e "${YELLOW}Запуск контейнера...${NC}"
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$DOMAIN")
    docker stop mtproto-proxy &>/dev/null; docker rm mtproto-proxy &>/dev/null
    docker run -d --name mtproto-proxy --restart always -p "$PORT":"$PORT" \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:"$PORT" "$SECRET" > /dev/null
    
    show_config
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    read -p "Нажмите Enter для возврата в меню..."
}

# --- ВЫХОД (ПАНЕЛЬ ДАННЫХ + ДОНАТ) ---
show_exit() {
    clear
    echo -e "${GREEN}=== ФИНАЛЬНЫЕ ДАННЫЕ ПРОКСИ ===${NC}"
    if docker ps | grep -q "mtproto-proxy"; then
        SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
        IP=$(get_ip)
        PORT=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
        echo -e "IP: $IP | Port: ${PORT:-443}"
        echo -e "Link: tg://proxy?server=$IP&port=${PORT:-443}&secret=$SECRET"
    else
        echo -e "Прокси не был запущен."
    fi
    
    echo -e "\n${MAGENTA}💰 БЛАГОДАРНОСТЬ АВТОРУ (CloudTips)${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "Донат: ${YELLOW}$TIP_LINK${NC}"
    echo -e "YouTube: ${CYAN}https://www.youtube.com/@antenkaru${NC}"
    echo -e "\n${GREEN}До встречи!${NC}"
}

# --- СТАРТ ---
check_root
install_deps

while true; do
    echo -e "\n${MAGENTA}=== GoTelegram Manager (by anten-ka) ===${NC}"
    echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
    echo -e "2) Показать данные подключения (QR)${NC}"
    echo -e "3) ${YELLOW}Показать PROMO (Скидки на VPS)${NC}"
    echo -e "4) ${RED}Удалить прокси${NC}"
    echo -e "0) Выход (и донат)${NC}"
    read -p "Выберите пункт: " m_idx
    case $m_idx in
