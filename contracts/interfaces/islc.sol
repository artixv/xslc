// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30

pragma solidity 0.8.6;
interface iSlc{
    function mintSLC(address _account,uint256 _value) external;
    function burnSLC(address _account,uint256 _value) external;
}