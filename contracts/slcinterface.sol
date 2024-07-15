// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/islcvaults.sol";
import "./interfaces/iwxcfx.sol";
contract slcInterface  {
    address public superLibraCoin;
    address public slcVaults;
    address public wxCFX;

    address public setter;
    address newsetter;

    // struct licensedAsset{
    //     address  assetAddr;
    //     // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount for a home against the value of that property
    //     uint     maximumLTV;           // MAX = 10000
    //     uint     liquidationPenalty;   // MAX = 10000 ,default is 500(5%)
    //     // default is 0, means no limits; if > 0, have limits : 1 ether = 1 slc
    //     uint     maxDepositAmount;
    //     uint     mortgagedAmountDisposed;
    //     uint     mortgagedAmountReturned;
    // }
    //----------------------------modifier ----------------------------
    modifier onlySetter() {
        require(msg.sender == setter, 'SLC Vaults: Only Manager Use');
        _;
    }

    //------------------------------------------------------------------

    constructor() {
        setter = msg.sender;
    }
    function transferSetter(address _set) external onlySetter{
        newsetter = _set;
    }
    function acceptSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'SLC Vaults: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    function setup( address _superLibraCoin,
                    address _slcVaults,
                    address _wxCFX ) external onlySetter{
        superLibraCoin = _superLibraCoin;
        slcVaults = _slcVaults;
        wxCFX = _wxCFX;
    }

    function viewUsersHealthFactor(address user) public view returns(uint userHealthFactor, 
                                                                    uint userAssetsValue, 
                                                                    uint userBorrowedSLCAmount, 
                                                                    uint userAvailbleBorrowedSLCAmount){
        (userHealthFactor, 
         userAssetsValue,  
         userBorrowedSLCAmount, 
         userAvailbleBorrowedSLCAmount) = iSlcVaults(slcVaults).viewUsersHealthFactor(user);
         userHealthFactor = (userHealthFactor <= 1000 ether ? userHealthFactor : 1000 ether);
    }
    function usersRiskDetails(address user) external view returns(uint userHealthFactor, 
                                                      uint userValueUsedRatio, 
                                                      uint userMaxUsedRatio, 
                                                      uint tokenLiquidateRatio){
        uint[4] memory tempRustFactor;
        (tempRustFactor[0],tempRustFactor[1],tempRustFactor[2],tempRustFactor[3]) = viewUsersHealthFactor(user);
        userHealthFactor = tempRustFactor[0];
        if(tempRustFactor[1] > 0){
            userValueUsedRatio = tempRustFactor[2] * 10000 / tempRustFactor[1];
            userMaxUsedRatio =  (tempRustFactor[2] + tempRustFactor[3]) * 10000 / tempRustFactor[1];
        }else{
            userValueUsedRatio = 0;
            userMaxUsedRatio =  0;
        }
        
        address[] memory tokens;
        uint[] memory _amount;
        (tokens,_amount, ) = userAssetOverview(user);
        uint _count;
        iSlcVaults.licensedAsset memory usefulAsset;
        for(uint i=0;i<tokens.length;i++){
            if(_amount[i]>0){
                usefulAsset = licensedAssets(tokens[i]);
                tokenLiquidateRatio += usefulAsset.maximumLTV;
                _count += 1;
            }
        }
        if(_count > 1){
            tokenLiquidateRatio = tokenLiquidateRatio / _count;
        }
    }

    function licensedAssets(address token) public view returns(iSlcVaults.licensedAsset memory asset){
        asset = iSlcVaults(slcVaults).licensedAssets(token);
    }

    function licensedAssetOverview() public view returns(uint totalValueOfMortgagedAssets, 
                                                         uint _slcSupply, 
                                                         uint _slcValue){
        return iSlcVaults(slcVaults).licensedAssetOverview();
    }

    function userAssetOverview(address user) public view returns(address[] memory tokens, uint[] memory _amount, uint SLCborrowed){
        return iSlcVaults(slcVaults).userAssetOverview(user);
    }

    function assetsSerialNumber(uint num) external view returns(address){
        return iSlcVaults(slcVaults).assetsSerialNumber(num);
    }

    //---------------------------- User Setting Function --------------------------------

    function userModeSetting(uint8 _mode,address _userModeAssetsAddress) external{
        iSlcVaults(slcVaults).userModeSetting( _mode, _userModeAssetsAddress,msg.sender);
    }
    
    //---------------------------- User Used Function ----------------------------------
    function userMode(address user) external view returns(uint8 mode, address userSetAssets){
        mode = iSlcVaults(slcVaults).userMode(user);
        userSetAssets = iSlcVaults(slcVaults).userModeAssetsAddress(user);
    }
    
    function usersHealthFactorEstimate(address user,address token,uint amount,bool operator) external view returns(uint userHealthFactor){
        userHealthFactor = iSlcVaults(slcVaults).usersHealthFactorEstimate(user, token, amount, operator);
        userHealthFactor = (userHealthFactor <= 1000 ether ? userHealthFactor : 1000 ether);
    }
    
    function slcTokenBuyEstimateOut(address TokenAddr, uint amount) external view returns(uint outputAmount){
        return iSlcVaults(slcVaults).slcTokenBuyEstimateOut( TokenAddr, amount);
    }
    function slcTokenSellEstimateOut(address TokenAddr, uint amount) external view returns(uint outputAmount){
        return iSlcVaults(slcVaults).slcTokenSellEstimateOut( TokenAddr, amount);
    }
    function slcTokenBuyEstimateIn(address TokenAddr, uint amount) external view returns(uint inputAmount){
        return iSlcVaults(slcVaults).slcTokenBuyEstimateIn( TokenAddr, amount);
    }
    function slcTokenSellEstimateIn(address TokenAddr, uint amount) external view returns(uint inputAmount){
        return iSlcVaults(slcVaults).slcTokenSellEstimateIn( TokenAddr, amount);
    }

    function slcTokenBuy(address TokenAddr, uint amount) public  returns(uint outputAmount){
        IERC20(TokenAddr).transferFrom(msg.sender,address(this),amount);
        IERC20(TokenAddr).approve(slcVaults, amount);
        outputAmount = iSlcVaults(slcVaults).slcTokenBuy( TokenAddr, amount);

        if(IERC20(superLibraCoin).balanceOf(address(this))>0){
            IERC20(superLibraCoin).transfer(msg.sender,IERC20(superLibraCoin).balanceOf(address(this)));
        }
        if(IERC20(TokenAddr).balanceOf(address(this))>0){
            IERC20(TokenAddr).transfer(msg.sender,IERC20(TokenAddr).balanceOf(address(this)));
        }
    }
    function slcTokenSell(address TokenAddr, uint amount) public  returns(uint outputAmount){
        IERC20(superLibraCoin).transferFrom(msg.sender,address(this),amount);
        IERC20(superLibraCoin).approve(slcVaults, amount);
        outputAmount = iSlcVaults(slcVaults).slcTokenSell( TokenAddr, amount);

        if(IERC20(superLibraCoin).balanceOf(address(this))>0){
            IERC20(superLibraCoin).transfer(msg.sender,IERC20(superLibraCoin).balanceOf(address(this)));
        }
        if(IERC20(TokenAddr).balanceOf(address(this))>0){
            IERC20(TokenAddr).transfer(msg.sender,IERC20(TokenAddr).balanceOf(address(this)));
        }
    }
    //---------------------------- borrow & lend  Function----------------------------
    // licensed Assets Pledge
    function licensedAssetsPledge(address TokenAddr, uint amount) public {
        IERC20(TokenAddr).transferFrom(msg.sender,address(this),amount);
        IERC20(TokenAddr).approve(slcVaults, amount);
        iSlcVaults(slcVaults).licensedAssetsPledge( TokenAddr, amount, msg.sender);
    }
    // redeem Pledged Assets
    function redeemPledgedAssets(address TokenAddr, uint amount) public {
        iSlcVaults(slcVaults).redeemPledgedAssets( TokenAddr, amount, msg.sender);
        IERC20(TokenAddr).transfer(msg.sender,IERC20(TokenAddr).balanceOf(address(this)));
    }
    // obtain SLC coin
    function obtainSLC(uint amount) public {
        iSlcVaults(slcVaults).obtainSLC(amount, msg.sender);
        IERC20(superLibraCoin).transfer(msg.sender,amount);
    }
    // return SLC coin
    function returnSLC(uint amount) public {
        IERC20(superLibraCoin).transferFrom(msg.sender,address(this),amount);
        IERC20(superLibraCoin).approve(slcVaults, amount);
        iSlcVaults(slcVaults).returnSLC(amount, msg.sender);
    }
    function returnAllSLC() public {
        uint amount;
        (,,amount,) = viewUsersHealthFactor(msg.sender);
        IERC20(superLibraCoin).transferFrom(msg.sender,address(this),amount);
        IERC20(superLibraCoin).approve(slcVaults, amount);
        iSlcVaults(slcVaults).returnSLC(amount, msg.sender);
    }
    //---------------------------- CFX  Function----------------------------
    function buySlcByCFX() public payable returns(uint outputAmount){
        iwxCFX(wxCFX).deposit{value:msg.value}();
        IERC20(wxCFX).approve(slcVaults, msg.value);
        outputAmount = iSlcVaults(slcVaults).slcTokenBuy( wxCFX , msg.value);
        if(IERC20(superLibraCoin).balanceOf(address(this))>0){
            IERC20(superLibraCoin).transfer(msg.sender,IERC20(superLibraCoin).balanceOf(address(this)));
        }
        if(IERC20(wxCFX).balanceOf(address(this))>0){
            IERC20(wxCFX).transfer(msg.sender,IERC20(wxCFX).balanceOf(address(this)));
        }
    }
    function sellSlcToCFX(uint amount) public  returns(uint outputAmount){
        IERC20(superLibraCoin).transferFrom(msg.sender,address(this),amount);
        IERC20(superLibraCoin).approve(slcVaults, amount);
        outputAmount = iSlcVaults(slcVaults).slcTokenSell( wxCFX, amount);

        amount = IERC20(wxCFX).balanceOf(address(this));
        iwxCFX(wxCFX).withdraw(amount);
        address payable receiver = payable(msg.sender);
        (bool success, ) = receiver.call{value:amount}("");
        require(success,"X SLC Interface: CFX Transfer Failed");
        if(IERC20(superLibraCoin).balanceOf(address(this))>0){
            IERC20(superLibraCoin).transfer(msg.sender,IERC20(superLibraCoin).balanceOf(address(this)));
        }
    }

    // licensed Assets Pledge
    function CFXPledge() public payable {
        iwxCFX(wxCFX).deposit{value:msg.value}();
        IERC20(wxCFX).approve(slcVaults, msg.value);
        iSlcVaults(slcVaults).licensedAssetsPledge( wxCFX, msg.value, msg.sender);
    }
    // redeem Pledged Assets
    function redeemCFX(uint amount) public {
        iSlcVaults(slcVaults).redeemPledgedAssets( wxCFX, amount, msg.sender);
        iwxCFX(wxCFX).withdraw(amount);
        address payable receiver = payable(msg.sender);
        (bool success, ) = receiver.call{value:amount}("");
        require(success,"X SLC Interface: CFX Transfer Failed");
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}