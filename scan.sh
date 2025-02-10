#!/bin/bash
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Логотип SCANNER
logo() {
    echo "   #####    ####     ####    #####    #####     ####    ###### ";
    echo "  ##       ##  ##       ##   ##  ##   ##  ##   ##  ##    ##  ## ";
    echo "   #####   ##        #####   ##  ##   ##  ##   ######    ## ";
    echo "       ##  ##  ##   ##  ##   ##  ##   ##  ##   ##        ## ";
    echo "  ######    ####     #####   ##  ##   ##  ##    #####   #### ";
    echo "By deadlars"
    echo
}

# Запрос пароля для sudo
get_sudo_password() {
    read -sp "Введите пароль для sudo: " sudo_password
    echo
}

# Выбор языка
choose_language() {
    echo "Выберите язык / Select language:"
    echo "1. Русский (ru)"
    echo "2. English (en)"
    read -p "Введите номер / Enter number: " lang_choice

    case $lang_choice in
        1)
            lang="ru"
            echo "Выбран русский язык."
            ;;
        2)
            lang="en"
            echo "English language selected."
            ;;
        *)
            echo "Неверный выбор. По умолчанию будет использован русский язык."
            echo "Invalid choice. Defaulting to Russian."
            lang="ru"
            ;;
    esac
}

# Локализация сообщений
localize() {
    if [ "$lang" == "ru" ]; then
        prompt_domain="Введите доменное имя: "
        prompt_domains="Введите доменные имена через пробел: "
        searching_ip="Поиск IP-адреса для домена $domain... "
        ip_found="Найден IP-адрес: $ip_address"
        ip_not_found="Не удалось найти IP-адрес для домена $domain."
        searching_subdomains="Поиск поддоменов для $domain... "
        subdomains_found="Найдены поддомены!"
        subdomains_not_found="Поддомены не найдены."
        scanning_ports="Сканирование портов для IP-адреса $ip_address... "
        ports_found="Найдены открытые порты!"
        ports_not_found="Открытые порты не найдены."
        final_info="=== Итоговая информация ==="
        domain_label="Домен:"
        ip_label="IP-адрес:"
        subdomains_label="=== Найденные поддомены ==="
        ports_label="=== Открытые порты и службы ==="
        os_label="=== Информация об операционной системе ==="
        os_not_found="Информация об операционной системе не найдена."
    else
        prompt_domain="Enter domain name: "
        prompt_domains="Enter domain names separated by space: "
        searching_ip="Searching IP address for domain $domain... "
        ip_found="Found IP address: $ip_address"
        ip_not_found="Failed to find IP address for domain $domain."
        searching_subdomains="Searching subdomains for $domain... "
        subdomains_found="Subdomains found!"
        subdomains_not_found="No subdomains found."
        scanning_ports="Scanning ports for IP address $ip_address... "
        ports_found="Open ports found!"
        ports_not_found="No open ports found."
        final_info="=== Final Information ==="
        domain_label="Domain:"
        ip_label="IP address:"
        subdomains_label="=== Found Subdomains ==="
        ports_label="=== Open Ports and Services ==="
        os_label="=== Operating System Information ==="
        os_not_found="No operating system information found."
    fi
}

# Функция для сканирования одного домена
scan_single_domain() {
    local domain=$1
    echo -n "$searching_ip"
    dig +short $domain > /tmp/ip_address.txt &
    spinner $!
    ip_address=$(cat /tmp/ip_address.txt)
    rm -f /tmp/ip_address.txt

    if [ -z "$ip_address" ]; then
        echo -e "\n$ip_not_found"
        return
    else
        echo -e "\n$ip_found"
    fi

    echo -n "$searching_subdomains"
    subfinder -d $domain -silent > /tmp/subdomains.txt &
    spinner $!
    subdomains=$(cat /tmp/subdomains.txt)
    rm -f /tmp/subdomains.txt

    if [ -z "$subdomains" ]; then
        echo -e "\n$subdomains_not_found"
    else
        echo -e "\n$subdomains_found"
    fi

    echo -n "$scanning_ports"
    echo "$sudo_password" | sudo -S nmap -p- -sV -O --open $ip_address > /tmp/nmap_output.txt 2>/dev/null &
    spinner $!
    nmap_output=$(cat /tmp/nmap_output.txt)
    rm -f /tmp/nmap_output.txt

    open_ports=$(echo "$nmap_output" | grep '^[0-9]' | awk '{print "Порт: " $1, "Служба: " $3, "Версия: " $4, $5}' | tr '\n' ';' | sed 's/;$//')
    os_info=$(echo "$nmap_output" | grep -i "OS details" | sed 's/OS details: //')

    if [ -z "$open_ports" ]; then
        echo -e "\n$ports_not_found"
    else
        echo -e "\n$ports_found"
    fi

    # Сохраняем результаты
    results+=("$domain" "$ip_address" "$subdomains" "$open_ports" "$os_info")
}

