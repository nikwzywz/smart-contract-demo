// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IAavePool
 * @dev Интерфейс для взаимодействия с AAVE Pool
 */
interface IAavePool {
    /**
     * @dev Депозит токенов в AAVE
     * @param asset Адрес токена для депозита
     * @param amount Количество токенов
     * @param onBehalfOf Адрес, от имени которого делается депозит
     * @param referralCode Код реферала (0 для отсутствия)
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @dev Вывод токенов из AAVE
     * @param asset Адрес токена для вывода
     * @param amount Количество токенов
     * @param to Адрес получателя
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @dev Получение баланса aToken
     * @param user Адрес пользователя
     * @param asset Адрес базового токена
     * @return Баланс aToken
     */
    function balanceOf(address user, address asset) external view returns (uint256);

    /**
     * @dev Получение данных резерва для базового токена
     * @param asset Адрес базового токена
     * @return configuration Конфигурация резерва
     * @return liquidityIndex Индекс ликвидности
     * @return variableBorrowIndex Индекс переменного займа
     * @return currentLiquidityRate Текущая ставка ликвидности
     * @return currentVariableBorrowRate Текущая ставка переменного займа
     * @return currentStableBorrowRate Текущая ставка стабильного займа
     * @return lastUpdateTimestamp Время последнего обновления
     * @return aTokenAddress Адрес aToken
     * @return stableDebtTokenAddress Адрес токена стабильного долга
     * @return variableDebtTokenAddress Адрес токена переменного долга
     * @return interestRateStrategyAddress Адрес стратегии процентных ставок
     * @return id ID резерва
     */
    function getReserveData(address asset) external view returns (
        uint256 configuration,
        uint128 liquidityIndex,
        uint128 variableBorrowIndex,
        uint128 currentLiquidityRate,
        uint128 currentVariableBorrowRate,
        uint128 currentStableBorrowRate,
        uint40 lastUpdateTimestamp,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress,
        uint8 id
    );
} 