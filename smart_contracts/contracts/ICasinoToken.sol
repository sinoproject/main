// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import {IERC20} from "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";

interface ICasinoToken is IERC20 {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function transferOnBehalf(address from, address to, uint256 amount) external;
}
