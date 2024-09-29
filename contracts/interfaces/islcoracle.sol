// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30

pragma solidity 0.8.6;
interface iSlcOracle{
    function getPrice(address Token) external view returns (uint price);

}