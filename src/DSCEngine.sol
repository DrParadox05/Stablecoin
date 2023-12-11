// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DSCEngine is ReentrancyGuard{

    error DSCEngine__ZeroAmountPassed();
    error DSCEngine__TokenNotAllowed(address);
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__TransferFailed();

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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

    DecentralizedStablecoin private immutable i_dsc;

    mapping (address collateralToken => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    address[] private s_collateralTokens;

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

    function depositCollateral(address _tokenCollateralAddress, uint256 _collateralAmount) public moreThanZero(_collateralAmount) isAllowedToken(_tokenCollateralAddress) nonReentrant {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _collateralAmount;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _collateralAmount);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }
}