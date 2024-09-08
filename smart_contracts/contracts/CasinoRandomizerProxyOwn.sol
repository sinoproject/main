// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import {Ownable} from "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts@4.7.3/utils/math/Math.sol";
import {ICasino} from "./ICasino.sol";
import {ICasinoRandomizerProxy} from "./ICasinoRandomizerProxy.sol";

error ErrInvalidCaller();
error ErrInvalidRandomNumber();
error ErrSendingEth();

contract CasinoRandomizerProxyOwn is ICasinoRandomizerProxy, Ownable {

    ICasino public casino;
    address public oracleOperator;
    uint256 public callbackGasLimit = 300000;
    uint256 public gasPriceWei = 20000000;
    uint256 public lastRequestId = 3;

    event RequestReceived(
        uint256 indexed requestId
    );

    event RequestFulfilled(
        uint256 indexed requestId,
        uint256 randomNumber
    );

    function setOracleOperatorAddress(address value) public onlyOwner {
        oracleOperator = value;
    }

    function setCasinoAddress(address value) public onlyOwner {
        casino = ICasino(value);
    }

    function setCallbackGasLimit(uint256 value) public {
        if(msg.sender != owner() && msg.sender != oracleOperator) {
            revert ErrInvalidCaller();
        }
        callbackGasLimit = value;
    }

    function setGasPriceWei(uint256 value, bool triggerCasinoUpdateRandomizerCallbackFee) public {
        if(msg.sender != owner() && msg.sender != oracleOperator) {
            revert ErrInvalidCaller();
        }
        gasPriceWei = value;

        if (triggerCasinoUpdateRandomizerCallbackFee == true) {
            casino.updateRandomizerCallbackFee();
        }
    }

    function estimateCallbackFee() external view returns(uint256) {
        return gasPriceWei * callbackGasLimit;
    }

    function makeRequest() external payable returns(uint256) {
        if(msg.sender != address(casino)) {
            revert ErrInvalidCaller();
        }

        // Forward received ETH to oracleOperator to cover randomizerCallback() costs
        if (msg.value > 0) {
            (bool sent, bytes memory data) = oracleOperator.call{ value: msg.value }("");
            if(sent != true) {
                revert ErrSendingEth();
            }
            data = "";
        }

        // Emit event that oracleOperator reads offchain to then trigger randomizerCallback()
        ++lastRequestId;
        emit RequestReceived(lastRequestId);
        return lastRequestId;
    }

    function randomizerCallback(uint256 requestId, uint256 randomNumber) external {
        if(msg.sender != oracleOperator) {
            revert ErrInvalidCaller();
        }
        if(randomNumber < 1 || randomNumber > 10000) {
            revert ErrInvalidRandomNumber();
        }
        casino.settleBet(requestId, randomNumber);
        emit RequestFulfilled(requestId, randomNumber);
    }
}
