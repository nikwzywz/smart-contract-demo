// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AaveFund} from "../src/AaveFund.sol";

contract AaveFundScript is Script {
    AaveFund public aaveFund;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Параметры для Base network
        address baseToken = vm.envAddress("BASE_TOKEN"); // USDC на Base
        address aavePool = vm.envAddress("AAVE_POOL"); // AAVE Pool на Base
        uint256 minInvestment = vm.envUint("MIN_INVESTMENT");
        uint256 buyFee = vm.envUint("BUY_FEE");
        uint256 sellFee = vm.envUint("SELL_FEE");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        
        console.log("Deploying AaveFund to Base network...");
        console.log("Deployer address:", deployer);
        console.log("Base token:", baseToken);
        console.log("Aave pool:", aavePool);
        console.log("Min investment:", minInvestment);
        console.log("Buy fee:", buyFee);
        console.log("Sell fee:", sellFee);
        console.log("Fee collector:", feeCollector);
        
        vm.startBroadcast(deployerPrivateKey);

        aaveFund = new AaveFund(
            baseToken,
            aavePool,
            minInvestment,
            buyFee,
            sellFee,
            feeCollector
        );
        
        console.log("AaveFund deployed at:", address(aaveFund));

        vm.stopBroadcast();
    }
} 