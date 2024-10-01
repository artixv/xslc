// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "./interfaces/ixinterface.sol";
import "./interfaces/iexchangeRoom.sol";

contract slcOracle {
    address public  slcAddress;
    uint256 public  slcValue;
    address public  pythAddr;
    address public  xInterface; 
    address public  exchangRoomAddr;
    address public  xcfxaddr;
    address public  sxcfxaddr;
    address public  wxcfxaddr;// wxcfx == cfx

    address public  usdtAddr;
    address public  usdcAddr;

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
    function cfxsetup( address _xcfxaddr,
                       address _sxcfxaddr,
                       address _exchangRoomAddr,
                       address _wxcfxaddr ) external onlySetter{
        xcfxaddr = _xcfxaddr;
        sxcfxaddr = _sxcfxaddr;
        wxcfxaddr = _wxcfxaddr;
        exchangRoomAddr = _exchangRoomAddr;
    }
    function usdsetup( address _usdtAddr,
                       address _usdcAddr) external onlySetter{
        usdcAddr = _usdcAddr;
        usdtAddr = _usdtAddr;
    }

    function TokenToPythIdSetup(address tokenAddress, bytes32 pythId) external onlySetter{
        TokenToPythId[tokenAddress] = pythId;
    }
    //-----------------------------------Special token handling----------------------------------------

    function xcfxToCFXPrice() public view returns(uint _xcfxPrice){
        (_xcfxPrice,) = iexchangeRoom(exchangRoomAddr).XCFX_burn_estim(1 ether);
    }

    //-----------------------------------------------------------------------------------
  
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
        address pair;
        try ixInterface(xInterface).getPair(token, slcAddress){
            pair = ixInterface(xInterface).getPair(token, slcAddress);
        } catch {
            // Do something in any other case
            return 0;
        }
        
        try ixInterface(xInterface).getLpPrice( pair) {
            price = ixInterface(xInterface).getLpPrice( pair)* slcValue / 1 ether;
            // Do something if the call succeeds
        } catch {
            // Do something in any other case
            return 0;
        }
    }

    function getSwappiPrice(address token) public view returns (uint price){}

    function getPrice(address token) external view returns (uint price){
        uint x ;
        if(token == slcAddress){
            return ((1 ether * 1 ether / getXUnionPrice(usdtAddr) 
                   + getPythPrice(usdtAddr) 
                   + 1 ether * 1 ether / getXUnionPrice(usdcAddr) 
                   + getPythPrice(usdcAddr)) / 4);
        }else if(token == sxcfxaddr){
            token = wxcfxaddr;
        }else if(token == xcfxaddr){
            token = wxcfxaddr;
            x=1;
        }

        price = getXUnionPrice(token);
        uint pythPrice = getPythPrice(token);
        if(pythPrice != 0 && price != 0){
            price = (getXUnionPrice(token) + pythPrice) / 2;
        }else if(pythPrice != 0){
            price = pythPrice;
        }

        if(x == 1){
            price = price * xcfxToCFXPrice() / 1 ether;
        }
    }

    //  Native token return
    function  nativeTokenReturn() external onlySetter {
        uint amount = address(this).balance;
        address payable receiver = payable(msg.sender);
        (bool success, ) = receiver.call{value:amount}("");
        require(success,"X SLC Oracle: CFX Transfer Failed");
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}
