#!/bin/bash

# Скрипт для загрузки переменных окружения из .env файла
# Использование: source load_env.sh

if [ -f .env ]; then
    echo "Загружаем переменные окружения из .env файла..."
    export $(cat .env | grep -v '^#' | xargs)
    echo "Переменные окружения загружены!"
    echo "RPC_URL: $RPC_URL"
    echo "CHAIN_ID: $CHAIN_ID"
    echo "DEPLOYER_ADDRESS: $DEPLOYER_ADDRESS"
else
    echo "Ошибка: файл .env не найден!"
    echo "Создайте файл .env с вашими настройками"
    exit 1
fi 