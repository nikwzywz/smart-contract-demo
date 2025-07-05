// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IAToken
 * @dev Интерфейс для aToken (токен AAVE)
 */
interface IAToken {
    /**
     * @dev Получение баланса aToken
     * @param account Адрес аккаунта
     * @return Баланс aToken
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Получение базового токена
     * @return Адрес базового токена
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    /**
     * @dev Получение общей суммы заимствований
     * @return Общая сумма заимствований
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Получение масштаба токена
     * @return Масштаб токена
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Получение символа токена
     * @return Символ токена
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Получение имени токена
     * @return Имя токена
     */
    function name() external view returns (string memory);
} 