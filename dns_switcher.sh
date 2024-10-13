#!/bin/bash

declare -a DNS_SERVERS=(
	"RU - Яндекс|77.88.8.8,77.88.8.1"
	"US - NextDNS|45.90.28.230,45.90.30.230"
	"AU - Cloudflare|1.0.0.1,1.1.1.1"
	"US - GoogleDNS|8.8.8.8,8.8.4.4"
	"US - OpenDNS|208.67.222.222,208.67.220.220"
	"US - Quad9|9.9.9.10,149.112.112.10"
	"RU - AdGuard DNS|94.140.15.15,94.140.14.14"
	
)

INTERFACE=$(ip route | awk '/^default/ {print $5}')

if [[ -z "$INTERFACE" ]]; then
    echo "Невозможно обнаружить сетевой интерфейс по умолчанию."
    exit 1
fi

display_dns_servers() {
	echo "Выберите сервер DNS для установки:"
	for i in "${!DNS_SERVERS[@]}"; do
		IFS="|" read -ra DNS <<< "${DNS_SERVERS[$i]}"
		echo "[$i] ${DNS[0]}"
	done
}

validate_input() {
	local selection="$1"
	if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 0 && "$selection" -lt "${#DNS_SERVERS[@]}" ]]; then
		return 0
	else
		echo "Неверный выбор. Пожалуйста, попробуйте еще раз."
		return 1
	fi
}

set_dns_servers() {
	local servers="$1"
	echo "Установка DNS Server на $servers"
	if nmcli dev modify $INTERFACE ipv4.dns "$servers"; then
		echo "Перезагрузка сервиса сетевого менеджера ..."
		if sudo systemctl restart systemd-networkd; then
			echo "Успешно."
			return 0
		else
			echo "Не удалось перезапустить службу сетевого менеджера."
			return 1
		fi
	else
		echo "Не удалось установить DNS -серверы."
		return 1
	fi
}

clear_dns_servers() {
	echo "Очистка сервера DNS ..."
	if nmcli dev modify $INTERFACE ipv4.dns ""; then
		echo "Перезагрузка сервиса сетевого менеджера ..."
		if sudo systemctl restart systemd-networkd; then
			echo "Успешно."
			return 0
		else
			echo "Не удалось перезапустить службу сетевого менеджера."
			return 1
		fi
	else
		echo "Не удалось очистить серверы DNS."
		return 1
	fi
}

echo "Выберите действие:"
echo "[1] Выбрать DNS сервер"
echo "[2] Очистить запись DNS сервера"
read -p "Введите число (1-2): " action

case "$action" in
	1)
		display_dns_servers
		while true; do
			read -p "Введите число (0-${#DNS_SERVERS[@]}): " selection
			if validate_input "$selection"; then
				IFS="|" read -ra DNS <<< "${DNS_SERVERS[$selection]}"
				SERVERS="${DNS[1]}"
				if set_dns_servers "$SERVERS"; then
					break
				else
					echo "Не удалось установить DNS-сервер. Пожалуйста, попробуйте еще раз."
				fi
			fi
		done
		;;
	2)
		if clear_dns_servers; then
			exit 0
		else
			echo "Не удалось очистить серверы DNS. Пожалуйста, попробуйте еще раз."
			exit 1
		fi
		;;
	*)
		echo "Неверный выбор. Выход."
		exit 1
		;;
esac
