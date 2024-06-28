// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
interface ixInterface{
    // factory
    function createPair(address tokenA,address tokenB) external returns (address) ;
    // lp manager
    function xLpSubscribe(address _lp,uint[2] memory _amountEstimated) external returns(uint[2] memory _amountActual,uint _amountLp) ;
    function xLpRedeem(address _lp,uint _amountLp) external returns(uint[2] memory _amount) ;
    // vaults
    function xexchange(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) external returns(uint output) ;
    // vaults :: for exchange estimate
    function xExchangeEstimateInput(address[] memory tokens,uint amountIn) external  view returns(uint output, uint[3] memory priceImpactAndFees) ;
    function xExchangeEstimateOutput(address[] memory tokens,uint amountOut) external view returns(uint input, uint[3] memory priceImpactAndFees) ;
    // lp vaults
    function initialLpRedeem(address _lp) external returns(uint _amount) ;

    // Query function
    // Overall parameter query
    // Including 8 aspects:
    // 1 查询目前有多少币对；
    // 2 查询两个币种对应的币对是否存在，存在的话地址是多少；
    // 3 查询某个地址的币对是哪两个币种
    // 4 查询某个币种是否创建了稳定币币对
    // 5 查询某个币种的创建者是哪个地址
    // 6 查询某个币种初始创建的lp数量
    // 7 获取某一币对的详情
    // 8 获取某一币对现在的参数设置
    // 9 获取某一币对目前给定数量获得的兑换数量
    // factory
    function getPair(address tokenA, address tokenB) external view returns (address pair) ;
    function getCoinToStableLpPair(address tokenA) external view returns (address pair) ;
    function allPairs(uint _num) external view returns (address pair) ;
    function allPairsLength() external view returns (uint) ;
    // vaults
    function getLpPrice(address _lp) external view returns (uint ) ;
    function getLpReserve(address _lp) external view returns (uint[2] memory ,uint[2] memory, uint) ;
    function getLpPair(address _lp) external view returns (address[2] memory) ;
    function getLpSettings(address _lp) external view returns(uint32 balanceFee, uint a0) ;

    // lpvaults 
    function getInitialLpOwner(address lp) external view returns (address) ;
    function getInitLpAmount(address lp) external view returns (uint) ;

    // ERC20
    function getCoinOrLpTotalAmount(address lpOrCoin) external view returns (uint);


    // Personal parameter query
    // 1 查询用户持有某一币种或某一lp的数量 
    // 2 查询用户持有某lp相应两种reserve的数量

    function getUserCoinOrLpAmount(address lpOrCoin,address _user) external view returns (uint);

    function getUserLpReservesAmount(address _lp,address _user) external view returns (address[2] memory TokensAdd,uint[2] memory TokensAmount);
    

}