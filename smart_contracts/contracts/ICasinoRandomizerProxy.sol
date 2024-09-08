// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

interface ICasinoRandomizerProxy {
    function makeRequest() external payable returns(uint256);
    function estimateCallbackFee() external returns(uint256);
}
