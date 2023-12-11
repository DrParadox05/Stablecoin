// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// IMPORTS
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
 
contract DecentralizedStablecoin is ERC20Burnable, Ownable{

    // ERRORS
    error DecentralizedStablecoin__AmountMustBeMoreThanZero();
    error DecentralizedStablecoin__BalanceMustBeMoreThanAmount();
    error DecentralizedStablecoin__ZeroAddress();

    // CONSTRUCTOR
    constructor() ERC20("DecentralizedStablecoin", "DSC") Ownable(msg.sender) {}

    // EXTERNAL & PUBLIC FUNCTIONS
    function burn (uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(_amount <= 0){
            revert DecentralizedStablecoin__AmountMustBeMoreThanZero();
        }
        if(balance < _amount){
            revert DecentralizedStablecoin__BalanceMustBeMoreThanAmount();
        }
        super.burn(_amount);
    }

    function mint (address _to, uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DecentralizedStablecoin__ZeroAddress();
        }
        if(_amount <= 0){
            revert DecentralizedStablecoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}