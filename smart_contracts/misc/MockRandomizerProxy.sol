// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import {Ownable} from "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import {ICasino} from "../contracts/ICasino.sol";
import {ICasinoRandomizerProxy} from "../contracts/ICasinoRandomizerProxy.sol";

error ErrCallerMustBeCasinoContract();

contract MockRandomizerProxy is ICasinoRandomizerProxy, Ownable {

    ICasino public casino;

    function setCasinoAddress(address value) public onlyOwner {
        casino = ICasino(value);
    }

    function makeRequest() external payable returns(uint256) {
        if (msg.sender != address(casino)) {
            revert ErrCallerMustBeCasinoContract();
        }
        return uint256(12345999);
    }

    function estimateCallbackFee() external pure returns(uint256) {
        return 1000 gwei;
    }

    function randomizerCallback(uint256 requestFullId, bytes32 value) public onlyOwner {      
        uint256 randomNumber = (uint256(value) % 10000); // Convert random bytes to number between 0 and 9999
        randomNumber += 1; // Make it a random number between 1 and 10000
        casino.settleBet(requestFullId, randomNumber);
    }
}

