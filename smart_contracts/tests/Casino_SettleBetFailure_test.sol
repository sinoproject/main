// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";
import "../misc/MockRandomizerProxy.sol";

// Please note that casino.settleBet() can only be called by the designated
// casino randomizer proxy contract, this is way all test scenarios
// call one of that proxy contract's functions.
contract Casino_SettleBetFailure_test {

    CasinoToken casinoToken;
    Casino casino;
    MockRandomizerProxy mockRandomizerProxy;
    uint256 betId;

    /// #value: 1000000000000
    function beforeEach () public payable {
        casinoToken = new CasinoToken();
        casino = new Casino();
        mockRandomizerProxy = new MockRandomizerProxy();

        casinoToken.initialize();
        casino.initialize(address(casinoToken));

        uint256 betAmount = 1 * 10**9;
        casino.setIsBettingEnabled(true);
        casino.setRandomizerProxyAddress(address(mockRandomizerProxy));
        casino.updateRandomizerCallbackFee();
        mockRandomizerProxy.setCasinoAddress(address(casino));
        casinoToken.transferOwnership(address(casino));

        // Place bet and get its betId
        uint256 decimalStyleOddsX100 = 200;
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        betId = casino.placeBet{ value: randomizerFee }(betAmount, decimalStyleOddsX100, address(0));
    }

    function testFailure_Casino_SettleBet_CannotCallDirectly() public {
        try casino.settleBet(betId, 666) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrCallerMustBeRandomizerProxyContract()")), keccak256(err), "unexpected revert error");
        }
    }
}
