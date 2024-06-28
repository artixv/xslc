// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "./interfaces/ixinterface.sol";

contract slcOracle {
    address public  slcAddress;
    uint256 public  slcValue;
    address public  pythAddr;
    address public  xInterface; 

    address public setter;
    address newsetter;

    mapping(address => bytes32) public TokenToPythId;

    //----------------------------modifier ----------------------------
    modifier onlySetter() {
        require(msg.sender == setter, 'SLC Vaults: Only Manager Use');
        _;
    }
    //------------------------------------ ----------------------------

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
    function setup( address _slcAddress,
                    uint256 _slcValue,
                    address _xInterface,
                    address _pythAddr ) external onlySetter{
        slcAddress = _slcAddress;
        slcValue = _slcValue;
        xInterface = _xInterface;
        pythAddr = _pythAddr;
    }

    function TokenToPythIdSetup(address tokenAddress, bytes32 pythId) external onlySetter{
        TokenToPythId[tokenAddress] = pythId;
    }
  
    // function getPrice(
    //     bytes32 id
    // ) external view returns (PythStructs.Price memory price){}
    function getPythBasicPrice(bytes32 id) internal view returns (PythStructs.Price memory price){
        price = IPyth(pythAddr).getPriceUnsafe(id);
    }

    function pythPriceUpdate(bytes[] calldata updateData) public payable {
        uint fee = IPyth(pythAddr).getUpdateFee( updateData);
        IPyth(pythAddr).updatePriceFeeds{ value: fee }(updateData);
    }

    function getPythPrice(address token) public view returns (uint price){
        PythStructs.Price memory priceBasic;
        uint tempPriceExpo ;
        if(TokenToPythId[token] != bytes32(0)){
            priceBasic = getPythBasicPrice(TokenToPythId[token]);
            tempPriceExpo = uint(int256(18+priceBasic.expo));
            price = uint(int256(priceBasic.price)) * (10**tempPriceExpo);
        }else{
            price = 0;
        }
    }

    function getXUnionPrice(address token) public view returns (uint price){
        address pair = ixInterface(xInterface).getPair(token, slcAddress);
        price = ixInterface(xInterface).getLpPrice( pair)* slcValue / 1 ether;
    }

    function getSwappiPrice(address token) public view returns (uint price){}

    function getPrice(address token) external view returns (uint price){
        uint pythPrice = getPythPrice(token);
        if(token == slcAddress){
            return slcValue;
        }
        if(pythPrice != 0){
            price = (getXUnionPrice(token) + pythPrice) / 2;
        }else{
            price = getXUnionPrice(token);
        }
    }

    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}
}
