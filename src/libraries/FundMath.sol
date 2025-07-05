// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title FundMath
 * @dev Библиотека для математических расчётов инвестиционных фондов
 */
library FundMath {

    /**
     * @dev Рассчитывает цену пая на основе Equity и общего количества паев
     * @param equity Общая стоимость активов фонда в базовом токене
     * @param totalShares Общее количество паев фонда
     * @param lastSharePrice Последняя известная цена пая (используется когда totalShares = 0)
     * @param decimals Точность базового токена
     * @return Цена одного пая в базовом токене (с точностью decimals)
     */
    function calculateSharePrice(uint256 equity, uint256 totalShares, uint256 lastSharePrice, uint8 decimals) 
        internal 
        pure 
        returns (uint256) 
    {
        if (totalShares == 0) {
            return lastSharePrice; // Возвращаем последнюю известную цену
        }
        return equity * (10 ** decimals) / totalShares;
    }

    /**
     * @dev Рассчитывает цену пая на основе Equity и общего количества паев (без lastSharePrice)
     * @param equity Общая стоимость активов фонда в базовом токене
     * @param totalShares Общее количество паев фонда
     * @param decimals Точность базового токена
     * @return Цена одного пая в базовом токене (с точностью decimals)
     */
    function calculateSharePrice(uint256 equity, uint256 totalShares, uint8 decimals) 
        internal 
        pure 
        returns (uint256) 
    {
        if (totalShares == 0) {
            return 10 ** decimals; // 1 пай = 1 базовый токен при инициализации
        }
        return equity * (10 ** decimals) / totalShares;
    }

    /**
     * @dev Рассчитывает количество паев для покупки и новую цену пая
     * @param amount Количество базовых токенов для инвестиции
     * @param equity Общая стоимость активов фонда
     * @param totalShares Общее количество паев фонда
     * @param decimals Точность базового токена
     * @return sharesToMint Количество паев для покупки
     * @return newSharePrice Новая цена пая
     */
    function calculateSharesToMintAndPrice(
        uint256 amount, 
        uint256 equity, 
        uint256 totalShares,
        uint8 decimals
    ) 
        internal 
        pure 
        returns (uint256 sharesToMint, uint256 newSharePrice) 
    {
        if (totalShares == 0) {
            // Первая инвестиция - 1 пай = 1 базовый токен
            sharesToMint = amount;
            newSharePrice = 10 ** decimals; // 1 пай = 1 базовый токен
        } else {
            // Последующие инвестиции - по текущей цене пая
            sharesToMint = amount * totalShares / equity;
            newSharePrice = (equity + amount) * (10 ** decimals) / (totalShares + sharesToMint);
        }
    }

    /**
     * @dev Рассчитывает количество паев для покупки на основе инвестируемой суммы
     * @param amount Количество базовых токенов для инвестиции
     * @param equity Общая стоимость активов фонда
     * @param totalShares Общее количество паев фонда
     * @return Количество паев для покупки
     */
    function calculateSharesToMint(
        uint256 amount, 
        uint256 equity, 
        uint256 totalShares
    ) 
        internal 
        pure 
        returns (uint256) 
    {
        if (totalShares == 0) {
            // Первая инвестиция - 1 пай = 1 базовый токен
            return amount;
        } else {
            // Последующие инвестиции - по текущей цене пая
            return amount * totalShares / equity;
        }
    }

    /**
     * @dev Рассчитывает сумму к выплате и новую цену пая при продаже
     * @param shares Количество паев для продажи
     * @param equity Общая стоимость активов фонда
     * @param totalShares Общее количество паев фонда
     * @param sharePrice Текущая цена пая
     * @param decimals Точность базового токена
     * @return amountToPay Сумма к выплате в базовом токене
     * @return newSharePrice Новая цена пая
     */
    function calculateRedemptionAmountAndPrice(
        uint256 shares, 
        uint256 equity, 
        uint256 totalShares,
        uint256 sharePrice,
        uint8 decimals
    ) 
        internal 
        pure 
        returns (uint256 amountToPay, uint256 newSharePrice) 
    {
        amountToPay = shares * sharePrice / (10 ** decimals);
        
        if (totalShares > shares) {
            newSharePrice = equity * (10 ** decimals) / (totalShares - shares);
        } else {
            newSharePrice = sharePrice; // Сохраняем текущую цену если все паи проданы
        }
    }

    /**
     * @dev Рассчитывает сумму к выплате при продаже паев
     * @param shares Количество паев для продажи
     * @param sharePrice Цена одного пая
     * @param decimals Точность базового токена
     * @return Сумма к выплате в базовом токене
     */
    function calculateRedemptionAmount(uint256 shares, uint256 sharePrice, uint8 decimals) 
        internal 
        pure 
        returns (uint256) 
    {
        return shares * sharePrice / (10 ** decimals);
    }

    /**
     * @dev Рассчитывает стоимость паев инвестора в базовом токене
     * @param shares Количество паев инвестора
     * @param sharePrice Цена одного пая
     * @param decimals Точность базового токена
     * @return Стоимость паев в базовом токене
     */
    function calculateSharesValue(uint256 shares, uint256 sharePrice, uint8 decimals) 
        internal 
        pure 
        returns (uint256) 
    {
        return shares * sharePrice / (10 ** decimals);
    }

    /**
     * @dev Рассчитывает комиссию фонда
     * @param amount Сумма для расчёта комиссии
     * @param feeRate Комиссия в базовых пунктах (100 = 1%)
     * @return Сумма комиссии
     */
    function calculateFee(uint256 amount, uint256 feeRate) 
        internal 
        pure 
        returns (uint256) 
    {
        return amount * feeRate / 10000;
    }

    /**
     * @dev Рассчитывает сумму после вычета комиссии
     * @param amount Исходная сумма
     * @param feeRate Комиссия в базовых пунктах (100 = 1%)
     * @return Сумма после вычета комиссии
     */
    function calculateAmountAfterFee(uint256 amount, uint256 feeRate) 
        internal 
        pure 
        returns (uint256) 
    {
        return amount - calculateFee(amount, feeRate);
    }
} 