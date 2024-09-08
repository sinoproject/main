// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";
import "../misc/MockRandomizerProxy.sol";

contract Casino_VoidBet_test {

    CasinoToken casinoToken;
    Casino casino;
    MockRandomizerProxy mockRandomizerProxy;
    uint256 betAmount = 1 * 10**9;
    uint256 decimalStyleOddsX100 = 177;
    uint256 betId;
    uint256 casinoTokenTotalSupplyBefore;
    uint256 casinoTokenUserBalanceBefore;
    uint256 casinoJackpotFundBefore;
    address agent = address(0);

    /// #value: 1000000000000
    function beforeEach () public payable {
        casinoToken = new CasinoToken();
        casino = new Casino();
        mockRandomizerProxy = new MockRandomizerProxy();

        casinoToken.initialize();
        casino.initialize(address(casinoToken));

        casino.setIsBettingEnabled(true);
        casino.setRandomizerProxyAddress(address(mockRandomizerProxy));
        mockRandomizerProxy.setCasinoAddress(address(casino));
        casinoToken.transferOwnership(address(casino));

        // Place bet and get its betId
        casinoTokenTotalSupplyBefore = casinoToken.totalSupply();
        casinoTokenUserBalanceBefore = casinoToken.balanceOf(address(this));
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        betId = casino.placeBet{ value: randomizerFee }(betAmount, decimalStyleOddsX100, agent);
    }

    function testSuccess_Casino_VoidBet_ContractOwnerCanVoid() public {

        // Before voiding
        Assert.equal(casinoToken.totalSupply(), (casinoTokenTotalSupplyBefore - betAmount), "before voiding: casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), (casinoTokenUserBalanceBefore - betAmount), "before voiding: casinoToken balanceOf invalid");

        // After voiding
        casino.voidBet(betId);
        Assert.equal(casinoToken.totalSupply(), casinoTokenTotalSupplyBefore, "after voiding: casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), casinoTokenUserBalanceBefore, "after voiding: casinoToken balanceOf invalid");

        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal(bet.id == 0, true, "bet still exists (id must have been empty)");
        Assert.equal(bet.bettor, address(0), "bet still exists (bettor must have been 0)");
        Assert.equal(bet.amount, 0, "bet still exists (amount must have been 0)");
    }

    function testSuccess_Casino_VoidBet_Failure_BetDoesNotExist() public {
        uint256 nonExistingBetId = 666;
        casino.voidBet(nonExistingBetId);
        Casino.Bet memory bet = casino.getBetById(nonExistingBetId);
        Assert.equal(bet.amount, 0, "bet exists but it should not");
    }

    function testFailure_Casino_VoidBet_NonContractOwnerCannotVoid() public {

        // Transfer ownership of contract to another user
        casino.transferOwnership(address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2));
        Assert.equal(casino.owner() != address(this), true, "before voiding: casino contract owner must not be me");

        // Before voiding
        uint256 expectedAmountOfTokens = casinoTokenTotalSupplyBefore - betAmount;
        Assert.equal(casinoToken.totalSupply(), expectedAmountOfTokens, "before voiding: casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), expectedAmountOfTokens, "before voiding: casinoToken balanceOf invalid");

        try casino.voidBet(betId) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {

        }

        // After voiding failed (expectedAmountOfTokens must be the same as before voiding)
        Assert.equal(casinoToken.totalSupply(), expectedAmountOfTokens, "after voiding: casinoToken supply invalid");
        Assert.equal(casinoToken.balanceOf(address(this)), expectedAmountOfTokens, "after voiding: casinoToken balanceOf invalid");

        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal((bet.id > 0), true, "bet must still exist but it doesn't");
    }
}
