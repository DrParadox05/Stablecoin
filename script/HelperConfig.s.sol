//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script{
    struct NetworkConfig{
        address WETHUSDPriceFeedAddress;
        address WBTCUSDPriceFeedAddress;
        address WBTC;
        address WETH;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor(){}

    function getSepoliaETHConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            WETHUSDPriceFeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            WBTCUSDPriceFeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            WETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            WBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
    
    function getOrCreateAnvilETHConfig() public returns(NetworkConfig memory){
        if(activeNetworkConfig.WETHUSDPriceFeedAddress == address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast
    }
}
