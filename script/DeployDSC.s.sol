//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script{
    
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(DecentralizedStablecoin, DSCEngine, HelperConfig){
        HelperConfig config = new HelperConfig();

        (address WETHUSDPriceFeedAddress, address WBTCUSDPriceFeedAddress, address WBTC, address WETH, uint256 deployerKey) = config.activeNetworkConfig();
        tokenAddresses = [WETH, WBTC];
        priceFeedAddresses = [WETHUSDPriceFeedAddress, WBTCUSDPriceFeedAddress];

        vm.startBroadcast(deployerKey);
        DecentralizedStablecoin dsc = new DecentralizedStablecoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc, engine, config);
    }
}