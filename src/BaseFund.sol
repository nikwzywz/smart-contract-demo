// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/FundMath.sol";

// Интерфейс для получения decimals токена
interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title BaseFund
 * @dev Базовый контракт для инвестиционных фондов
 * Содержит основную логику для управления паями фонда
 */
abstract contract BaseFund is ReentrancyGuard, Ownable {
    using FundMath for uint256;

    // Базовый токен фонда (например, USDC, USDT, DAI)
    IERC20 public immutable baseToken;
    
    // Точность базового токена (decimals)
    uint8 public immutable baseTokenDecimals;
    
    // Общее количество паев фонда
    uint256 public totalShares;
    
    // Последняя известная цена пая (для случая когда все паи выведены)
    uint256 public lastSharePrice;
    
    // Equity фонда до операции (для расчета реального изменения)
    uint256 private equityBeforeOperation;
    
    // Минимальная сумма для покупки паев
    uint256 public minInvestment;
    
    // Комиссия за покупку паев (в базовых пунктах, 100 = 1%)
    uint256 public buyFee;
    
    // Комиссия за продажу паев (в базовых пунктах, 100 = 1%)
    uint256 public sellFee;
    
    // Адрес для сбора комиссий
    address public feeCollector;
    
    // Мэппинг инвесторов к количеству их паев
    mapping(address => uint256) public sharesOf;
    
    // События
    event SharesBuy(address indexed investor, uint256 amount, uint256 shares, uint256 equityChange, uint256 buyFee);
    event SharesSell(address indexed investor, uint256 shares, uint256 amount, uint256 sellFee);
    event SharePriceUpdated(uint256 newSharePrice);
    event BuyFeeUpdated(uint256 newBuyFee);
    event SellFeeUpdated(uint256 newSellFee);
    event MinInvestmentUpdated(uint256 newMinInvestment);
    event FeeCollectorUpdated(address newFeeCollector);

    /**
     * @dev Конструктор базового фонда
     * @param _baseToken Адрес базового токена фонда
     * @param _minInvestment Минимальная сумма инвестиций
     * @param _buyFee Комиссия за покупку паев в базовых пунктах
     * @param _sellFee Комиссия за продажу паев в базовых пунктах
     * @param _feeCollector Адрес для сбора комиссий
     */
    constructor(
        address _baseToken,
        uint256 _minInvestment,
        uint256 _buyFee,
        uint256 _sellFee,
        address _feeCollector
    ) {
        require(_baseToken != address(0), "BaseFund: invalid base token");
        require(_feeCollector != address(0), "BaseFund: invalid fee collector");
        require(_buyFee <= 1000, "BaseFund: buy fee too high"); // Максимум 10%
        require(_sellFee <= 1000, "BaseFund: sell fee too high"); // Максимум 10%
        
        baseToken = IERC20(_baseToken);
        baseTokenDecimals = IERC20Metadata(_baseToken).decimals();
        lastSharePrice = 10 ** baseTokenDecimals; // Инициализируем цену пая как 1 базовый токен с правильной точностью
        minInvestment = _minInvestment;
        buyFee = _buyFee;
        sellFee = _sellFee;
        feeCollector = _feeCollector;
    }

    /**
     * @dev Абстрактный метод для получения Equity фонда (общей стоимости активов)
     * @return Общая стоимость активов фонда в базовом токене
     */
    function getEquity() public view virtual returns (uint256);

    /**
     * @dev Сохраняет текущее Equity фонда перед операцией
     */
    function _saveEquityBeforeOperation() internal {
        equityBeforeOperation = getEquity();
    }

    /**
     * @dev Получает сохраненное Equity фонда до операции
     * @return Equity фонда до операции
     */
    function _getEquityBeforeOperation() internal view returns (uint256) {
        return equityBeforeOperation;
    }

    /**
     * @dev Рассчитывает реальное изменение Equity фонда
     * @return Разница между текущим и предыдущим Equity
     */
    function _getEquityChange() internal view returns (uint256) {
        return getEquity() - equityBeforeOperation;
    }

    /**
     * @dev Рассчитывает цену пая
     * @return Цена одного пая в базовом токене
     */
    function getSharePrice() public view returns (uint256) {
        return FundMath.calculateSharePrice(getEquity(), totalShares, lastSharePrice, baseTokenDecimals);
    }

    /**
     * @dev Покупка паев фонда
     * @param amount Количество базовых токенов для инвестиции
     */
    function buyShares(uint256 amount) external virtual nonReentrant {
        require(amount >= minInvestment, "BaseFund: amount below minimum");
        
        // Рассчитываем комиссию за покупку
        uint256 buyFeeAmount = FundMath.calculateFee(amount, buyFee);
        
        // Сохраняем Equity до операции
        _saveEquityBeforeOperation();
        
        // Переводим токены от инвестора в фонд
        require(
            baseToken.transferFrom(msg.sender, address(this), amount),
            "BaseFund: transfer failed"
        );
        
        // Переводим комиссию за покупку на feeCollector
        if (buyFeeAmount > 0) {
            require(
                baseToken.transfer(feeCollector, buyFeeAmount),
                "BaseFund: buy fee transfer failed"
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
    }

    /**
     * @dev Продажа паев фонда
     * @param shares Количество паев для продажи
     */
    function sellShares(uint256 shares) external virtual nonReentrant {
        require(shares > 0, "BaseFund: shares must be positive");
        require(sharesOf[msg.sender] >= shares, "BaseFund: insufficient shares");
        
        // Рассчитываем сумму к выплате и новую цену пая
        (uint256 amountToPay, uint256 newSharePrice) = FundMath.calculateRedemptionAmountAndPrice(
            shares, 
            getEquity(), 
            totalShares, 
            getSharePrice(), 
            baseTokenDecimals
        );
        
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
                "BaseFund: sell fee transfer failed"
            );
        }
        
        // Выплачиваем средства инвестору (после вычета комиссии)
        require(
            baseToken.transfer(msg.sender, amountAfterFee),
            "BaseFund: transfer failed"
        );
        
        emit SharesSell(msg.sender, shares, amountAfterFee, sellFeeAmount);
        emit SharePriceUpdated(newSharePrice);
    }

    /**
     * @dev Получение баланса паев инвестора
     * @param investor Адрес инвестора
     * @return Количество паев
     */
    function getSharesBalance(address investor) external view returns (uint256) {
        return sharesOf[investor];
    }

    /**
     * @dev Получение стоимости паев инвестора в базовом токене
     * @param investor Адрес инвестора
     * @return Стоимость паев в базовом токене
     */
    function getSharesValue(address investor) external view returns (uint256) {
        return FundMath.calculateSharesValue(sharesOf[investor], getSharePrice(), baseTokenDecimals);
    }

    /**
     * @dev Получение последней известной цены пая
     * @return Последняя известная цена пая
     */
    function getLastSharePrice() external view returns (uint256) {
        return lastSharePrice;
    }

    // Административные функции

    /**
     * @dev Обновление минимальной суммы инвестиций
     * @param _minInvestment Новая минимальная сумма
     */
    function setMinInvestment(uint256 _minInvestment) external onlyOwner {
        minInvestment = _minInvestment;
        emit MinInvestmentUpdated(_minInvestment);
    }

    /**
     * @dev Обновление комиссии за покупку паев
     * @param _buyFee Новая комиссия в базовых пунктах
     */
    function setBuyFee(uint256 _buyFee) external onlyOwner {
        require(_buyFee <= 1000, "BaseFund: buy fee too high");
        buyFee = _buyFee;
        emit BuyFeeUpdated(_buyFee);
    }

    /**
     * @dev Обновление комиссии за продажу паев
     * @param _sellFee Новая комиссия в базовых пунктах
     */
    function setSellFee(uint256 _sellFee) external onlyOwner {
        require(_sellFee <= 1000, "BaseFund: sell fee too high");
        sellFee = _sellFee;
        emit SellFeeUpdated(_sellFee);
    }

    /**
     * @dev Обновление адреса для сбора комиссий
     * @param _feeCollector Новый адрес
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "BaseFund: invalid fee collector");
        feeCollector = _feeCollector;
        emit FeeCollectorUpdated(_feeCollector);
    }


} 