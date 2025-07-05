#!/bin/bash

# Скрипт для проверки баланса через Etherscan API v2
# Поддерживает Base network (chain_id = 8453)

# Загружаем переменные окружения
source load_env.sh

# Проверяем, что API ключ установлен
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Ошибка: ETHERSCAN_API_KEY не установлен в .env файле"
    exit 1
fi

# Адрес для проверки баланса (можно передать как аргумент)
ADDRESS=${1:-$DEPLOYER_ADDRESS}

if [ -z "$ADDRESS" ]; then
    echo "Ошибка: не указан адрес для проверки баланса"
    echo "Использование: ./check_balance.sh <адрес>"
    echo "Или установите DEPLOYER_ADDRESS в .env файле"
    exit 1
fi

echo "Проверяем баланс адреса: $ADDRESS"
echo "Сеть: Base (chain_id = 8453)"
echo "API: Etherscan v2"

# Выполняем запрос к Etherscan API v2
RESPONSE=$(curl -s "https://api.etherscan.io/v2/api?chainid=8453&module=account&action=balance&address=$ADDRESS&tag=latest&apikey=$ETHERSCAN_API_KEY")

echo "Ответ API:"
echo "$RESPONSE"

# Парсим ответ (если установлен jq)
if command -v jq &> /dev/null; then
    echo ""
    echo "Результат:"
    echo "$RESPONSE" | jq -r '.result'
else
    echo ""
    echo "Для лучшего отображения установите jq: sudo apt install jq"
fi 