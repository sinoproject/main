// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19.0;

import {ERC20} from "@openzeppelin/contracts@4.7.3/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable@4.7.3/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import {ICasinoToken} from "./ICasinoToken.sol";

contract CasinoToken is ERC20, ICasinoToken, Initializable, Ownable {

    constructor() ERC20("SINOTN02", "SINOTN02") {}

    function initialize() public payable initializer onlyOwner {
        _mint(msg.sender, 10000000 * 10**18);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function transferOnBehalf(address from, address to, uint256 amount) public onlyOwner {
        _transfer(from, to, amount);
    }
}
