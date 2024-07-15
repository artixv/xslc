// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
interface iRewardMini{
    function recordUpdate(address _userAccount,uint _value) external returns(bool);
    function factoryUsedCoinRegist(address _token, uint256 _type) external returns(bool);
}