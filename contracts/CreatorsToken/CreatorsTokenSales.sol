// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "../LiquidityPool/Exchange.sol";
import "./CreatorsToken.sol";

contract CreatorsTokenSale {
    // mapping that holds the information for the creators token sales
    mapping(address => Sale) creatorsTokenSales;

    struct Sale {
        address CreatorsTokenAddress;
        address payable ExchangeAddress;
        uint PricePerToken;
        uint256 amount;
        uint PercentageForLiquidity;
        uint TokensForSale;
        //RICO
        uint InitialCommitedNativeTokens;
        uint InitialUnlockedNativeTokens;
        uint InitialReturnPricePerCoin;
        uint ReturnPriceReducePerInterval;
        uint LockedPerInterval;
        uint IntervalLength;
        uint IntervalTotalLength;
        uint TimeStart;
        uint CreatorsLastClaimTime;
        uint maxTime;
        uint amountClaimed;
    }

    // mapping that holds all information on the exchange addresses created
    mapping(address => address) createdExchangeAddresses;

    address contractDeployer;

    event CreateSaleEvent(
        address indexed creatorsAddress,
        address indexed creatorsTokenAddress,
        uint indexed pricePerToken
    );
    event StartSaleEvent(address indexed creatorsAddress);
    event StopSaleEvent(address indexed creatorsAddress);
    event BuyCreatorsTokensEvent(
        address indexed creatorsAddress,
        uint indexed buyAmount
    );
    event NewExchange(
        address indexed token,
        address indexed creator,
        address indexed exchange
    );

    constructor() {
        contractDeployer = msg.sender;
    }

    // a new exchange token is created for the token by the creator
    function CreateExchange(address _tokenAddress, address _creatorsAddress)
        public
    {
        Exchange newExchange = new Exchange(_tokenAddress, _creatorsAddress);
        createdExchangeAddresses[msg.sender] = address(newExchange);

        emit NewExchange(_tokenAddress, _creatorsAddress, address(newExchange));
    }

    // only te deployer of this contract can create sales.
    // once you create sales for a token with the creators address and token address, you cannot create sles again
    
    function CreateSale(
        address _creatorsAddress,
        address _creatorsTokenAddress,
        address payable _exchangeAddress,
        uint _pricePerToken,
        uint _percentageForCreators,
        uint _percentageForLiquidity,
        uint _percentageOfCommitedFunds,
        uint _intervalLength,
        uint _intervalTotalLength,
        uint _amountMinted
    ) public {
        //user must approve this contract address to transfer tokens from creators token address before calling this function
        require(
            msg.sender == contractDeployer,
            "Only contract deployer can call this function"
        );
        require(
            creatorsTokenSales[_creatorsAddress].CreatorsTokenAddress ==
                0x0000000000000000000000000000000000000000,
            "creators token sale is already created"
        );
        // percentage for liquidity must be <= 100
        require(
            _percentageForLiquidity <= 100,
            "Percentage for liquidity cannot be higher than 100"
        );
        require(
            _percentageForCreators <= 100,
            "Percentage for creators cannot be higher than 100"
        );
        // instatiating the functions inside the creators token contract
        CreatorsToken creatorsToken = CreatorsToken(_creatorsTokenAddress);

        setupSale1(
            _creatorsAddress,
            _creatorsTokenAddress,
            _exchangeAddress,
            _pricePerToken,
            _percentageForLiquidity,
            _amountMinted
        );
        setupSale2(
            _creatorsAddress,
            _creatorsTokenAddress,
            _pricePerToken,
            _percentageOfCommitedFunds,
            _intervalLength,
            _intervalTotalLength
        );

        uint PercentageForSale = 100 -
            (_percentageForCreators + _percentageForLiquidity);

        //calculate and apply percentage of token supply for sale
        uint TokenSupplyMultiplied = creatorsToken.totalSupply() * 100;
        creatorsTokenSales[_creatorsAddress].TokensForSale =
            (PercentageForSale * TokenSupplyMultiplied) /
            10000;

        creatorsToken.transfer(
            _creatorsAddress,
            (_percentageForCreators * TokenSupplyMultiplied) / 10000
        );

        emit CreateSaleEvent(
            _creatorsAddress,
            _creatorsTokenAddress,
            _pricePerToken
        );
        address(this).delegatecall(abi.encodeWithSignature("StartSale()"));
    }

    // it initializes the creators token address and store all the inputs into the mapping
    // it mints from the creators token to the creators address
    
    function setupSale1(
        address _creatorsAddress,
        address _creatorsTokenAddress,
        address payable _exchangeAddress,
        uint _pricePerToken,
        uint _percentageForLiquidity,
        uint _amountMinted
    ) internal {
        CreatorsToken creatorsToken = CreatorsToken(_creatorsTokenAddress);

        creatorsTokenSales[_creatorsAddress]
            .CreatorsTokenAddress = _creatorsTokenAddress;
        creatorsTokenSales[_creatorsAddress].ExchangeAddress = _exchangeAddress;
        creatorsTokenSales[_creatorsAddress].PricePerToken = _pricePerToken;
        creatorsTokenSales[_creatorsAddress].amount = _amountMinted;

        creatorsTokenSales[_creatorsAddress]
            .PercentageForLiquidity = _percentageForLiquidity;
        creatorsToken.mint(_creatorsAddress, _amountMinted);
    }

    function setupSale2(
        address _creatorsAddress,
        address _creatorsTokenAddress,
        uint _pricePerToken,
        uint _percentageOfCommitedFunds,
        uint _intervalLength,
        uint _intervalTotalLength
    ) internal {
        //calculate and apply percentage of funds that will be commited

        CreatorsToken creatorsToken = CreatorsToken(_creatorsTokenAddress);
        uint TotalFundsFromSale = creatorsToken.totalSupply() * _pricePerToken;
        uint TotalFundsMultiplied = TotalFundsFromSale * 100;
        creatorsTokenSales[_creatorsAddress].InitialCommitedNativeTokens =
            (_percentageOfCommitedFunds * TotalFundsMultiplied) /
            10000;

        creatorsTokenSales[_creatorsAddress].InitialUnlockedNativeTokens =
            TotalFundsFromSale -
            creatorsTokenSales[_creatorsAddress].InitialCommitedNativeTokens;
        creatorsTokenSales[_creatorsAddress]
            .InitialUnlockedNativeTokens = creatorsTokenSales[_creatorsAddress]
            .InitialCommitedNativeTokens;
        //calculate and apply percentage of funds that will be commited
        uint PercentageForReturnPrice = 100 - _percentageOfCommitedFunds;
        uint PricePerTokenMultipled = _pricePerToken * 100;
        creatorsTokenSales[_creatorsAddress].InitialReturnPricePerCoin =
            (PercentageForReturnPrice * PricePerTokenMultipled) /
            10000;
        creatorsTokenSales[_creatorsAddress]
            .InitialReturnPricePerCoin = PercentageForReturnPrice;

        creatorsTokenSales[_creatorsAddress].ReturnPriceReducePerInterval =
            creatorsTokenSales[_creatorsAddress].InitialReturnPricePerCoin /
            _intervalTotalLength;

        creatorsTokenSales[_creatorsAddress]
            .LockedPerInterval = creatorsTokenSales[_creatorsAddress]
            .ReturnPriceReducePerInterval;

        creatorsTokenSales[_creatorsAddress].IntervalLength = _intervalLength;
        creatorsTokenSales[_creatorsAddress]
            .IntervalTotalLength = _intervalTotalLength;

        creatorsTokenSales[_creatorsAddress].TimeStart = block.timestamp;
        creatorsTokenSales[_creatorsAddress]
            .CreatorsLastClaimTime = creatorsTokenSales[_creatorsAddress]
            .TimeStart;

        creatorsTokenSales[_creatorsAddress].maxTime =
            (_intervalLength * _intervalTotalLength) +
            creatorsTokenSales[_creatorsAddress].TimeStart;
        creatorsTokenSales[_creatorsAddress].amountClaimed = 0;
    }

    function BuyCreatorsTokens(address _creatorsAddress) public payable {
        require(
            creatorsTokenSales[_creatorsAddress].CreatorsTokenAddress !=
                0x0000000000000000000000000000000000000000,
            "creators does not have token address set"
        );
        require(
            creatorsTokenSales[_creatorsAddress].PricePerToken <= msg.value,
            "Token price is greater than native token that has been sent"
        );
        require(
            creatorsTokenSales[_creatorsAddress].TokensForSale > 0,
            "No creators tokens for sale right now"
        );

        //has account sent enough native tokens
        CreatorsToken creatorsToken = CreatorsToken(
            creatorsTokenSales[_creatorsAddress].CreatorsTokenAddress
        );

        uint buyAmount = msg.value /
            creatorsTokenSales[_creatorsAddress].PricePerToken;
        require(
            buyAmount <= creatorsToken.balanceOf(address(this)),
            "Not enough tokens left to buy"
        );

        creatorsTokenSales[_creatorsAddress].TokensForSale -= buyAmount;
        creatorsToken.transfer(msg.sender, buyAmount);

        if (creatorsTokenSales[_creatorsAddress].TokensForSale == 0) {
            Exchange creatorsExchange = Exchange(
                creatorsTokenSales[_creatorsAddress].ExchangeAddress
            );
            //work out token %
            uint tokenAmount = creatorsToken.balanceOf(address(this)) * 100;
            uint tokensForLiquidity = (creatorsTokenSales[_creatorsAddress]
                .PercentageForLiquidity * tokenAmount) / 10000;

            //work out native token %
            uint nativeTokenAmount = address(this).balance * 100;
            uint nativeTokensForLiquidity = (creatorsTokenSales[
                _creatorsAddress
            ].PercentageForLiquidity * nativeTokenAmount) / 10000;
            //send those

            creatorsToken.approve(
                address(creatorsExchange),
                tokensForLiquidity
            );
            creatorsExchange.addLockedLiquidity{
                value: nativeTokensForLiquidity
            }(tokensForLiquidity, 63120000); //24 months
        }
        emit BuyCreatorsTokensEvent(_creatorsAddress, buyAmount);
    }

    function UnlockLiquidity(uint _depositId) public {
        Exchange exchange = Exchange(
            creatorsTokenSales[msg.sender].ExchangeAddress
        );

        exchange.unlockLockedLiquidity(_depositId);
        exchange.withdrawLiquidity(
            exchange.getDepositInfo(address(this), _depositId).tokenAmount,
            exchange.getDepositInfo(address(this), _depositId).nativeTokenAmount
        );

        CreatorsToken creatorsToken = CreatorsToken(
            creatorsTokenSales[msg.sender].CreatorsTokenAddress
        );

        creatorsToken.transfer(
            msg.sender,
            exchange.getDepositInfo(address(this), _depositId).tokenAmount
        );
        payable(msg.sender).transfer(
            exchange.getDepositInfo(address(this), _depositId).nativeTokenAmount
        );
    }

    //rico
    function CreatorsClaim() public {
        uint intervalsFromStart = (block.timestamp -
            creatorsTokenSales[msg.sender].TimeStart) /
            creatorsTokenSales[msg.sender].IntervalLength;
        uint intervalsFromLastClaim = (creatorsTokenSales[msg.sender]
            .CreatorsLastClaimTime - creatorsTokenSales[msg.sender].TimeStart) /
            creatorsTokenSales[msg.sender].IntervalLength;
        uint result = intervalsFromStart - intervalsFromLastClaim;

        require(result > 0, "not enough time has passed for creators to claim");
        require(
            intervalsFromLastClaim <
                creatorsTokenSales[msg.sender].IntervalTotalLength,
            "no more claims avaliable for creators"
        );
        CreatorsToken creatorsToken = CreatorsToken(
            creatorsTokenSales[msg.sender].CreatorsTokenAddress
        );
        uint sendToCreators = creatorsTokenSales[msg.sender].LockedPerInterval *
            result;

        creatorsTokenSales[msg.sender].CreatorsLastClaimTime +=
            result *
            creatorsTokenSales[msg.sender].IntervalLength;
        creatorsToken.transfer(msg.sender, sendToCreators);
    }

    function ReturnTokens(address _creatorsAddress, uint _amount) public {
        //user must approve this contract address with the creators token before calling this function

        uint difference = block.timestamp -
            creatorsTokenSales[_creatorsAddress].TimeStart;
        uint intervalsPassed = difference /
            creatorsTokenSales[_creatorsAddress].IntervalLength;

        require(
            intervalsPassed <
                creatorsTokenSales[_creatorsAddress].IntervalTotalLength,
            "Reversible ICO has finished with this token"
        );

        CreatorsToken creatorsToken = CreatorsToken(
            creatorsTokenSales[_creatorsAddress].CreatorsTokenAddress
        );

        uint priceRemovePerToken = intervalsPassed *
            creatorsTokenSales[_creatorsAddress].ReturnPriceReducePerInterval;
        uint pricePerToken = creatorsTokenSales[_creatorsAddress]
            .InitialReturnPricePerCoin - priceRemovePerToken;
        uint nativeReturnAmount = _amount * pricePerToken;

        creatorsToken.transfer(address(this), _amount);
        creatorsTokenSales[_creatorsAddress].TokensForSale += _amount;
        payable(msg.sender).transfer(nativeReturnAmount);
    }

    function getSaleInfo(address _creatorsAddress)
        public
        view
        returns (Sale memory)
    {
        return (creatorsTokenSales[_creatorsAddress]);
    }

    function getExchangeAddress(address _address)
        public
        view
        returns (address)
    {
        return createdExchangeAddresses[_address];
    }
}
