// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EventToken is Context, ERC20 {
    constructor() ERC20("EventToken", "EVNT") {
        _mint(_msgSender(), 10000 * (10**uint256(decimals())));
    }
}