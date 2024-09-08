// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";

contract Casino_SettersFailure_test {

    CasinoToken casinoToken;
    Casino casino;

    function beforeEach () public {
        casinoToken = new CasinoToken();
        casino = new Casino();
        casinoToken.initialize();
        casino.initialize(address(casinoToken));
        casinoToken.transferOwnership(address(casino));
    }

    function testFailure_Casino_SetMaxPayout_TooLow() public {
        uint256 value = 0;
        try casino.setMaxPayout(value) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.ok(true, "");
        }
    }

    function testFailure_Casino_SetMaxPayout_TooHigh() public {
        uint256 onePcOfTokenSupply = casinoToken.totalSupply() / 100;
        uint256 value = onePcOfTokenSupply + 1;
        try casino.setMaxPayout(value) {
            Assert.ok(false, "method execution should fail");
        } catch (bytes memory err) {
            Assert.ok(true, "");
        }
    }
}
