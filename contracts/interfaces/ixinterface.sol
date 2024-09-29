// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30

pragma solidity 0.8.6;

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

    function getUserCoinOrLpAmount(address lpOrCoin,address _user) external view returns (uint);

    function getUserLpReservesAmount(address _lp,address _user) external view returns (address[2] memory TokensAdd,uint[2] memory TokensAmount);
    

}