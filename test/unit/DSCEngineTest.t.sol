//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "forge-std/console2.sol";

contract DSCEngineTest is Test {
    DecentralizedStablecoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;
    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant INITIAL_WETH_AMOUNT = 10 ether;
    address[] public priceFeedAddress;
    address[] public tokenAddress;

    function setUp() external {
        // This function can only be public or external and it will execute before each test function is executed
        DeployDSC deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = config
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, INITIAL_WETH_AMOUNT);
    }

    // function testGetUSDValue() public {
    //     uint256 ethAmount = 15e18;
    //     uint256 expectedUsd = 30_000e18;
    //     uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
    //     console2.log("PRIVATE KEY: ", deployerKey);
    //     console2.log("Actual USD: ", actualUSD);
    //     console2.log("Expected USD: ", expectedUsd);
    //     assertEq(expectedUsd, actualUSD, "USD value mismatch");
    // }

    // function testGetTokenAmountFromUSD() public {
    //     uint256 USDAmount = 100e18;
    //     uint256 expectedWeth = 0.05 ether;
    //     uint256 actualWeth = engine.getTokenAmountFromUSD(weth, USDAmount);
    //     console2.log("USDAmount: ", USDAmount);
    //     console2.log("expectedWeth: ", expectedWeth);
    //     console2.log("actualWeth: ", actualWeth);
    //     assertEq(expectedWeth, actualWeth);
    // }

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__ZeroAmountPassed.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfTokenAndPriceFeedLengthsDoNotMatch() public {
        tokenAddress.push(weth);
        priceFeedAddress.push(weth);
        priceFeedAddress.push(wbtc);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch
                .selector
        );
        new DSCEngine(tokenAddress, priceFeedAddress, address(dsc));
    }

    function testRevertIfUnapprovedToken() public {
        ERC20Mock unApprovedToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__TokenNotAllowed.selector,
                address(unApprovedToken)
            )
        );
        engine.depositCollateral(address(unApprovedToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralandGetAccountInfo() public depositCollateral{
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedDepositedAmount = engine.getTokenAmountFromUSD(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(COLLATERAL_AMOUNT, expectedDepositedAmount);
    }
}
