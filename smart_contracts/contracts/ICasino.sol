// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

interface ICasino {
    function settleBet(uint256 betId, uint256 randomValue) external;
    function updateRandomizerCallbackFee() external;
}