# Функция для сканирования нескольких доменов
scan_multiple_domains() {
    local domains=("$@")
    for domain in "${domains[@]}"; do
        echo -n "$searching_ip"
        dig +short $domain > /tmp/ip_address.txt &
        spinner $!
        ip_address=$(cat /tmp/ip_address.txt)
        rm -f /tmp/ip_address.txt

        if [ -z "$ip_address" ]; then
            echo -e "\n$ip_not_found"
            continue
        else
            echo -e "\n$ip_found"
        fi

        echo -n "$searching_subdomains"
        subfinder -d $domain -silent > /tmp/subdomains.txt &
        spinner $!
        subdomains=$(cat /tmp/subdomains.txt)
        rm -f /tmp/subdomains.txt

        if [ -z "$subdomains" ]; then
            echo -e "\n$subdomains_not_found"
        else
            echo -e "\n$subdomains_found"
        fi

        echo -n "$scanning_ports"
        echo "$sudo_password" | sudo -S nmap -p- -sV -O --open $ip_address > /tmp/nmap_output.txt 2>/dev/null &
        spinner $!
        nmap_output=$(cat /tmp/nmap_output.txt)
        rm -f /tmp/nmap_output.txt

        open_ports=$(echo "$nmap_output" | grep '^[0-9]' | awk '{print "Порт: " $1, "Служба: " $3, "Версия: " $4, $5}' | tr '\n' ';' | sed 's/;$//')
        os_info=$(echo "$nmap_output" | grep -i "OS details" | sed 's/OS details: //')

        if [ -z "$open_ports" ]; then
            echo -e "\n$ports_not_found"
        else
            echo -e "\n$ports_found"
        fi

        # Сохраняем результаты
        results+=("$domain" "$ip_address" "$subdomains" "$open_ports" "$os_info")
    done
}

# Основной скрипт
clear
logo
get_sudo_password
choose_language
localize

# Запрос количества доменов
read -p "Сколько доменов вы хотите просканировать? (1/несколько): " domain_count

if [ "$domain_count" == "1" ]; then
    read -p "$prompt_domain" domain
    results=()
    scan_single_domain "$domain"
else
    read -p "$prompt_domains" domains_input
    domains=($domains_input)
    results=()
    scan_multiple_domains "${domains[@]}"
fi

# Вывод итоговой информации
echo -e "\n$final_info"

if [ "$domain_count" == "1" ]; then
    echo "$domain_label ${results[0]}"
    echo "$ip_label ${results[1]}"
    echo -e "\n$subdomains_label"
    echo "${results[2]}"
    echo -e "\n$ports_label"
    echo "${results[3]}" | tr ';' '\n'
    echo -e "\n$os_label"
    echo "${results[4]}"
else
    # Вывод в колонки для нескольких доменов
    for ((i = 0; i < ${#results[@]}; i += 5)); do
        domain=${results[i]}
        ip=${results[i+1]}
        subdomains=${results[i+2]}
        ports=${results[i+3]}
        os=${results[i+4]}

        echo "Домен: $domain"
        echo "IP-адрес: $ip"
        echo -e "\n$subdomains_label"
        echo "$subdomains"
        echo -e "\n$ports_label"
        echo "$ports" | tr ';' '\n'
        echo -e "\n$os_label"
        echo "$os"
        echo "----------------------------------------"
    done
fi
