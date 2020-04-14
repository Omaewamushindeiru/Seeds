pragma solidity >= 0.4.24;

import "./ERC20.sol";
import "./ReentrancyGuard.sol";

contract Crowdshare is ReentrancyGuard {

    using SafeMath for uint256;

    event WhitelistedAdded(address indexed account);
    event WhitelistedRemoved(address indexed account);
    event AirdropSuccessful(uint value);
    event CocktailUpdated(uint value);

    mapping (address => bool) private _whitelist;

    address[] private investors;
    uint private investorsCount;

    ERC20 private _token;
    uint _cocktailDeBienvenue;



    address private _owner;

    constructor (uint rate, ERC20 token, uint cdbv) public {
        require(rate > 0, "rate is negative");
        require(address(token) != address(0), "address 0x0");

        _owner = msg.sender;
        _token = token;
        _cocktailDeBienvenue = cdbv;
        addToWhitelist(_owner);
    }

    function token() public view returns (ERC20) {
        return _token;
    }

    function owner() public view returns (address) {
        return _owner;
    }




    modifier onlyOwner() {
        require(msg.sender == _owner, "Owner 0x0");
        _;
    }

    modifier isWhitelisted(address _address) {
        require(_whitelist[_address], "not in whitelist");
        _;
    }

    modifier isNotZeroAccount(address _address) {
        require(_address != address(0), "address 0x0");
        _;
    }






    function updateCdbv(uint cdbv) public onlyOwner() {
        _cocktailDeBienvenue = cdbv;
        emit CocktailUpdated(_cocktailDeBienvenue);
    }

    function addToWhitelist(address _address) public onlyOwner() isNotZeroAccount(_address) {
        require(!_whitelist[_address], "aldready in whitelist");
        _whitelist[_address] = true;
        investors.push(_address);
        investorsCount++;
        _token.transferFrom(_owner, _address, _cocktailDeBienvenue);
        emit WhitelistedAdded(_address);
    }
    
    function isInWhitelist(address _address) public view returns (bool) {
        return _whitelist[_address];
    }

    function removeFromWhitelist(address _address) public onlyOwner() isNotZeroAccount(_address) {
        require(_whitelist[_address], "not in whitelist");
        require(_token.balanceOf(_address) == 0, "still owns seeds");
        _whitelist[_address] = false;

        uint8 i;
        for(i = 0; i < investors.length; i++) if(_address == investors[i]) break;

        investors[i] = investors[investorsCount - 1];
        delete investors[investorsCount - 1];
        investorsCount --;

        emit WhitelistedRemoved(_address);
    }





    function airdrop(uint _value) public onlyOwner() {
        require(_token.balanceOf(_owner) >= _value * investorsCount, "airdrop fail, balance insufficient");
        for (uint8 i = 0; i < investorsCount; i++) {
            _token.transferFromTrusted(investors[i], _value);
        }
        emit AirdropSuccessful(_value);
    }

    function getInvestorCount() public view returns(uint) {
        return investorsCount;
    }

    function getInvestors() public view returns(address[] memory) {
        return investors;
    }

}