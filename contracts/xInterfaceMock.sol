// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract xInterfaceMock {

    // factory
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        return address(this);
    }

    // vaults
    function getLpPrice(address _lp) external view returns (uint ) {
        return 0;
    }
}