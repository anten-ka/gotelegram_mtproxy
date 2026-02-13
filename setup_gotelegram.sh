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

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
type_text() {
    local text="$1"
    for (( i=0; i<${#text}; i++ )); do echo -n "${text:$i:1}"; sleep 0.01; done
    echo ""
}

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
    cp "$0" "$BINARY_PATH" && chmod +x "$BINARY_PATH"
}

get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com)
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

# --- ПРОМО БЛОК (С ИСПРАВЛЕННЫМ ВЫВОДОМ) ---
show_promo() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          ХОСТИНГ, КОТОРЫЙ РАБОТАЕТ СО СКИДКОЙ ДО -60%         ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -ne "${CYAN}"
    type_text "  >>> $PROMO_LINK"
    echo -ne "${NC}"
    echo -e "\n${MAGENTA}❖ •••••••••••••••••• АКТУАЛЬНЫЕ ПРОМОКОДЫ •••••••••••••••••• ❖${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "OFF60" "Скидка 60% на ПЕРВЫЙ МЕСЯЦ"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka20" "Буст 20% + 3% (при оплате за 3 МЕС)"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka6" "Буст 15% + 5% (при оплате за 6 МЕС)"
    echo -e "${BLUE}  ---------------------------------------------------------- ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka12" "Буст 5% + 5% (при оплате за 12 МЕС)"
    echo -e "${MAGENTA}❖ •••••••••••••••••••••••••••••••••••••••••••••••••••••••••• ❖${NC}"
    
    echo -e "\n${YELLOW}Генерация QR-кода на хостинг... (5 сек)${NC}"
    for i in {5..1}; do echo -ne "$i..."; sleep 1; done
    echo -e "\n"
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    echo -e "${GREEN}Сканируйте камерой телефона для получения скидки!${NC}"
    echo -e "------------------------------------------------------"
    read -p "Нажмите [ENTER] чтобы перейти к установке прокси..."
}

# --- ВЫВОД ДАННЫХ ---
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
    echo -e "${YELLOW}КАК ИМПОРТИРОВАТЬ:${NC}"
    echo -e "1) Кликните по ссылке в терминале"
    echo -e "2) Сосканируйте QR-код телефоном"
    echo -e "------------------------------------------------------"
}

# --- УСТАНОВКА ---
menu_install() {
    # Сначала показываем промо
    show_promo
    
    # Затем настройка
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
    read -p "Нажмите Enter для возврата в меню..."
}

show_exit() {
    clear
    echo -e "${MAGENTA}💰 БЛАГОДАРНОСТЬ АВТОРУ (CloudTips)${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "Ссылка на донат: ${YELLOW}$TIP_LINK${NC}"
    echo -e "YouTube: ${CYAN}https://www.youtube.com/@antenkaru${NC}"
    echo -e "\n${GREEN}Спасибо за использование скрипта!${NC}"
}

check_root
install_deps

while true; do
    echo -e "\n${MAGENTA}=== GoTelegram Manager (by anten-ka) ===${NC}"
    echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
    echo -e "2) Показать данные подключения (QR)${NC}"
    echo -e "3) ${YELLOW}Показать PROMO (Скидки на VPS)${NC}"
    echo -e "4) ${RED}Удалить прокси${NC}"
    echo -e "0) Выход${NC}"
    read -p "Выберите пункт: " m_idx
    case $m_idx in
        1) menu_install ;;
        2) show_config; read -p "Нажмите Enter для возврата..." ;;
        3) show_promo ;;
        4) docker stop mtproto-proxy && docker rm mtproto-proxy && echo -e "${GREEN}Удалено!${NC}" ;;
        0) show_exit; exit 0 ;;
    esac
done
