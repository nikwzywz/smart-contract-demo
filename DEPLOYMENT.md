# Деплой контракта на Base Network

## Настройка окружения

### 1. Настройка .env файла

Создайте файл `.env` со следующими переменными:

```bash
# Приватный ключ для деплоя контрактов
PRIVATE_KEY=your_private_key_here

# RPC URL для сети Base (mainnet)
RPC_URL=https://mainnet.base.org

# Etherscan API ключ для верификации контрактов (v2 API)
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Адрес кошелька для деплоя
DEPLOYER_ADDRESS=your_wallet_address_here

# Настройки газа для Base
GAS_LIMIT=3000000
GAS_PRICE=1000000000

# Chain ID для Base
CHAIN_ID=8453
```

### 2. Получение Etherscan API ключа

1. Зарегистрируйтесь на [Etherscan](https://etherscan.io/)
2. Перейдите в раздел API Keys
3. Создайте новый API ключ
4. Добавьте ключ в переменную `ETHERSCAN_API_KEY` в файле `.env`

## Деплой контракта

### 1. Загрузка переменных окружения

```bash
source load_env.sh
```

### 2. Проверка баланса

```bash
./check_balance.sh <адрес_кошелька>
```

### 3. Деплой контракта

```bash
# Деплой на Base mainnet
forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

# Или используя профиль
forge script script/Counter.s.sol:CounterScript --profile base --broadcast --verify
```

## Проверка контракта

После деплоя контракт будет автоматически верифицирован через Etherscan API v2.

### Проверка через Etherscan

1. Перейдите на [BaseScan](https://basescan.org/)
2. Найдите ваш контракт по адресу
3. Проверьте, что код верифицирован

## Полезные команды

### Проверка баланса через API

```bash
curl "https://api.etherscan.io/v2/api?chainid=8453&module=account&action=balance&address=YOUR_ADDRESS&tag=latest&apikey=YOUR_API_KEY"
```

### Получение газа

```bash
curl "https://api.etherscan.io/v2/api?chainid=8453&module=gastracker&action=gasoracle&apikey=YOUR_API_KEY"
```

## Поддерживаемые сети

- **Base Mainnet**: chain_id = 8453
- **Base Sepolia**: chain_id = 84532 (для тестирования)

## Безопасность

⚠️ **ВАЖНО**: Никогда не коммитьте файл `.env` в Git репозиторий!
Файл `.env` уже добавлен в `.gitignore` для безопасности. 