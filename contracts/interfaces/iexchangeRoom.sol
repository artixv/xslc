// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface iexchangeRoom{
    /// @title UserSummary
    /// @custom:field unlocking
    /// @custom:field unlocked
    struct UserSummary 
    {
        uint unlocking;
        uint unlocked;
    }
    function CFX_exchange_XCFX() external payable returns(uint);
    function XCFX_burn(uint _amount) external returns(uint, uint);
    function getback_CFX(uint _amount) external;
    function CFX_exchange_estim(uint _amount) external view returns(uint);
    function XCFX_burn_estim(uint _amount) external view returns(uint,uint);
}