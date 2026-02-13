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

# Ссылки и пути
ALIAS_PATH="/usr/local/bin/GoTelegram"
ALIAS_LOWER="/usr/local/bin/gotelegram"
TIP_LINK="https://pay.cloudtips.ru/p/7410814f"
PROMO_LINK="https://vk.cc/ct29NQ"

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
type_text() {
    local text="$1"
    local delay=0.01
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Запустите скрипт с правами root (sudo)!${NC}"
        exit 1
    fi
}

prepare_system() {
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    fi
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1

    if ! command -v qrencode &> /dev/null; then
        apt-get update -y && apt-get install -y qrencode > /dev/null 2>&1 || yum install -y qrencode -y > /dev/null 2>&1
    fi

    cp "$0" "$ALIAS_PATH"
    chmod +x "$ALIAS_PATH"
    ln -sf "$ALIAS_PATH" "$ALIAS_LOWER"
    
    if ! grep -q "gotelegram" ~/.bashrc; then
        echo "alias gotelegram='GoTelegram'" >> ~/.bashrc
        echo "alias GoTelegram='/usr/local/bin/GoTelegram'" >> ~/.bashrc
    fi
}

# --- ПРОМО БЛОК ---
show_promo() {
    clear
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          ХОСТИНГ, КОТОРЫЙ РАБОТАЕТ СО СКИДКОЙ ДО -60%         ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -ne "${CYAN}"
    type_text "  >>> $PROMO_LINK"
    type_text "  >>> $PROMO_LINK"
    type_text "  >>> $PROMO_LINK"
    echo -ne "${NC}"

    echo ""
    echo -e "${MAGENTA}❖ •••••••••••••••••• PROMO CODES ••••••••••••••••••• ❖${NC}"
    echo ""
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "OFF60" "60% скидка на первый месяц"
    echo -e "${BLUE}  . . . . . . . . . . . . . . . . . . . . . . . . . . ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka20" "Буст 20% + 3% (при оплате за 3 мес)"
    echo -e "${BLUE}  . . . . . . . . . . . . . . . . . . . . . . . . . . ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka6" "Буст 15% + 5% (при оплате за 6 мес)"
    echo -e "${BLUE}  . . . . . . . . . . . . . . . . . . . . . . . . . . ${NC}"
    printf "  ${YELLOW}%-12s${NC} : ${WHITE}%s${NC}\n" "antenka12" "Буст 5% + 5% (при оплате за 12 мес)"
    echo ""
    echo -e "${MAGENTA}❖ •••••••••••••••••••••••••••••••••••••••••••••••••• ❖${NC}"

    echo -e "\n${YELLOW}Генерация QR-кода... (5 сек)${NC}"
    for i in {5..1}; do echo -ne "$i..."; sleep 1; done
    echo ""
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    echo -e "${GREEN}Сканируйте камерой телефона!${NC}"
    read -p "Нажмите Enter для настройки прокси..."
}

# --- ВЫВОД КОНФИГУРАЦИИ С ИНСТРУКЦИЕЙ ---
show_current_config() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не запущен.${NC}"; return; fi
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    # Используем альтернативные сервисы и жесткую фильтрацию только цифр
    IP=$(curl -s -4 https://icanhazip.com || curl -s -4 https://ipinfo.io/ip || curl -s -4 https://checkip.amazonaws.com)
    
    # Убираем любые лишние символы, если сервис вернул HTML или мусор
    IP=$(echo "$IP" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)

    # Если совсем ничего не помогло, берем внутренний IP сервера
    if [[ -z "$IP" ]]; then 
        IP=$(hostname -I | awk '{print $1}')
    fi
    CONF_LINK="tg://proxy?server=$IP&port=443&secret=$SECRET"
    
    echo -e "${GREEN}=== ПАНЕЛЬ ДАННЫХ (RU) ===${NC}"
    echo -e "IP: $IP | Port: 443"
    echo -e "Secret: $SECRET"
    echo -e "\n${BLUE}$CONF_LINK${NC}\n"
    qrencode -t ANSIUTF8 "$CONF_LINK"
    
    echo -e "------------------------------------------------------"
    echo -e "${YELLOW}КАК ИМПОРТИРОВАТЬ ПРОКСИ:${NC}"
    echo -e "${WHITE}1)${NC} Скопировать ссылку выше в браузер или переслать в"
    echo -e "   личные сообщения (например самому себе или избранное)"
    echo -e "${WHITE}2)${NC} Просто сосканировать телефоном QR код и добавить"
    echo -e "   в приложение Proxy"
    echo -e "------------------------------------------------------"
}

