//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {

    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address WETHUSDPriceFeedAddress;
        address WBTCUSDPriceFeedAddress;
        address WBTC;
        address WETH;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaETHConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        return
            sepoliaNetworkConfig = NetworkConfig({
                WETHUSDPriceFeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                WBTCUSDPriceFeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                WETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
                WBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
                deployerKey: privateKey
            });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.WETHUSDPriceFeedAddress != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUSDPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        ERC20Mock WETHMock = new ERC20Mock();

        MockV3Aggregator btcUSDPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock WBTCMock = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            WETHUSDPriceFeedAddress: address(ethUSDPriceFeed),
            WBTCUSDPriceFeedAddress: address(btcUSDPriceFeed),
            WETH: address(WETHMock),
            WBTC: address(WBTCMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });

        return anvilNetworkConfig;
    }
}
