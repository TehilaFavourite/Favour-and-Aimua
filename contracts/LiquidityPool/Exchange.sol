// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../CreatorsToken/CreatorsToken.sol";

contract Exchange {
    address tokenAddress;
    address creatorsAddress;

    uint nativeTokenBalance;
    uint tokenBalance;

    uint lockedNativeTokenBalance;
    uint lockedTokenBalance;

    uint deployedTime;

    mapping(address => uint) creatorsTokenDeposited;
    mapping(address => uint) nativeTokenDeposited;

    mapping(address => mapping(uint => LockedLiquidityDeposit)) lockedLiquidityDeposits;
    mapping(address => uint) lockedLiquidityLastDepositId;

    CreatorsToken creatorsToken;

    struct LockedLiquidityDeposit {
        bool active;
        uint tokenAmount;
        uint nativeTokenAmount;
        uint lockedUntil;
    }

    constructor (address _tokenAddress, address _creatorsAddress) {
        tokenAddress = _tokenAddress;
        creatorsToken = CreatorsToken(_tokenAddress);
        creatorsAddress = _creatorsAddress;
        deployedTime = block.timestamp;
    }

    receive() external payable {nativeTokenBalance += msg.value;}

    function addLockedLiquidity(uint _tokenAmount, uint _lockedFor) public payable{
        //this contract must be approved to spend tokens before calling this function
       lockedNativeTokenBalance += msg.value;
       lockedTokenBalance += _tokenAmount;
       creatorsToken.transfer(address(this), _tokenAmount);

       lockedLiquidityDeposits[msg.sender][lockedLiquidityLastDepositId[msg.sender]].active = true;
       lockedLiquidityDeposits[msg.sender][lockedLiquidityLastDepositId[msg.sender]].tokenAmount = _tokenAmount;
       lockedLiquidityDeposits[msg.sender][lockedLiquidityLastDepositId[msg.sender]].nativeTokenAmount = _tokenAmount;
       lockedLiquidityDeposits[msg.sender][lockedLiquidityLastDepositId[msg.sender]].lockedUntil = block.timestamp + _lockedFor;
       lockedLiquidityLastDepositId[msg.sender]++;
    }

    function unlockLockedLiquidity(uint _depositId) public {
        require(lockedLiquidityDeposits[msg.sender][_depositId].lockedUntil <= block.timestamp, "liquidity lock duration has not passed yet");
        LockedLiquidityDeposit memory lockedLiquidity = lockedLiquidityDeposits[msg.sender][_depositId];
        
        lockedTokenBalance -= lockedLiquidity.tokenAmount;
        lockedNativeTokenBalance -= lockedLiquidity.nativeTokenAmount;

        tokenBalance += lockedLiquidity.tokenAmount;
        nativeTokenBalance += lockedLiquidity.nativeTokenAmount;

        creatorsTokenDeposited[msg.sender] = lockedLiquidity.tokenAmount;
        nativeTokenDeposited[msg.sender] = lockedLiquidity.nativeTokenAmount;

        lockedLiquidityDeposits[msg.sender][_depositId].active = false;
    }

    function addLiquidity(uint _tokenAmount) public payable {
        //this contract must be approved to spend tokens before calling this function
       nativeTokenBalance += msg.value;
       tokenBalance += _tokenAmount;
       creatorsToken.transfer(address(this), _tokenAmount);

       creatorsTokenDeposited[msg.sender] += _tokenAmount;
       nativeTokenDeposited[msg.sender] += msg.value;
    }

    function withdrawLiquidity(uint _creatorsTokenAmount, uint _nativeTokenAmount) public {
        require (creatorsTokenDeposited[msg.sender] <= _creatorsTokenAmount, "address does not have enough creators tokens deposited");
        require (nativeTokenDeposited[msg.sender] <= _nativeTokenAmount, "address does not have enough native tokens deposited");
    
        tokenBalance -= _creatorsTokenAmount;
        nativeTokenBalance -= _nativeTokenAmount;

        creatorsTokenDeposited[msg.sender] -= _creatorsTokenAmount;
        nativeTokenDeposited[msg.sender] -= _nativeTokenAmount;

        creatorsToken.transfer( msg.sender, _creatorsTokenAmount);
        payable (msg.sender).transfer(_nativeTokenAmount);
    }

    function nativeToTokenSwap() public payable returns (uint) {
        uint invariant = nativeTokenBalance * tokenBalance;
        nativeTokenBalance += msg.value;
        uint tokenBalDifference = invariant / nativeTokenBalance;
        uint tokensOut = tokenBalance - tokenBalDifference;
        tokenBalance -= tokensOut;
        
        creatorsToken.transfer(msg.sender, tokensOut);
        return (tokensOut);
    }

    function tokenToNativeSwap(uint _tokenAmount) public returns (uint){
        //user must approve this contract and token amount before calling this function

        creatorsToken.transfer(address(this), _tokenAmount);

        uint invariant = nativeTokenBalance * tokenBalance;
        tokenBalance += _tokenAmount;
        uint nativeBalDifference = invariant / tokenBalance;
        uint nativeOut = nativeTokenBalance - nativeBalDifference;

        nativeTokenBalance -= nativeOut;

        payable(msg.sender).transfer(nativeOut);
        return (nativeOut);
    }

    function getDepositInfo(address _depositer, uint _id) public view returns(LockedLiquidityDeposit memory) {
        return lockedLiquidityDeposits[_depositer][_id];
    }

    function getNativeTokenBalance() public view returns(uint) {
        return nativeTokenBalance;
    }

    function getTokenBalance() public view returns(uint) {
        return tokenBalance;
    }
}