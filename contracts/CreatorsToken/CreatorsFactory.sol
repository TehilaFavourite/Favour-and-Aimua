// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CreatorsToken.sol";

contract Factory {
    address[] public tokens;
    uint256 public tokenCount;
    event TokenDeployed(address tokenAddress);

    function deployToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _totalSupply
    ) public returns (address) {
        CreatorsToken token = new CreatorsToken(_name, _symbol, _totalSupply, msg.sender);
        tokens.push(address(token));
        tokenCount += 1;
        emit TokenDeployed(address(token));
        return address(token);
    }
}
