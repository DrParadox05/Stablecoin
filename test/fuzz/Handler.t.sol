// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test{

    DecentralizedStablecoin dsc;
    DSCEngine engine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DecentralizedStablecoin _dsc, DSCEngine _engine){
        dsc = _dsc;
        engine = _engine;

        address[] memory collateralTokens = engine.getCollateralTokenAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(uint256 _collateralSeed, uint256 _collateralAmount) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        _collateralAmount = bound(_collateralAmount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _collateralAmount);
        collateral.approve(address(engine), _collateralAmount);
        engine.depositCollateral(address(collateral), _collateralAmount);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 _collateralSeed, uint256 _collateralAmount) public{
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalance(msg.sender, address(collateral));
        _collateralAmount = bound(_collateralAmount, 0, maxCollateralToRedeem);
        if(_collateralAmount == 0){
            return;
        }
        vm.prank(msg.sender);
        engine.redeemCollateral(address(collateral), _collateralAmount);
    }

    function _getCollateralFromSeed(uint256 _collateralSeed) private view returns(ERC20Mock){
        if(_collateralSeed % 2 == 0){
            return weth;
        }
        else{
            return wbtc;
        }
    }




}