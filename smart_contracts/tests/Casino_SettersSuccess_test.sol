// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import "remix_tests.sol";
import "hardhat/console.sol";
import "../contracts/CasinoToken.sol";
import "../contracts/Casino.sol";

contract Casino_SettersSuccess_test {

    CasinoToken casinoToken;
    Casino casino;

    function beforeEach () public {
        casinoToken = new CasinoToken();
        casino = new Casino();
        casinoToken.initialize();
        casino.initialize(address(casinoToken));
        casinoToken.transferOwnership(address(casino));
    }

    function testSuccess_Casino_SetMaxPayout() public {
        uint256 onePcOfTokenSupply = casinoToken.totalSupply() / 100;
        uint256 value = onePcOfTokenSupply - 1;
        casino.setMaxPayout(value);
        Assert.equal(casino.maxPayout(), value, "unexpected value");
    }
}
