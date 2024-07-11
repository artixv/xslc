// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
interface iSlcVaults{
    struct licensedAsset{
        address  assetAddr;
        // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount for a home against the value of that property
        uint     maximumLTV;           // MAX = 10000
        uint     liquidationPenalty;   // MAX = 10000 ,default is 500(5%)
        // default is 0, means no limits; if > 0, have limits : 1 ether = 1 slc
        uint     maxDepositAmount;
        uint     mortgagedAmountDisposed;
        uint     mortgagedAmountReturned;
    }

    //----------------------------- View Function------------------------------------
    function viewUsersHealthFactor(address user) external view returns(uint userHealthFactor, uint userAssetsValue, uint userBorrowedSLCAmount, uint userAvailbleBorrowedSLCAmount);
    function licensedAssetOverview() external view returns(uint totalValueOfMortgagedAssets, uint _slcSupply, uint _slcValue);
    function userAssetOverview(address user) external view returns(address[] memory tokens, uint[] memory amounts, uint SLCborrowed);

    function assetsSerialNumber(uint) external view returns(address);
    function usersHealthFactorEstimate(address user,address token,uint amount,bool operator) external view returns(uint userHealthFactor);
    function userMode(address user) external view returns(uint8);
    function userModeAssetsAddress(address user) external view returns(address);
 
    //-------------------------------mode setting------------------------------------
    function userModeSetting(uint8 _mode,address _userModeAssetsAddress,address user) external;
    //---------------------------- User Used Function--------------------------------
    function slcTokenBuyEstimateOut(address TokenAddr, uint amount) external view returns(uint outputAmount);
    function slcTokenSellEstimateOut(address TokenAddr, uint amount) external view returns(uint outputAmount);
    function slcTokenBuyEstimateIn(address TokenAddr, uint amount) external view returns(uint inputAmount);
    function slcTokenSellEstimateIn(address TokenAddr, uint amount) external view returns(uint inputAmount);

    function slcTokenBuy(address TokenAddr, uint amount) external  returns(uint outputAmount);
    function slcTokenSell(address TokenAddr, uint amount) external  returns(uint outputAmount);
    //---------------------------- borrow & lend  Function----------------------------
    // licensed Assets Pledge
    function licensedAssetsPledge(address TokenAddr, uint amount, address user) external ;
    // redeem Pledged Assets
    function redeemPledgedAssets(address TokenAddr, uint amount, address user) external ;
    // obtain SLC coin
    function obtainSLC(uint amount, address user) external ;
    // return SLC coin
    function returnSLC(uint amount, address user) external ;

}