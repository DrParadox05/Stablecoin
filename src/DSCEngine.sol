// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// IMPORTS
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard{

    // ERRORS
    error DSCEngine__ZeroAmountPassed();
    error DSCEngine__TokenNotAllowed(address);
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256);
    error DSCEngine__MintFailed();

    // EVENTS
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    // MODIFIERS
    modifier moreThanZero(uint256 amount) {
        if(amount == 0){
            revert DSCEngine__ZeroAmountPassed();
        }
        _;
    }

    modifier isAllowedToken(address tokenContract) {
        if(s_priceFeeds[tokenContract] == address(0)){
            revert DSCEngine__TokenNotAllowed(tokenContract);
        }
        _;
    }

    // STATE VARIABLES
    DecentralizedStablecoin private immutable i_dsc;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1;

    // MAPPINGS
    mapping (address collateralToken => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    mapping (address user => uint256 amountDSC) private s_DSCMinted;
    address[] private s_collateralTokens;

    // CONSTRUCTOR
    constructor(address[] memory tokenAddress, address[] memory priceFeedAddress, address dcsAddress){
        if(tokenAddress.length != priceFeedAddress.length){
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        for(uint256 i = 0; i < priceFeedAddress.length; i++){
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStablecoin(dcsAddress);
    }

    // EXTERNAL FUNCTIONS
    function depositCollateral(address _tokenCollateralAddress, uint256 _collateralAmount) public moreThanZero(_collateralAmount) isAllowedToken(_tokenCollateralAddress) nonReentrant {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _collateralAmount;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _collateralAmount);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDSC(uint256 _amountDSCToMint) external moreThanZero(_amountDSCToMint) nonReentrant{
        s_DSCMinted[msg.sender] += _amountDSCToMint;
        _revertHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amountDSCToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    // PRIVATE AND INTERNAL FUNCTIONS
    function _revertIfHealthFactorIsBroken(address user) internal view returns(uint256){
        userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MINIMUM_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) private view returns(uint256){
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDSCMinted, uint256 collateralValueInUSD){
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUSD = _getAccountCollateralValue(user);
        return (totalDSCMinted, collateralValueInUSD);
    }

    // VIEW AND PURE FUNCTIONS
    function _getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUSD){
        for(uint256 i = 0; i < s_collateralTokens; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(address _token, uint256 _amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

}