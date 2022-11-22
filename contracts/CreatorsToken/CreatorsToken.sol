// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CreatorsToken is ERC20, ERC20Burnable, Ownable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address owner_
    ) ERC20(_name, _symbol) {        
        transferOwnership(owner_);
        _mint(owner_, _supply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}