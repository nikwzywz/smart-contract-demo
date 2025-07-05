// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BaseFund.sol";
import "./interfaces/IAavePool.sol";
import "./interfaces/IAToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/FundMath.sol";

/**
 * @title AaveFund
 * @dev Фонд, который инвестирует средства в AAVE лендинг
 */
contract AaveFund is BaseFund {
    using SafeERC20 for IERC20;

    // AAVE Pool контракт
    IAavePool public immutable aavePool;
    
    // aToken для базового токена
    IAToken public aToken;
    
    // События
    event AaveDeposit(uint256 amount);
    event AaveWithdraw(uint256 amount);
    event ATokenSet(address aToken);

    /**
     * @dev Конструктор AAVE фонда
     * @param _baseToken Адрес базового токена (например, USDC)
     * @param _aavePool Адрес AAVE Pool контракта
     * @param _minInvestment Минимальная сумма инвестиций
     * @param _buyFee Комиссия за покупку паев в базовых пунктах
     * @param _sellFee Комиссия за продажу паев в базовых пунктах
     * @param _feeCollector Адрес для сбора комиссий
     */
    constructor(
        address _baseToken,
        address _aavePool,
        uint256 _minInvestment,
        uint256 _buyFee,
        uint256 _sellFee,
        address _feeCollector
    ) BaseFund(_baseToken, _minInvestment, _buyFee, _sellFee, _feeCollector) Ownable(msg.sender) {
        require(_aavePool != address(0), "AaveFund: invalid aave pool");
        aavePool = IAavePool(_aavePool);
        
        // Получаем адрес aToken для базового токена
        _setAToken();
    }

    /**
     * @dev Получение Equity фонда (общей стоимости активов)
     * @return Общая стоимость активов в базовом токене
     */
    function getEquity() public view override returns (uint256) {
        uint256 aTokenBalance = 0;
        if (address(aToken) != address(0)) {
            aTokenBalance = aToken.balanceOf(address(this));
        }
        
        // Добавляем баланс базового токена в контракте
        uint256 baseTokenBalance = baseToken.balanceOf(address(this));
        
        return aTokenBalance + baseTokenBalance;
    }

    /**
     * @dev Переопределяем buyShares для автоматического депозита в AAVE
     * @param amount Количество базовых токенов для инвестиции
     */
    function buyShares(uint256 amount) external override {
        require(amount >= minInvestment, "AaveFund: amount below minimum");
        
        // Рассчитываем комиссию за покупку
        uint256 buyFeeAmount = FundMath.calculateFee(amount, buyFee);
        
        // Сохраняем Equity до операции
        _saveEquityBeforeOperation();
        
        // Переводим токены от инвестора в фонд
        require(
            baseToken.transferFrom(msg.sender, address(this), amount),
            "AaveFund: transfer failed"
        );
        
        // Переводим комиссию за покупку на feeCollector
        if (buyFeeAmount > 0) {
            require(
                baseToken.transfer(feeCollector, buyFeeAmount),
                "AaveFund: buy fee transfer failed"
            );
        }
        
        // Получаем реальное изменение Equity (после вычета комиссии)
        uint256 equityChange = _getEquityChange();
        
        // Рассчитываем количество паев для покупки и новую цену пая на основе реального изменения Equity
        (uint256 sharesToMint, uint256 newSharePrice) = FundMath.calculateSharesToMintAndPrice(
            equityChange, 
            _getEquityBeforeOperation(), 
            totalShares, 
            baseTokenDecimals
        );
        
        // Обновляем последнюю известную цену пая
        lastSharePrice = newSharePrice;
        
        // Минтим паи инвестору
        sharesOf[msg.sender] = sharesOf[msg.sender] + sharesToMint;
        totalShares = totalShares + sharesToMint;
        
        emit SharesBuy(msg.sender, amount, sharesToMint, equityChange, buyFeeAmount);
        emit SharePriceUpdated(newSharePrice);
        
        // Автоматически депозим новые средства в AAVE
        _depositToAave();
    }

    /**
     * @dev Переопределяем sellShares для автоматического вывода из AAVE при необходимости
     * @param shares Количество паев для продажи
     */
    function sellShares(uint256 shares) external override {
        require(shares > 0, "AaveFund: shares must be positive");
        require(sharesOf[msg.sender] >= shares, "AaveFund: insufficient shares");
        
        // Рассчитываем сумму к выплате и новую цену пая
        (uint256 amountToPay, uint256 newSharePrice) = FundMath.calculateRedemptionAmountAndPrice(
            shares, 
            getEquity(), 
            totalShares, 
            getSharePrice(), 
            baseTokenDecimals
        );
        
        // Проверяем, достаточно ли базового токена для выплаты
        uint256 baseTokenBalance = baseToken.balanceOf(address(this));
        
        // Если недостаточно базового токена, выводим из AAVE
        if (baseTokenBalance < amountToPay) {
            uint256 needToWithdraw = amountToPay - baseTokenBalance;
            _withdrawFromAave(needToWithdraw);
        }
        
        // Рассчитываем комиссию за продажу
        uint256 sellFeeAmount = FundMath.calculateFee(amountToPay, sellFee);
        uint256 amountAfterFee = amountToPay - sellFeeAmount;
        
        // Обновляем последнюю известную цену пая
        lastSharePrice = newSharePrice;
        
        // Сжигаем паи
        sharesOf[msg.sender] = sharesOf[msg.sender] - shares;
        totalShares = totalShares - shares;
        
        // Переводим комиссию за продажу на feeCollector
        if (sellFeeAmount > 0) {
            require(
                baseToken.transfer(feeCollector, sellFeeAmount),
                "AaveFund: sell fee transfer failed"
            );
        }
        
        // Выплачиваем средства инвестору (после вычета комиссии)
        require(
            baseToken.transfer(msg.sender, amountAfterFee),
            "AaveFund: transfer failed"
        );
        
        emit SharesSell(msg.sender, shares, amountAfterFee, sellFeeAmount);
        emit SharePriceUpdated(newSharePrice);
    }

    /**
     * @dev Депозит средств в AAVE
     * @param amount Количество токенов для депозита
     */
    function depositToAave(uint256 amount) external onlyOwner {
        _depositToAave(amount);
    }

    /**
     * @dev Вывод средств из AAVE
     * @param amount Количество токенов для вывода
     */
    function withdrawFromAave(uint256 amount) external onlyOwner {
        _withdrawFromAave(amount);
    }

    /**
     * @dev Получение баланса в AAVE
     * @return Баланс aToken
     */
    function getAaveBalance() external view returns (uint256) {
        if (address(aToken) == address(0)) {
            return 0;
        }
        return aToken.balanceOf(address(this));
    }

    /**
     * @dev Получение текущей процентной ставки AAVE
     * @return Текущая процентная ставка (в базовых пунктах)
     */
    function getCurrentAaveRate() external view returns (uint256) {
        if (address(aToken) == address(0)) {
            return 0;
        }
        
        // Получаем данные резерва из AAVE Pool
        (,,,, uint128 currentLiquidityRate,,,,,,,) = aavePool.getReserveData(address(baseToken));
        
        return currentLiquidityRate;
    }

    /**
     * @dev Установка адреса aToken (если не установлен автоматически)
     * @param _aToken Адрес aToken
     */
    function setAToken(address _aToken) external onlyOwner {
        require(_aToken != address(0), "AaveFund: invalid aToken address");
        aToken = IAToken(_aToken);
        emit ATokenSet(_aToken);
    }

    // Внутренние функции

    /**
     * @dev Автоматический депозит всех доступных средств в AAVE
     */
    function _depositToAave() internal {
        uint256 balance = baseToken.balanceOf(address(this));
        if (balance > 0 && address(aToken) != address(0)) {
            _depositToAave(balance);
        }
    }

    /**
     * @dev Депозит указанной суммы в AAVE
     * @param amount Количество токенов для депозита
     */
    function _depositToAave(uint256 amount) internal {
        require(amount > 0, "AaveFund: amount must be positive");
        require(address(aToken) != address(0), "AaveFund: aToken not set");
        
        // Разрешаем AAVE Pool тратить наши токены
        baseToken.approve(address(aavePool), amount);
        
        // Депозим в AAVE
        aavePool.supply(address(baseToken), amount, address(this), 0);
        
        emit AaveDeposit(amount);
    }

    /**
     * @dev Вывод средств из AAVE
     * @param amount Количество токенов для вывода
     */
    function _withdrawFromAave(uint256 amount) internal {
        require(amount > 0, "AaveFund: amount must be positive");
        require(address(aToken) != address(0), "AaveFund: aToken not set");
        
        // Выводим из AAVE
        aavePool.withdraw(address(baseToken), amount, address(this));
        
        emit AaveWithdraw(amount);
    }

    /**
     * @dev Установка адреса aToken из AAVE Pool
     */
    function _setAToken() internal {
        try aavePool.getReserveData(address(baseToken)) returns (
            uint256,
            uint128,
            uint128,
            uint128,
            uint128,
            uint128,
            uint40,
            address aTokenAddress,
            address,
            address,
            address,
            uint8
        ) {
            if (aTokenAddress != address(0)) {
                aToken = IAToken(aTokenAddress);
                emit ATokenSet(aTokenAddress);
            }
        } catch {
            // Если не удалось получить адрес aToken, оставляем как есть
        }
    }
} 