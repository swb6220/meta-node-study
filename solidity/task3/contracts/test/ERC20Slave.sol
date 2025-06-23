// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Slave is ERC20 {
    constructor() ERC20("Token on slave", "TOS") {
        _mint(msg.sender, 50000000);
    }
}