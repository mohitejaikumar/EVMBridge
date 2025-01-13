// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IBERC20} from "./IBERC20.sol";


contract Bridge is Ownable{
    
    error BridgeToken_Transfer_Failed();
    error Invalid_Token_Address();
    error BridgeToken_Insufficient_Deposit();
    error Invalid_Nonce();

    event Mint(address indexed, address indexed, uint256);
    event Burn(address indexed, address indexed, uint256);

    mapping(address => uint256) public pendingBalances;
    address public bridgeTokenAddress;

    uint256 public nonce;
    
    constructor(address _tokenAddress) Ownable(_msgSender()) {
        bridgeTokenAddress = _tokenAddress;
    }

    function mint(address _tokenAddress, address _to, uint256 _amount, uint256 _nonce) external onlyOwner {
        require(
            _tokenAddress == bridgeTokenAddress,
            Invalid_Token_Address()
        );
        require(
            _nonce == nonce + 1,
            Invalid_Nonce()
        );
        IBERC20(_tokenAddress).mint(_to, _amount);
        pendingBalances[_to] += _amount;
        nonce++;
        emit Mint(_tokenAddress, _to, _amount);
    }
    
    function burn(address _tokenAddress, uint256 _amount) public {
        require(
            _tokenAddress == bridgeTokenAddress,
            Invalid_Token_Address()
        );
        require(
            pendingBalances[_msgSender()] >= _amount,
            BridgeToken_Insufficient_Deposit()
        );
        IBERC20(_tokenAddress).burn(_msgSender(), _amount);
        pendingBalances[_msgSender()] -= _amount;
        emit Burn(_tokenAddress, _msgSender(), _amount);
    }
    
}