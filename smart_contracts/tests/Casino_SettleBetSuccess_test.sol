// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";
import "../misc/MockRandomizerProxy.sol";

// Please note that casino.settleBet() cannot be called directly. Instead
// we call a casino randomizer proxy contract's function that triggers settleBet
contract Casino_SettleBetSuccess_test {

    CasinoToken casinoToken;
    Casino casino;
    MockRandomizerProxy mockRandomizerProxy;
    uint256 betAmount = 1 * 10**9;
    uint256 decimalStyleOddsX100 = 177;
    uint256 betId;
    uint256 casinoTokenTotalSupplyBefore;
    uint256 casinoTokenUserBalanceBefore;
    uint256 casinoJackpotFundBefore;
    address agent = address(0xb9b0310760e439A180172Df7bDf0E1FC1525B40b);

    /// #value: 1000000000000
    function beforeEach () public payable {
        casinoToken = new CasinoToken();
        casino = new Casino();
        mockRandomizerProxy = new MockRandomizerProxy();

        casinoToken.initialize();
        casino.initialize(address(casinoToken));

        casino.setIsBettingEnabled(true);
        casino.setRandomizerProxyAddress(address(mockRandomizerProxy));
        casino.updateRandomizerCallbackFee();
        mockRandomizerProxy.setCasinoAddress(address(casino));
        casinoToken.transferOwnership(address(casino));

        // Place bet and get its betId
        casinoTokenTotalSupplyBefore = casinoToken.totalSupply();
        casinoTokenUserBalanceBefore = casinoToken.balanceOf(address(this));
        casinoJackpotFundBefore = casino.jackpotFund();
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        betId = casino.placeBet{ value: randomizerFee }(betAmount, decimalStyleOddsX100, agent);
    }

    function testSuccess_Casino_SettleBet_LosingBet() public {
        // Bet odds of 1.77, combined with the standard house
        // edge of 2%, require randomNumber 1-5537 to settle bet as winner.
        // So, bet will be a loser because 5538 > 5537.
        bytes32 randomValue = 0x000000000000000000000000000000000000000000000000000000000FF6FFA1; // randomNumber 5538
        mockRandomizerProxy.randomizerCallback(betId, randomValue);
        Assert.equal(casinoToken.totalSupply(), (casinoTokenTotalSupplyBefore - betAmount), "casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), (casinoTokenUserBalanceBefore - betAmount), "casinoToken balanceOf invalid");
        Assert.equal(casinoToken.balanceOf(agent), 0, "casinoToken balanceOf agent invalid");
        Assert.equal(casino.jackpotFund(), casinoJackpotFundBefore, "jackpotFund invalid");
        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal(bet.amount, 0, "bet still exists");
    }

    function testSuccess_Casino_SettleBet_WinningBet() public {
        // Bet odds of 1.77, combined with the standard house
        // edge of 2%, require randomNumber 1-5537 to settle bet as winner.
        // So, bet will be a winner because 5536 < 5537.
        bytes32 randomValue = 0x000000000000000000000000000000000000000000000000000000000FF6FF9F; // randomNumber 5536
        mockRandomizerProxy.randomizerCallback(betId, randomValue);
        Assert.equal(casinoToken.totalSupply(), 10000000000000000788000000, "casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), 10000000000000000770000000, "casinoToken balanceOf invalid");
        Assert.equal(casinoToken.balanceOf(agent), 9000000, "casinoToken balanceOf agent invalid");
        Assert.equal(casino.jackpotFund(), 9000000, "jackpotFund invalid");
        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal(bet.amount, 0, "bet still exists");
    }

    function testSuccess_Casino_SettleBet_WinningBetAndJackpot() public {
        // Bet odds of 1.77, combined with the standard house
        // edge of 2%, require randomNumber 1-5537 to settle bet as winner.
        // So, bet will be a winner because 1 < 5537.
        bytes32 randomValue = 0x000000000000000000000000000000000000000000000000000000000FFF0050; // randomNumber 1
        mockRandomizerProxy.randomizerCallback(betId, randomValue);
        Assert.equal(casinoToken.totalSupply(), 10000000000000000788000000, "casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), 10000000000000000779000000, "casinoToken balanceOf invalid");
        Assert.equal(casinoToken.balanceOf(agent), 9000000, "casinoToken balanceOf agent invalid");
        Assert.equal(casino.jackpotFund(), 0, "jackpotFund invalid");
        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal(bet.amount, 0, "bet still exists");
    }

    function testSuccess_Casino_SettleBet_NotExistingBet() public {
        bytes32 randomValue = 0x6261720000000000000000000000000000000000000000000000000000000000;
        uint256 nonExistingBetId = 666;
        mockRandomizerProxy.randomizerCallback(nonExistingBetId, randomValue);
        Casino.Bet memory bet = casino.getBetById(nonExistingBetId);
        Assert.equal(bet.amount, 0, "bet exists but it should not");
    }
}
