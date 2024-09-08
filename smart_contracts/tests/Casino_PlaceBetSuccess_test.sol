// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";
import "../misc/MockRandomizerProxy.sol";

contract Casino_PlaceBetSuccess_test {

    CasinoToken casinoToken;
    Casino casino;
    MockRandomizerProxy mockRandomizerProxy;

    function beforeEach () public {
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
    }

    /// #value: 1000000000000
    function testSuccess_Casino_PlaceBet() public payable {
        uint256 casinoTokenSupplyBeforeBet = casinoToken.totalSupply();
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        uint256 betAmount = 1 * 10**9;
        uint256 decimalStyleOddsX100 = 200;

        address agent = address(0xb9b0310760e439A180172Df7bDf0E1FC1525B40b);
        uint256 betId = casino.placeBet{ value: randomizerFee }(betAmount, decimalStyleOddsX100, agent);
        Assert.equal(casinoToken.totalSupply(), (casinoTokenSupplyBeforeBet - betAmount), "casinoToken totalSupply was expected to be lower than before the bet");
        Assert.equal(betId == 12345999, true, "betId was expected to have a value");

        Casino.Bet memory bet = casino.getBetById(betId);
        Assert.equal(bet.id, betId, "bet's id is invalid");
        Assert.equal(bet.bettor, address(this), "bet's bettor is invalid");
        Assert.equal(bet.amount, betAmount, "bet's amount is invalid");
        Assert.equal(bet.decimalStyleOddsX100, decimalStyleOddsX100, "bet's decimalStyleOddsX100 is invalid");
        Assert.equal(bet.agent, agent, "bet's agent is invalid");
    }
}
