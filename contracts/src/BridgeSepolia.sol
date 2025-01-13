// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IBERC20} from "./IBERC20.sol";



contract BridgeSepolia is Ownable{
    
    error BridgeToken_Insufficient_Allowance();
    error BridgeToken_Transfer_Failed();
    error BridgeToken_Insufficient_Deposit();
    error Invalid_Token_Address();

    event Deposit(address indexed, address indexed, uint256);
    event Redeem(address indexed, address indexed, uint256);

    mapping(address => uint256) public pendingBalances;
    address public bridgeTokenAddress;

    constructor(address _tokenAddress) Ownable(_msgSender()) {
        bridgeTokenAddress = _tokenAddress;
    }

    function deposit(address _tokenAddress, uint256 _amount) public {
        require(
            _tokenAddress == bridgeTokenAddress,
            Invalid_Token_Address()
        );
        require(
            IBERC20(_tokenAddress).allowance(_msgSender(), address(this)) >= _amount,
            BridgeToken_Insufficient_Allowance()
        );
        require(
            IBERC20(_tokenAddress).transferFrom(_msgSender(), address(this), _amount),
            BridgeToken_Transfer_Failed()
        );
        pendingBalances[_msgSender()] += _amount;
        emit Deposit(_tokenAddress, _msgSender(), _amount);
    }
    
    function redeem(address _tokenAddress, address _to, uint256 _amount) external onlyOwner {
        require(
            _tokenAddress == bridgeTokenAddress,
            Invalid_Token_Address()
        );
        require(
            pendingBalances[_to] >= _amount,
            BridgeToken_Insufficient_Deposit()
        );
        require(
            IBERC20(_tokenAddress).transfer(_to, _amount),
            BridgeToken_Transfer_Failed()
        );
        pendingBalances[_to] -= _amount;
        emit Redeem(_tokenAddress, _to, _amount);
    }

}