manage_proxy() {
    local DOMAINS=("habr.com" "rbc.ru" "lenta.ru" "wikipedia.org" "tass.ru")
    clear
    echo -e "${CYAN}--- Настройка MTProxy ---${NC}"
    for i in "${!DOMAINS[@]}"; do
        printf "${YELLOW}%2d)${NC} %s\n" "$((i+1))" "${DOMAINS[$i]}"
    done
    echo -e "${YELLOW} 0)${NC} Свой домен"
    read -p "Выбор: " d_choice
    [[ "$d_choice" -eq 0 ]] && read -p "Домен: " SELECTED_DOMAIN || SELECTED_DOMAIN=${DOMAINS[$((d_choice-1))]}
    [[ -z "$SELECTED_DOMAIN" ]] && SELECTED_DOMAIN="habr.com"
    
    docker stop mtproto-proxy >/dev/null 2>&1
    docker rm mtproto-proxy >/dev/null 2>&1
    
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$SELECTED_DOMAIN")
    
    docker run -d --name mtproto-proxy --restart always -p 443:443 \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:443 "$SECRET" > /dev/null
    
    if [ "$(docker inspect -f '{{.State.Running}}' mtproto-proxy)" == "true" ]; then
        clear; show_current_config;
    else
        echo -e "${RED}Ошибка запуска. Проверьте порт 443.${NC}"
    fi
    read -p "Enter для возврата..."
}

# --- QR НА ЧАЙ (ПРИ ВЫХОДЕ) ---
show_tips() {
    clear
    echo -e "${MAGENTA}💰 БЛАГОДАРНОСТЬ АВТОРУ${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "${YELLOW}Сканируйте для чаевых (CloudTips).${NC}"
    echo -e "Спасибо за использование GoTelegram!"
}

# --- МЕНЮ ---
show_menu() {
    while true; do
        clear
        echo -e "${MAGENTA}"
        echo "******************************************************"
        echo "        anten-ka канал представляет..."
        echo "        YouTube: https://www.youtube.com/@antenkaru"
        echo "******************************************************"
        echo -e "${NC}"
        
        echo -e "${YELLOW}Получить инструкции:${NC}"
        echo -e "1 способ: ${BLUE}https://boosty.to/anten-ka${NC}"
        echo -e "2 способ: ${BLUE}https://antenka.taplink.ws${NC}"
        echo -e "3 способ: ${BLUE}https://web.tribute.tg/p/cJu${NC}"
        echo ""
        echo -e "${GREEN}💰 Задонатить каналу и автору:${NC} $TIP_LINK"
        echo -e "------------------------------------------------------"
        
        echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
        echo -e "2) Показать QR и ссылку прокси"
        echo -e "3) ${RED}Удалить прокси${NC}"
        echo -e "4) ${YELLOW}Показать PROMO${NC}"
        echo -e "0) Выход"
        echo -e "------------------------------------------------------"
        read -p "Ваш выбор: " choice
        case $choice in
            1) manage_proxy ;;
            2) clear; show_current_config; read -p "Enter..." ;;
            3) docker stop mtproto-proxy && docker rm mtproto-proxy && echo "Удалено" && sleep 1 ;;
            4) show_promo ;;
            0) exit 0 ;;
        esac
    done
}

# ЗАПУСК
check_root
prepare_system
show_promo
trap show_tips EXIT
show_menu
