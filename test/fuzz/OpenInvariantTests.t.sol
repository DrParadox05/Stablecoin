// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStablecoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external{
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (,,weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(dsc, engine);
        targetContract(address(handler));
    }

    function invariant_DSCMustBeLessThanTotalSupply() public view{
        uint256 DSCtotalSupply = dsc.totalSupply();
        uint256 wethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 wbtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        uint256 wethUSDValue = engine.getUSDValue(weth, wethDeposited);
        uint256 wbtcUSDValue = engine.getUSDValue(wbtc, wbtcDeposited);
        assert(wethUSDValue + wbtcUSDValue >= DSCtotalSupply);
    }

    
}