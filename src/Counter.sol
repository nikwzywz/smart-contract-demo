// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public amount;

    function setNumber(uint256 newNumber) public {
        amount = newNumber;
    }

    function increment() public {
        amount++;
    }

    function double() public {
        amount = amount * 2;
    }
}
