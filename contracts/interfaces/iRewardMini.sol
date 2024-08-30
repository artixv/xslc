// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30

pragma solidity 0.8.6;
interface iRewardMini{
    function recordUpdate(address _userAccount,uint _value) external returns(bool);
    function factoryUsedCoinRegist(address _token, uint256 _type) external returns(bool);
}