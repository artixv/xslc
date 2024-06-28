// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
interface iSlcOracle{
    function getPrice(address Token) external view returns (uint price);

}