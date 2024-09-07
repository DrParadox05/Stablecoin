// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// IMPORTS
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";

contract DSCEngine is ReentrancyGuard {
    // ERRORS
    error DSCEngine__ZeroAmountPassed();
    error DSCEngine__TokenNotAllowed(address);
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    // EVENTS
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed token,
        uint256 amount
    );

    // MODIFIERS
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__ZeroAmountPassed();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(_token);
        }
        _;
    }

    // STATE VARIABLES
    DecentralizedStablecoin private immutable i_dsc;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;

    // MAPPINGS
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 amountDSC) private s_DSCMinted;
    address[] private s_collateralTokens;

    // CONSTRUCTOR
    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dcsAddress
    ) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch();
        }

        for (uint256 i = 0; i < priceFeedAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStablecoin(dcsAddress);
    }

    //EXTERNAL FUNCTIONS
    function depositCollateralAndMintDSC(
        uint256 _collateralAmount,
        address _collateralAddress,
        uint256 _DSCAmount
    ) external {
        depositCollateral(_collateralAddress, _collateralAmount);
        mintDSC(_DSCAmount);
    }

    function redeemCollateralForDSC(
        uint256 _collateralAmount,
        address _collateralAddress,
        uint256 _DSCtoBurn
    )
        external
        moreThanZero(_collateralAmount)
        isAllowedToken(_collateralAddress)
    {
        _burnDSC(_DSCtoBurn, msg.sender, msg.sender);
        _redeemCollateral(
            _collateralAmount,
            _collateralAddress,
            msg.sender,
            msg.sender
        );
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(
        address _collateral,
        address _user,
        uint256 _debtToCover
    )
        external
        nonReentrant
        moreThanZero(_debtToCover)
        isAllowedToken(_collateral)
    {
        uint256 initialHealthFactor = _healthFactor(_user);
        if (initialHealthFactor >= MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebt = getTokenAmountFromUSD(
            _collateral,
            _debtToCover
        );
        uint256 bonusCollateral = (tokenAmountFromDebt * LIQUIDATION_BONUS) /
            LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebt + bonusCollateral;
        _redeemCollateral(
            totalCollateralToRedeem,
            _collateral,
            msg.sender,
            _user
        );
        _burnDSC(totalCollateralToRedeem, _user, msg.sender);
        uint256 finalHealthFactor = _healthFactor(_user);
        if (finalHealthFactor <= initialHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    // PUBLIC FUNCTIONS
    function getTokenAmountFromUSD(
        address _collateral,
        uint256 _usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_collateral]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return ((_usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _collateralAmount
    )
        public
        moreThanZero(_collateralAmount)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            _tokenCollateralAddress
        ] += _collateralAmount;

        emit CollateralDeposited(
            msg.sender,
            _tokenCollateralAddress,
            _collateralAmount
        );

        bool success = IERC20(_tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDSC(
        uint256 _amountDSCToMint
    ) public moreThanZero(_amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += _amountDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function redeemCollateral(address _collateralAddress, uint256 _collateralAmount) external moreThanZero(_collateralAmount) isAllowedToken(_collateralAddress) nonReentrant {
        _redeemCollateral(_collateralAmount, _collateralAddress, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // PRIVATE AND INTERNAL FUNCTIONS
    function _redeemCollateral(
        uint256 _redeemAmount,
        address _collateralAddress,
        address _from,
        address _to
    )
        private
        moreThanZero(_redeemAmount)
        nonReentrant
        isAllowedToken(_collateralAddress)
    {
        s_collateralDeposited[_from][_collateralAddress] -= _redeemAmount;
        emit CollateralRedeemed(_from, _to, _collateralAddress, _redeemAmount);
        bool success = IERC20(_collateralAddress).transfer(_to, _redeemAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(_from);
    }

    function _burnDSC(
        uint256 _amountToBurn,
        address onBehalfOf,
        address DSCFrom
    ) private moreThanZero(_amountToBurn) {
        s_DSCMinted[onBehalfOf] -= _amountToBurn;
        bool success = i_dsc.transferFrom(
            DSCFrom,
            address(this),
            _amountToBurn
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amountToBurn);
        _revertIfHealthFactorIsBroken(onBehalfOf);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalDSCMinted,
            uint256 collateralValueInUSD
        ) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUSD = _getAccountCollateralValue(user);
        return (totalDSCMinted, collateralValueInUSD);
    }

    // VIEW AND PURE FUNCTIONS
    function _getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) /
            PRECISION;
    }

    function getCollateralTokenAddress() external view returns(address[] memory){
        return s_collateralTokens;
    }

    function getCollateralBalance(address _user, address _collateral) external view returns(uint256){
        return s_collateralDeposited[_user][_collateral];
    }
}
