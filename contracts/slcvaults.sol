// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30

pragma solidity 0.8.6;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ixinterface.sol";
import "./interfaces/islc.sol";
import "./interfaces/islcoracle.sol";
import "./interfaces/iRewardMini.sol";
import "./interfaces/iDecimals.sol";

contract slcVaults  {
    using SafeERC20 for IERC20;

    address public superLibraCoin;
    uint    public slcValue;
    uint    public slcUnsecuredIssuancesAmount;
    address public mainCollateralToken;

    address public xInterface;
    address public oracleAddr;
    address public rewardContract;

    address public setter;
    address newsetter;
    address public rebalancer;

    uint public latestBlockNumber;
    address public latestBlockUser;

    //  Assets Init:   USDT  USDC  BTC  ETH  CFX  xCFX sxCFX NUT  CFXs
    //  MaximumLTV:     95%   95%  90%  85%  65%  65%   75%  55%  55%
    //  LiqPenalty:      5%    5%   5%   5%   5%   5%    5%   5%   5%
    //MaxDepositAmount:  0     0    0    0    0    0      0  1e6  1e6


    struct licensedAsset{
        address  assetAddr;             
        uint     maximumLTV;           // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount 
                                       // for a home against the value of that property.(MAX = 10000) 
        uint     liquidationPenalty;   // MAX = 2000 ,default is 500(5%)
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
    event LicensedAssetsSetting(address indexed asset, uint MaxLTV, uint LiqPenalty,uint MaxDepositAmount);
    event UserModeSetting(address indexed msgSender, uint8 _mode,address _userModeAssetsAddress);
    event SlcInterfaceSetup(address indexed _interface, bool _ToF);
    event SlcTokenBuy(address indexed buyer,address tokenAddr, uint amount,uint outputAmount);
    event SlcTokenSell(address indexed seller,address tokenAddr, uint amount, uint outputAmount);
    event LicensedAssetsPledge(address indexed msgSender, address tokenAddr, uint amount, address user);
    event RedeemPledgedAssets(address indexed msgSender, address tokenAddr, uint amount, address user);
    event ObtainSLC(address indexed msgSender, uint amount, address user) ;
    event ReturnSLC(address indexed msgSender, uint amount, address user) ;

    event SlCValue(uint value);
    event MainCollateralToken(address token);
    event Rebalance(address[] tokens, uint amount, uint outputAmount);
    event MortgagedAmountDisposed(address indexed token, uint amount);
    event MortgagedAmountReturned(address indexed token, uint amount);

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
    function rewardContractSetup(address _rewardContract) external onlySetter{
        rewardContract = _rewardContract;
    }
    function setSlcInterface(address _ifSlcInterface, bool _ToF) external onlySetter{
        slcInterface[_ifSlcInterface] = _ToF;
        emit SlcInterfaceSetup(_ifSlcInterface, _ToF);
    }

    // Evaluate the value of superLibraCoin
    function slcValueRevaluate(uint newVaule) public  onlySetter {
        slcValue = newVaule;
        emit SlCValue(newVaule);
    }

    function mainCollateralTokenSetting(address token) public  onlySetter {
        mainCollateralToken = token;
        emit MainCollateralToken(token);
    }
    function licensedAssetsRegister(address _asset, uint MaxLTV, uint LiqPenalty,uint MaxDepositAmount) public onlySetter {
        require(licensedAssets[_asset].assetAddr == address(0),"SLC Vaults: asset already registered!");
        require(assetsSerialNumber.length < 60,"SLC Vaults: Too Many Assets");
        require(MaxLTV < 10000,"SLC Vaults: MaxLTV < 10000");
        require(LiqPenalty <= 2000,"SLC Vaults: LiqPenalty <= 2000");
        assetsSerialNumber.push(_asset);
        licensedAssets[_asset].assetAddr = _asset;
        licensedAssets[_asset].maximumLTV = MaxLTV;
        licensedAssets[_asset].liquidationPenalty = LiqPenalty;
        licensedAssets[_asset].maxDepositAmount = MaxDepositAmount;
        emit LicensedAssetsSetting(_asset, MaxLTV, LiqPenalty, MaxDepositAmount);
    }
    function licensedAssetsReset(address _asset, uint MaxLTV, uint LiqPenalty,uint MaxDepositAmount) public onlySetter {
        require(licensedAssets[_asset].assetAddr == _asset,"SLC Vaults: asset is Not registered!");
        require(MaxLTV < 10000,"SLC Vaults: MaxLTV < 10000");
        require(LiqPenalty <= 2000,"SLC Vaults: LiqPenalty <= 2000");
        licensedAssets[_asset].maximumLTV = MaxLTV;
        licensedAssets[_asset].liquidationPenalty = LiqPenalty;
        licensedAssets[_asset].maxDepositAmount = MaxDepositAmount;
        emit LicensedAssetsSetting(_asset, MaxLTV, LiqPenalty, MaxDepositAmount);
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
        // require(assetsSerialNumber.length < 100,"SLC Vaults: Too Many Assets");
        // userAssetsMortgageAmount[user][assetsSerialNumber[i]] :: userAssetsMortgageAmount[user][assetsSerialNumber[i]] * 1 ether / iDecimals(tokenAddr).decimals()
        for(uint i=0;i<assetsSerialNumber.length;i++){
            if(licensedAssets[assetsSerialNumber[i]].maxDepositAmount == 0){
                tempValue[0] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals();
                tempLoanToValue[0] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                    * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
            }else if(userModeAssetsAddress[user]==assetsSerialNumber[i]){
                tempValue[1] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals();
                tempLoanToValue[1] += userAssetsMortgageAmount[user][assetsSerialNumber[i]] * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                    * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
            }
        }
        
        userBorrowedSLCAmount = userObtainedSLCAmount[user];
        userAssetsValue = tempValue[0] + tempValue[1];

        if(userObtainedSLCAmount[user] > 0){
            if(userMode[user] == 0){
                userHealthFactor = (tempLoanToValue[0] / userObtainedSLCAmount[user]) * slcValue;
                userAvailbleBorrowedSLCAmount = tempLoanToValue[0] * 10 / 12;
            }else{
                userHealthFactor = (tempLoanToValue[1] / userObtainedSLCAmount[user]) * slcValue;
                userAvailbleBorrowedSLCAmount = tempLoanToValue[1] * 10 / 12;
            }
        }else{
            userHealthFactor = 1000 ether;
            if(userMode[user] == 0){
                userAvailbleBorrowedSLCAmount = tempLoanToValue[0] * 10 / 12;
            }else{
                userAvailbleBorrowedSLCAmount = tempLoanToValue[1] * 10 / 12;
            }
        }
        
        if(userBorrowedSLCAmount >= userAvailbleBorrowedSLCAmount){
            userAvailbleBorrowedSLCAmount = 0;
        }else{
            userAvailbleBorrowedSLCAmount -= userBorrowedSLCAmount;
        }
    }

    function licensedAssetOverview() public view returns(uint totalValueOfMortgagedAssets, uint _slcSupply, uint _slcValue){
        // require(assetsSerialNumber.length < 100,"");
        for(uint i=0;i<assetsSerialNumber.length;i++){
            totalValueOfMortgagedAssets += IERC20(assetsSerialNumber[i]).balanceOf(address(this)) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
        }
        _slcSupply = IERC20(superLibraCoin).totalSupply();
        _slcValue = slcValue;
    }

    function userAssetOverview(address user) public view returns(address[] memory tokens, uint[] memory amounts, uint SLCborrowed){

        amounts = new uint[](assetsSerialNumber.length);
        tokens = new address[](assetsSerialNumber.length);
        for(uint i=0;i<assetsSerialNumber.length;i++){
            tokens[i] = assetsSerialNumber[i];
            amounts[i] = userAssetsMortgageAmount[user][tokens[i]];
        }
        SLCborrowed = userObtainedSLCAmount[user];
    }
    
    //---------------------------- User Used Function--------------------------------
    function slcTokenBuyEstimateOut(address tokenAddr, uint amount) public view returns(uint outputAmount){
        // uint amountNormalize = amount * 1 ether / iDecimals(tokenAddr).decimals();

        address[] memory tokens = new address[](3);

        tokens[0] = tokenAddr;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        if(tokens[0] == tokens[2]){
            outputAmount = amount * 1 ether * 99 / (100 * slcValue);
        }else{
            (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
            outputAmount = outputAmount * 1 ether * 99 / (100 * slcValue);
        }
    }

    function slcTokenSellEstimateOut(address tokenAddr, uint amount) public view returns(uint outputAmount){

        address[] memory tokens = new address[](2);

        tokens[0] = superLibraCoin;
        tokens[1] = tokenAddr;

        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = outputAmount * 96 / 100;
    }
    function slcTokenBuyEstimateIn(address tokenAddr, uint amount) public view returns(uint inputAmount){

        address[] memory tokens = new address[](3);

        tokens[0] = tokenAddr;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        if(tokens[0] == tokens[2]){
            inputAmount = amount * 1 ether / iDecimals(tokenAddr).decimals() * 1 ether * 100 / (99 * slcValue);
        }else{
            (inputAmount,) = ixInterface(xInterface).xExchangeEstimateOutput(tokens, amount * 1 ether * 100 / (99 * slcValue));
        }
    }

    function slcTokenSellEstimateIn(address tokenAddr, uint amount) public view returns(uint inputAmount){

        address[] memory tokens = new address[](2);

        tokens[0] = superLibraCoin;
        tokens[1] = tokenAddr;

        (inputAmount,) = ixInterface(xInterface).xExchangeEstimateOutput(tokens, amount * 100 / 96);
    }
    //---------------------------- Mint&Burn Function--------------------------------
    // Use licensedAssets to mint SLC
    function slcTokenBuy(address tokenAddr, uint amount) public returns(uint outputAmount){
        address[] memory tokens = new address[](3);
        tokens[0] = tokenAddr;
        tokens[1] = superLibraCoin;
        tokens[2] = mainCollateralToken;
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput( tokens, amount);
        IERC20(tokenAddr).safeTransferFrom(msg.sender,address(this), amount);
        IERC20(tokenAddr).approve(xInterface, amount);
        
        if(tokens[0] == tokens[2]){
            outputAmount = amount * 1 ether / iDecimals(tokenAddr).decimals() * 1 ether * 99 / (100 * slcValue);//iDecimals(tokenAddr).decimals();
        }else{
            outputAmount = ixInterface(xInterface).xexchange(tokens, amount, outputAmount, outputAmount / 100, block.timestamp + 100);
            outputAmount = outputAmount * 1 ether * 99 / (100 * slcValue);
        }

        iSlc(superLibraCoin).mintSLC(msg.sender, outputAmount);
        slcUnsecuredIssuancesAmount += outputAmount;
        emit SlcTokenBuy(msg.sender, tokenAddr, amount, outputAmount);
    
    }

    // Get back 95% of values in SLC
    function slcTokenSell(address tokenAddr, uint amount) public  returns(uint outputAmount) {
        iSlc(superLibraCoin).burnSLC(msg.sender,amount);
        if(slcUnsecuredIssuancesAmount > amount){
            slcUnsecuredIssuancesAmount -= amount;
        }else{
            slcUnsecuredIssuancesAmount = 0;
        }

        address[] memory tokens = new address[](2);
        tokens[0] = superLibraCoin;
        tokens[1] = tokenAddr;
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = outputAmount * 96 / 100 ;

        address[] memory tokensT = new address[](3);
        tokensT[0] = mainCollateralToken;
        tokensT[1] = superLibraCoin;
        tokensT[2] = tokenAddr;
        (amount,) = ixInterface(xInterface).xExchangeEstimateOutput(tokensT, outputAmount);

        IERC20(mainCollateralToken).approve(xInterface, amount);
        outputAmount = ixInterface(xInterface).xexchange(tokensT,amount,outputAmount,outputAmount / 50, block.timestamp + 100);
        IERC20(tokenAddr).safeTransfer(msg.sender,outputAmount);
        emit SlcTokenSell(msg.sender, tokenAddr, amount, outputAmount);
    
    }

    //---------------------------- borrow & lend  Function----------------------------
    // licensed Assets Pledge
    function licensedAssetsPledge(address tokenAddr, uint amount, address user) public  {
        require(licensedAssets[tokenAddr].assetAddr == tokenAddr,"SLC Vaults: Token Not registered");
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");

        if(licensedAssets[tokenAddr].maxDepositAmount == 0){ 
            require(userMode[user] == 0,"SLC Vaults: Wrong Mode, Need a  Popular Mode");
        }else{
            require((tokenAddr == userModeAssetsAddress[user]) && (userMode[user] == 1),"SLC Vaults: Wrong Mode, Need a  Non-Popular Mode");
        }
        IERC20(tokenAddr).safeTransferFrom(msg.sender,address(this),amount);
        userAssetsMortgageAmount[user][tokenAddr] += amount;
        userAssetsMortgageAmountSum[tokenAddr] += amount;
        emit LicensedAssetsPledge(msg.sender, tokenAddr, amount, user);
    }

    // redeem Pledged Assets
    function redeemPledgedAssets(address tokenAddr, uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");
        /*  // seems no need to have these code
        if(licensedAssets[TokenAddr].maxDepositAmount == 0){ 
            require(userMode[user] == 0,"SLC Vaults: Wrong Mode, Need a  Popular Mode");
        }else{
            require((TokenAddr == userModeAssetsAddress[user]) && (userMode[user] == 1),"SLC Vaults: Wrong Mode, Need a  Non-Popular Mode");
        }*/
        userAssetsMortgageAmount[user][tokenAddr] -= amount;
        userAssetsMortgageAmountSum[tokenAddr] -= amount;
        uint factor;
        IERC20(tokenAddr).safeTransfer(msg.sender,amount);
        (factor, ,,) = viewUsersHealthFactor(user);
        require( factor >= 1.2 ether,"Your Health Factor < 1.2, Cant redeem assets");
        emit RedeemPledgedAssets(msg.sender, tokenAddr, amount, user);
    
    }

    // obtain SLC coin
    function obtainSLC(uint amount, address user) public  {
        if(slcInterface[msg.sender]==false){
            require(user == msg.sender,"SLC Vaults: Not registered as slcInterface or user need be msg.sender!");
            require(latestBlockNumber < block.number,"SLC Vaults: Same block can only have ONE obtain operation ");
        }
        require(amount > 0,"SLC Vaults: Cant Pledge 0 amount");

        latestBlockNumber = block.number;
        latestBlockUser = user;
        uint factor;
        iSlc(superLibraCoin).mintSLC(msg.sender,amount);
        userObtainedSLCAmount[user] += amount;
        if(userMode[user] == 1){
            riskIsolationModeAmount[userModeAssetsAddress[user]] += amount;
            require(riskIsolationModeAmount[userModeAssetsAddress[user]] <= licensedAssets[userModeAssetsAddress[user]].maxDepositAmount,"Amount Exceed Limit");
        }
        (factor, ,,) = viewUsersHealthFactor(user);
        require(factor >= 1.2 ether,"Your Health Factor <= 1.2, Cant obtain SLC");

        iRewardMini(rewardContract).recordUpdate(user,userObtainedSLCAmount[user]);
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
        if(userMode[user] == 1){
            riskIsolationModeAmount[userModeAssetsAddress[user]] -= amount;
        }
        iSlc(superLibraCoin).burnSLC(msg.sender, amount);

        iRewardMini(rewardContract).recordUpdate(user,userObtainedSLCAmount[user]);
        emit ReturnSLC(msg.sender, amount, user);

    }
    //-----------------------------------------------------------------------------------------------------
    function usersHealthFactorEstimate(address user,address token,uint amount,bool operator) public view returns(uint userHealthFactor){
        uint tempValue;
        uint[2] memory tempLoanToValue;
        // userAssetsMortgageAmount[user][assetsSerialNumber[i]] :: userAssetsMortgageAmount[user][assetsSerialNumber[i]] * 1 ether / iDecimals(tokenAddr).decimals()
        for(uint i=0;i<assetsSerialNumber.length;i++){
            if(licensedAssets[assetsSerialNumber[i]].maxDepositAmount == 0){
                if(token == assetsSerialNumber[i]){
                    tempValue = amount;
                }else{
                    tempValue = 0;
                }
                if(operator){
                    tempLoanToValue[0] += (userAssetsMortgageAmount[user][assetsSerialNumber[i]] - tempValue) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                        * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                }else{
                    tempLoanToValue[0] += (userAssetsMortgageAmount[user][assetsSerialNumber[i]] + tempValue) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                        * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                }
            }else if(userModeAssetsAddress[user] == assetsSerialNumber[i]){
                if(token == assetsSerialNumber[i]){
                    tempValue = amount;
                }else{
                    tempValue = 0;
                }
                if(operator){
                    tempLoanToValue[1] += (userAssetsMortgageAmount[user][assetsSerialNumber[i]] - tempValue) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                        * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                }else{
                    tempLoanToValue[1] += (userAssetsMortgageAmount[user][assetsSerialNumber[i]] + tempValue) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / iDecimals(licensedAssets[assetsSerialNumber[i]].assetAddr).decimals()
                                        * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                }
            }
        }
        if(token == superLibraCoin){
            tempValue = amount;
        }else{
            tempValue = 0;
        }

        if(userObtainedSLCAmount[user] > 0 || (userObtainedSLCAmount[user]== 0 && !operator)){
            if(userMode[user] == 0){
                if(operator){
                    userHealthFactor = (tempLoanToValue[0] * 1 ether / (userObtainedSLCAmount[user] - tempValue)) * 1 ether / slcValue;
                }else{
                    userHealthFactor = (tempLoanToValue[0] * 1 ether / (userObtainedSLCAmount[user] + tempValue)) * 1 ether / slcValue;
                }
                
            }else{
                if(operator){
                    userHealthFactor = (tempLoanToValue[1] * 1 ether / (userObtainedSLCAmount[user] - tempValue)) * 1 ether / slcValue;
                }else{
                    userHealthFactor = (tempLoanToValue[1] * 1 ether / (userObtainedSLCAmount[user] + tempValue)) * 1 ether / slcValue;
                }
            }
        }else{
            userHealthFactor = 1000 ether;
        }
    }

    //-----------------------------------------------------------------------------------------------------

    // Token Rebalance 
    function rebalance(address[] memory tokens, uint amount) public onlyRebalancer() returns(uint outputAmount){
        IERC20(tokens[0]).approve(xInterface, amount);
        (outputAmount,) = ixInterface(xInterface).xExchangeEstimateInput(tokens, amount);
        outputAmount = ixInterface(xInterface).xexchange(tokens,amount,outputAmount,outputAmount / 100, block.timestamp + 100);
        emit Rebalance(tokens, amount, outputAmount);
    }
    // Assets excess Disposal
    function excessDisposal(address token, uint amount) public onlyRebalancer(){
        require(IERC20(token).balanceOf(address(this)) > amount + userAssetsMortgageAmountSum[token],"SLC Vaults: Cant Do Excess Disposal, asset not enough!");
        IERC20(token).safeTransfer(msg.sender,amount);
        licensedAssets[token].mortgagedAmountDisposed += amount;
        emit MortgagedAmountDisposed(token, amount);
    
    }
    function excessAssetsReturn(address token, uint amount) public onlyRebalancer(){
        IERC20(token).safeTransfer(msg.sender,amount);
        licensedAssets[token].mortgagedAmountReturned += amount;
        emit MortgagedAmountReturned(token, amount);
    }

    //------------------------------ Liquidate Function------------------------------
    // token Liquidate
    function tokenLiquidate(address user,address token, uint amount) public returns(uint outputAmount) {
        require(amount > 0,"SLC Vaults: Cant Liquidate 0 amount");
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

        IERC20(token).safeTransfer(msg.sender,amount/10000);
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