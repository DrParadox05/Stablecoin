//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSC is Script{
    function run() external returns(DecentralizedStablecoin, DSCEngine){
        vm.startPrank();
        DecentralizedStablecoin dsc = new DecentralizedStablecoin();
        vm.stopPrank();
    }
}