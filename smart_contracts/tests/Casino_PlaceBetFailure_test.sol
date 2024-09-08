// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";
import "../misc/MockRandomizerProxy.sol";

contract Casino_PlaceBetFailure_test {

    CasinoToken casinoToken;
    Casino casino;
    MockRandomizerProxy mockRandomizerProxy;
    uint256 minBetAmount = 1 * 10**9;

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

    function testFailure_Casino_PlaceBet_BettingNotEnabled() public {
        casino.setIsBettingEnabled(false);
        try casino.placeBet(minBetAmount, 200, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrBettingNotEnabled()")), keccak256(err), "unexpected revert error");
        }
    }

    function testFailure_Casino_PlaceBet_OddsInvalid() public {
        uint256 decimalStyleOddsX100 = 109; // below the minimum
        try casino.placeBet(minBetAmount, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrInvalidDecimalStyleOddsX100()")), keccak256(err), "unexpected revert error");
        }

        decimalStyleOddsX100 = 10100; // above the maximum
        try casino.placeBet(minBetAmount, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrInvalidDecimalStyleOddsX100()")), keccak256(err), "unexpected revert error");
        }
    }

    function testFailure_Casino_PlaceBet_BetAmountInvalid() public {
        uint256 decimalStyleOddsX100 = 200;
        try casino.placeBet(minBetAmount-1, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrInvalidBetAmount()")), keccak256(err), "unexpected revert error");
        }
    }

    function testFailure_Casino_PlaceBet_WouldExceedMaxPayout() public {
        uint256 decimalStyleOddsX100 = 200;
        uint256 betAmount = 1 + (casino.maxPayout() / ((decimalStyleOddsX100/100)));
        try casino.placeBet(betAmount, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrWouldExceedMaxPayout()")), keccak256(err), "unexpected revert error");
        }
    }

    function testFailure_Casino_PlaceBet_RandomizerFeeNotSent() public {
        try casino.placeBet(minBetAmount, 200, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrRandomizerCallbackFeeNotSent()")), keccak256(err), "unexpected revert error");
        }
    }

    /// #value: 1000000000000
    function testFailure_Casino_PlaceBet_BetAmountHigherThanSenderBalance() public payable {
        // Send all of my tokens (which is the entire supply) to dummy address
        casinoToken.transfer(0x666683F64D9C6D1ECf9B849aE677DD3315836666, casinoToken.totalSupply());

        // Place bet
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        uint256 decimalStyleOddsX100 = 200;
        try casino.placeBet{ value: randomizerFee }(minBetAmount, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrBetAmountHigherThanSenderBalance()")), keccak256(err), "unexpected revert error");
        }
    }

    /// #value: 2000000000000
    function testFailure_Casino_PlaceBet_BetIdExists() public payable {
        // Place bet
        uint256 randomizerFee = casino.randomizerCallbackFee(); // 1000 gwei
        uint256 decimalStyleOddsX100 = 200;
        casino.placeBet{ value: randomizerFee }(minBetAmount, decimalStyleOddsX100, address(0));

        // Place bet again: this should fail because MockRandomizerProxy
        // returns always the same betId, which corresponds to the existing
        // bet above which hasn't been settled yet
        try casino.placeBet{ value: randomizerFee }(minBetAmount, decimalStyleOddsX100, address(0)) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.equal(keccak256(abi.encodeWithSignature("ErrBetIdAlreadyExists()")), keccak256(err), "unexpected revert error");
        }
    }
}
