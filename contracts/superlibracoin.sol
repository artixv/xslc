// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract superLibraCoin is ERC20 {
    address public slcManager;
    address public setter;
    address newsetter;

    constructor(address _slcManager) ERC20("Super Libra Coin", "SLC") {
        setter = msg.sender;
        slcManager = _slcManager;
    }
    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Super Libra Coin: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyManager() {
        require(msg.sender == slcManager, 'Super Libra Coin: Only Manager Use');
        _;
    }
    modifier onlyLpSetter() {
        require(msg.sender == setter, 'Super Libra Coin: Only setter Use');
        _;
    }
    
    //----------------------------- event -----------------------------
    event Mint(address indexed mintAddress, uint amount);
    event Burn(address indexed burnAddress, uint amount);
    //-------------------------- sys function --------------------------

    function resetup(address _slcManager) external onlyLpSetter{
        slcManager = _slcManager;
    }
    function transferLpSetter(address _set) external onlyLpSetter{
        newsetter = _set;
    }
    function acceptLpSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'Super Libra Coin: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    //----------------------------- function -----------------------------

    /**
     * @dev mint
     */
    function mintSLC(address _account,uint256 _value) public onlyManager lock{
        // uint addTokens;
        require(_value > 0,"Super Libra Coin:Input value MUST > 0");
        // require(_value == msg.value,"X SWAP Pair:Input value MUST same as msg.value");
        _mint(_account, _value);
        emit Mint(_account, _value);
    }
    /**
     * @dev burn
     */
    function burnSLC(address _account,uint256 _value) public onlyManager lock{
        // uint burnTokens;
        require(_value > 0,"Super Libra Coin:Con't burn 0");
        require(_value <= balanceOf(_account),"Super Libra Coin:Must <= account balance");
        _burn(_account, _value);
        emit Burn(_account, _value);
    }

}
