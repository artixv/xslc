// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ixinterface.sol";
import "./interfaces/islc.sol";
import "./interfaces/islcoracle.sol";

contract slcVaults  {
    address public superLibraCoin;
    uint    public slcValue;
    uint    public slcUnsecuredIssuancesAmount;
    address public mainCollateralToken;

    address public xInterface;
    address public oracleAddr;

    address public setter;
    address newsetter;
    address public rebalancer;

    //  Assets Init:   USDT  USDC  BTC  ETH  CFX  xCFX sxCFX NUT  CFXs
    //  MaximumLTV:     95%   95%  90%  85%  65%  65%   75%  55%  55%
    //  LiqPenalty:      5%    5%   5%   5%   5%   5%    5%   5%   5%
    //MaxDepositAmount:  0     0    0    0    0    0      0  1e6  1e6


    struct licensedAsset{
        address  assetAddr;             
        uint     maximumLTV;           // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount 
                                       // for a home against the value of that property.(MAX = 10000) 
        uint     liquidationPenalty;   // MAX = 10000 ,default is 500(5%)
        uint     maxDepositAmount;     // default is 0, means no limits; if > 0, have limits : 1 ether = 1 slc
        uint     mortgagedAmountDisposed;
        uint     mortgagedAmountReturned;
    }

    mapping(address => licensedAsset) public licensedAssets;
    address[] public assetsSerialNumber;
    
    // address is user address, second address is licensedAssets address,  uint is the amount of assets
    mapping(address => mapping(address => uint)) public userAssetsMortgageAmount;
    mapping(address => uint) public userAssetsMortgageAmountSum;
    mapping(address => uint) public userObtainedSLCAmount;
    mapping(address => uint) public riskIsolationModeAmount;

    mapping(address => uint8) public userMode; // 0 High liquidity collateral mode; 1 Risk isolation mode
    mapping(address => address) public userModeAssetsAddress; 

    mapping(address => bool) public slcInterface;
    //----------------------------modifier ----------------------------
    modifier onlySetter() {
        require(msg.sender == setter, 'SLC Vaults: Only Manager Use');
        _;
    }

    modifier onlyRebalancer() {
        require(msg.sender == rebalancer, 'SLC Vaults: Only Rebalancer Use');
        _;
    }
    //----------------------------- event -----------------------------
    event UserModeSetting(address indexed msgSender, uint8 _mode,address _userModeAssetsAddress);

    event SlcTokenBuy(address indexed buyer,address TokenAddr, uint amount,uint outputAmount);
    event SlcTokenSell(address indexed seller,address TokenAddr, uint amount, uint outputAmount);
    event LicensedAssetsPledge(address indexed msgSender, address TokenAddr, uint amount, address user);
    event RedeemPledgedAssets(address indexed msgSender, address TokenAddr, uint amount, address user);
    event ObtainSLC(address indexed msgSender, uint amount, address user) ;
    event ReturnSLC(address indexed msgSender, uint amount, address user) ;

    event TokenLiquidate(address indexed user,address token, uint amount, uint outputAmount) ;

    //------------------------------------------------------------------

    constructor() {
        setter = msg.sender;
        slcValue = 1 ether;
        rebalancer = msg.sender;
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
    function setRebalancer(address _rebalancer) external onlySetter{
        rebalancer = _rebalancer;
    }
    function setup( address _superLibraCoin,
                    address _mainCollateralToken,
                    address _xInterface,
                    address _oracleAddr ) external onlySetter{
        superLibraCoin = _superLibraCoin;
        mainCollateralToken = _mainCollateralToken;
        xInterface = _xInterface;
        oracleAddr = _oracleAddr;
    }
    function setSlcInterface(address _ifSlcInterface, bool _ToF) external onlySetter{
        slcInterface[_ifSlcInterface] = _ToF;
    }

    // Evaluate the value of superLibraCoin
    function slcValueRevaluate(uint newVaule) public  onlySetter {
        slcValue = newVaule;
    }

    function mainCollateralTokenSetting(address token) public  onlySetter {
        mainCollateralToken = token;
    }
    function licensedAssetsRegister(address _asset, uint MaxLTV, uint LiqPenalty,uint MaxDepositAmount) public onlySetter {
        require(licensedAssets[_asset].assetAddr == address(0),"SLC Vaults: asset already registered!");
        require(assetsSerialNumber.length < 100,"SLC Vaults: Too Many Assets");
        assetsSerialNumber.push(_asset);
        licensedAssets[_asset].assetAddr = _asset;
        licensedAssets[_asset].maximumLTV = MaxLTV;
        licensedAssets[_asset].liquidationPenalty = LiqPenalty;
        licensedAssets[_asset].maxDepositAmount = MaxDepositAmount;
    }
    function licensedAssetsReset(address _asset, uint MaxLTV, uint LiqPenalty,uint MaxDepositAmount) public onlySetter {
        require(licensedAssets[_asset].assetAddr == _asset,"SLC Vaults: asset is Not registered!");
        licensedAssets[_asset].maximumLTV = MaxLTV;
        licensedAssets[_asset].liquidationPenalty = LiqPenalty;
        licensedAssets[_asset].maxDepositAmount = MaxDepositAmount;
    }

    function userModeSetting(uint8 _mode,address _userModeAssetsAddress,address user) public {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(userObtainedSLCAmount[user] == 0,"SLC Vaults: Cant Change Mode before return all SLC.");
        userMode[user] = _mode;
        userModeAssetsAddress[user] = _userModeAssetsAddress;
        emit UserModeSetting(user, _mode, _userModeAssetsAddress);
    }

    //----------------------------- View Function------------------------------------
    function viewUsersHealthFactor(address user) public view returns(uint userHealthFactor, uint userAssetsValue, uint userBorrowedSLCAmount, uint userAvailbleBorrowedSLCAmount){
        uint[2] memory tempValue;
        uint[2] memory tempLoanToValue;
        require(assetsSerialNumber.length < 100,"SLC Vaults: Too Many Assets");
         
        for(uint i=0;i<assetsSerialNumber.length;i++){
            if(licensedAssets[assetsSerialNumber[i]].maxDepositAmount == 0){
                tempValue[0] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
                tempLoanToValue[0] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                    * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
            }else if(userModeAssetsAddress[user]==assetsSerialNumber[i]){
                tempValue[1] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
                tempLoanToValue[1] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                    * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
            }
        }
        
        userBorrowedSLCAmount = userObtainedSLCAmount[user];
        userAssetsValue = tempValue[0] + tempValue[1];

        if(userObtainedSLCAmount[user] > 0){
            if(userMode[user] == 0){
                userHealthFactor = (tempLoanToValue[0] * 1 ether / userObtainedSLCAmount[user]) * slcValue / 1 ether;
                userAvailbleBorrowedSLCAmount = tempLoanToValue[0] * 1 ether / 1.2 ether;
            }else{
                userHealthFactor = (tempLoanToValue[1] * 1 ether / userObtainedSLCAmount[user]) * slcValue / 1 ether;
                userAvailbleBorrowedSLCAmount = tempLoanToValue[1] * 1 ether / 1.2 ether;
            }
        }else{
            userHealthFactor = 1000 ether;
            if(userMode[user] == 0){
                userAvailbleBorrowedSLCAmount = tempLoanToValue[0] * 1 ether / 1.2 ether;
            }else{
                userAvailbleBorrowedSLCAmount = tempLoanToValue[1] * 1 ether / 1.2 ether;
            }
        }
        
        if(userBorrowedSLCAmount >= userAvailbleBorrowedSLCAmount){
            userAvailbleBorrowedSLCAmount = 0;
        }else{
            userAvailbleBorrowedSLCAmount -= userBorrowedSLCAmount;
        }
    }

    function licensedAssetOverview() public view returns(uint totalValueOfMortgagedAssets, uint _slcSupply, uint _slcValue){
        require(assetsSerialNumber.length < 100,"");
        for(uint i=0;i<assetsSerialNumber.length;i++){
            totalValueOfMortgagedAssets += IERC20(assetsSerialNumber[i]).balanceOf(address(this)) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
        }
        _slcSupply = IERC20(superLibraCoin).totalSupply();
        _slcValue = slcValue;
    }

    function userAssetOverview(address user) public view returns(uint[] memory _amount, uint SLCborrowed){
        require(assetsSerialNumber.length < 100,"SLC Vaults: Too Many Assets");
        _amount = new uint[](assetsSerialNumber.length);
        for(uint i=0;i<assetsSerialNumber.length;i++){
            _amount[i] = userAssetsMortgageAmount[user][assetsSerialNumber[i]];
        }
        SLCborrowed = userObtainedSLCAmount[user];
    }
    
    //---------------------------- User Used Function--------------------------------
    function slcTokenBuyEstimate(address TokenAddr, uint amount) public view returns(uint outputAmount){
        // outputAmount = ixInterface(xInterface).xExchangeEstimateInput(address[] memory tokens,uint amountIn);
        address[] memory tokens = new address[](3);

        tokens[0] = TokenAddr;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        if(tokens[0] == tokens[2]){
            outputAmount = amount * 1 ether * 99 / (100 * slcValue);
        }else{
            (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
            outputAmount = outputAmount * 1 ether * 98 / (100 * slcValue);
        }
    }

    function slcTokenSellEstimate(address TokenAddr, uint amount) public view returns(uint outputAmount){
        // outputAmount = ixInterface(xInterface).swapCalculation2(_lp, slc, amount);
        address[] memory tokens = new address[](2);

        tokens[0] = superLibraCoin;
        tokens[1] = TokenAddr;

        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = outputAmount * 95 / 100;
    }
    //---------------------------- Mint&Burn Function--------------------------------
    // Use licensedAssets to mint SLC
    function slcTokenBuy(address TokenAddr, uint amount) public returns(uint outputAmount){
        address[] memory tokens = new address[](3);
        tokens[0] = TokenAddr;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        IERC20(TokenAddr).transferFrom(msg.sender,address(this),amount);
        IERC20(TokenAddr).approve(xInterface, amount);
        
        if(tokens[0] == tokens[2]){
            outputAmount = amount * 1 ether * 99 / (100 * slcValue);
        }else{
            outputAmount = ixInterface(xInterface).xexchange(tokens,amount,outputAmount,outputAmount / 100, block.timestamp + 100);
            outputAmount = outputAmount * 1 ether * 98 / (100 * slcValue);
        }

        iSlc(superLibraCoin).mintSLC(msg.sender,outputAmount);
        slcUnsecuredIssuancesAmount += outputAmount;
        emit SlcTokenBuy(msg.sender, TokenAddr, amount, outputAmount);
    
    }

    // Get back 95% of values in SLC
    function slcTokenSell(address TokenAddr, uint amount) public  returns(uint outputAmount) {
        iSlc(superLibraCoin).burnSLC(msg.sender,amount);
        if(slcUnsecuredIssuancesAmount > amount){
            slcUnsecuredIssuancesAmount -= amount;
        }else{
            slcUnsecuredIssuancesAmount = 0;
        }

        address[] memory tokens = new address[](2);
        tokens[0] = superLibraCoin;
        tokens[1] = TokenAddr;
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = outputAmount * 95 / 100 ;

        address[] memory tokensT = new address[](3);
        tokensT[0] = mainCollateralToken;
        tokensT[1] = superLibraCoin;
        tokensT[2] = TokenAddr;
        (amount,) = ixInterface(xInterface).xExchangeEstimateOutput(tokensT, outputAmount);

        IERC20(mainCollateralToken).approve(xInterface, amount);
        outputAmount = ixInterface(xInterface).xexchange(tokensT,amount,outputAmount,outputAmount / 50, block.timestamp + 100);
        IERC20(TokenAddr).transfer(msg.sender,outputAmount);
        emit SlcTokenSell(msg.sender, TokenAddr, amount, outputAmount);
    
    }

    //---------------------------- borrow & lend  Function----------------------------
    // licensed Assets Pledge
    function licensedAssetsPledge(address TokenAddr, uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        if(licensedAssets[TokenAddr].maxDepositAmount == 0){
            require(userMode[user] == 0,"SLC Vaults: Wrong Mode, Need a  Popular Mode");
        }else{
            require((TokenAddr == userModeAssetsAddress[user]) && (userMode[user] == 1),"SLC Vaults: Wrong Mode, Need a  Non-Popular Mode");
        }
        IERC20(TokenAddr).transferFrom(msg.sender,address(this),amount);
        userAssetsMortgageAmount[user][TokenAddr] += amount;
        userAssetsMortgageAmountSum[TokenAddr] += amount;
        emit LicensedAssetsPledge(msg.sender, TokenAddr, amount, user);
    
    }

    // redeem Pledged Assets
    function redeemPledgedAssets(address TokenAddr, uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        if(licensedAssets[TokenAddr].maxDepositAmount == 0){
            require(userMode[user] == 0,"SLC Vaults: Wrong Mode, Need a  Popular Mode");
        }else{
            require((TokenAddr == userModeAssetsAddress[user]) && (userMode[user] == 1),"SLC Vaults: Wrong Mode, Need a  Non-Popular Mode");
        }
        userAssetsMortgageAmount[user][TokenAddr] -= amount;
        userAssetsMortgageAmountSum[TokenAddr] -= amount;
        uint factor;
        IERC20(TokenAddr).transfer(msg.sender,amount);
        (factor, ,,) = viewUsersHealthFactor(user);
        require( factor >= 1.2 ether,"Your Health Factor <= 1.2, Cant redeem assets");
        emit RedeemPledgedAssets(msg.sender, TokenAddr, amount, user);
    
    }

    // obtain SLC coin
    function obtainSLC(uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        uint factor;
        iSlc(superLibraCoin).mintSLC(msg.sender,amount);
        userObtainedSLCAmount[user] += amount;
        if(userMode[user] == 1){
            riskIsolationModeAmount[userModeAssetsAddress[user]] += amount;
            require(riskIsolationModeAmount[userModeAssetsAddress[user]] <= licensedAssets[userModeAssetsAddress[user]].maxDepositAmount,"Amount Exceed Limit");
        }
        (factor, ,,) = viewUsersHealthFactor(user);
        require(factor >= 1.2 ether,"Your Health Factor <= 1.2, Cant obtain SLC");
        emit ObtainSLC(msg.sender, amount, user) ;
    
    }

    // return SLC coin
    function returnSLC(uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
            require(amount <= IERC20(superLibraCoin).balanceOf(user),"SLC Vaults: amount need <= balance Of user.");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        
        userObtainedSLCAmount[user] -= amount;
        iSlc(superLibraCoin).burnSLC(msg.sender, amount);
        emit ReturnSLC(msg.sender, amount, user);

    }

    // Token Rebalance 
    function rebalance(address[] memory tokens, uint amount) public onlyRebalancer() returns(uint outputAmount){
        IERC20(tokens[0]).approve(xInterface, amount);
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = ixInterface(xInterface).xexchange(tokens,amount,outputAmount,outputAmount / 100, block.timestamp + 100);
    }
    // Assets excess Disposal
    function excessDisposal(address token, uint amount) public onlyRebalancer(){
        require(IERC20(token).balanceOf(address(this)) > amount + userAssetsMortgageAmountSum[token],"SLC Vaults: Cant Do Excess Disposal, asset not enough!");
        IERC20(token).transfer(msg.sender,amount);
        licensedAssets[token].mortgagedAmountDisposed += amount;
    }
    function excessAssetsReturn(address token, uint amount) public onlyRebalancer(){
        // require(IERC20(token).balanceOf(address(this)) > amount + userAssetsMortgageAmountSum[token],"SLC Vaults: Cant Do Excess Disposal, asset not enough!");
        IERC20(token).transfer(msg.sender,amount);
        licensedAssets[token].mortgagedAmountReturned += amount;
    }

    //------------------------------ Liquidate Function------------------------------
    // token Liquidate
    function tokenLiquidate(address user,address token, uint amount) public returns(uint outputAmount) {
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        require(amount <= userAssetsMortgageAmount[user][token],"SLC Vaults: amount need <= balance Of user");
        uint factor;
        (factor, ,,) = viewUsersHealthFactor(user);
        require(factor < 1 ether,"SLC Vaults: Liquidate user Assets, his Health Factor must < 1");
        address[] memory tokens = new address[](3);

        tokens[0] = token;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        IERC20(token).approve(xInterface, amount);
        
        if(tokens[0] == mainCollateralToken){
            outputAmount = amount * 1 ether * (10000-licensedAssets[token].liquidationPenalty) / (10000 * slcValue);
        }else{
            (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
            outputAmount = ixInterface(xInterface).xexchange(tokens, amount, outputAmount, outputAmount / 100, block.timestamp + 100);
            outputAmount = outputAmount * 1 ether * (10000-licensedAssets[token].liquidationPenalty) / (10000 * slcValue);
        }
        
        require(userObtainedSLCAmount[user] >= outputAmount,"");
        slcUnsecuredIssuancesAmount += outputAmount;
        userObtainedSLCAmount[user] -= outputAmount;
        userAssetsMortgageAmountSum[token] -= amount;
        userAssetsMortgageAmount[user][token] -= amount;

        IERC20(token).transfer(msg.sender,amount/10000);
        // address payable receiver = payable(msg.sender);
        // (bool success, ) = receiver.call{value:0.1 ether}("");
        // require(success,"SLC Vaults: CFX Transfer Failed");
        emit TokenLiquidate(msg.sender, token, amount, outputAmount);
    }
    function tokenLiquidateEstimate(address user,address token) public view returns(uint maxAmount){
        uint factor;
        uint tempAmount = userObtainedSLCAmount[user];//userAssetsMortgageAmount[user][token];
        (factor, ,,) = viewUsersHealthFactor(user);
        if(factor >= 1 ether){
            return 0;
        }
        address[] memory tokens = new address[](3);

        tokens[0] = token;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        if(tokens[0] == mainCollateralToken){
            maxAmount = tempAmount * 1 ether * (10000 - licensedAssets[token].liquidationPenalty) / (10000 * slcValue);
        }else{
            (maxAmount,) = ixInterface(xInterface).xExchangeEstimateOutput(tokens, tempAmount);
            maxAmount = maxAmount * 1 ether * (10000 - licensedAssets[token].liquidationPenalty) / (10000 * slcValue);
        }
        if(maxAmount > userAssetsMortgageAmount[user][token]){
            maxAmount = userAssetsMortgageAmount[user][token];
        }
        
    }
}