pragma solidity >=0.4.24;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC721.sol";
import "./ERC20.sol";

contract Forest is Ownable {
    using SafeMath for uint256;

    event TreePlanted(address indexed owner, uint tokenId);
    event TreeDeleted(address indexed owner, uint tokenId);
    event MedianeUpdated(uint mediane);
    event SeedsToTreeUpdated(uint seeds);
    event TrustedAddressUpdated(address trusted);
    event SeasonOpened();
    event SeasonClosed();


    mapping (uint => address) private _treeToOwner;
    mapping (address => Tree[]) private _treesOfOwner;
    mapping (uint => Tree) private _treesById;

    uint private _currentId;
    uint private nonce;

    ERC721 private _erc721;
    ERC20 private _erc20;

    address private _trustedAddress;

    uint private _seedsToTree;
    uint private _seedsMediane;

    bool private _canPlant;

    struct Tree {
        uint id;

        uint seedsProduced;
        uint age;
    }


    constructor(ERC721 erc721, ERC20 erc20, uint seedsToTree, uint seedsMediane) public {
        _erc721 = erc721;
        _erc20 = erc20;
        _seedsToTree = seedsToTree;
        _seedsMediane = seedsMediane;
        _canPlant = false;
    }

    modifier onlyOwnerOftree(uint id) {
        require(msg.sender == _treeToOwner[id], "Not tree owner");
        _;
    }

    modifier onlyTrusted() {
        require(msg.sender == _trustedAddress, "Not trusted");
        _;
    }




    function updateTrustedAddress(address trusted) public onlyOwner() {
        _trustedAddress = trusted;
        emit TrustedAddressUpdated(_trustedAddress);
    }


    function updateS2T(uint seedsToTree) public onlyTrusted(){
        _seedsToTree = seedsToTree;
        emit SeedsToTreeUpdated(_seedsToTree);
    }

    function updateMediane(uint seedsMediane) public onlyTrusted(){
        _seedsMediane = seedsMediane;
        emit SeedsToTreeUpdated(_seedsToTree);
    }

    function openTreeSeason() public onlyTrusted(){
        require(!_canPlant, "season already opened");
        _canPlant = true;
        emit SeasonOpened();
    }

    function closeTreeSeason() public onlyTrusted(){
        require(_canPlant, "season already closed");
        _canPlant = false;
        emit SeasonClosed();
    }




    function getOwnerOftree(uint id) public view returns (address) {
        require(_treeToOwner[id] != address(0), "not tree");
        return _treeToOwner[id];
    }

    function getSeeds() public view returns (ERC20){
        return _erc20;
    }

    function getTreeSeeds(uint id) public view returns (uint) {
        return _treesById[id].seedsProduced;
    }

    function treeGetOlder(uint id) public returns (uint) {
        _treesById[id].age++;
        if(_treesById[id].age > 3) deadtree(id);
    }

    function isOwnerOfTree(uint id) public view returns (bool){
        return msg.sender == _treeToOwner[id];
    }
    







    function PRNG() public returns(uint) {
        nonce++;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function plantTree(address to) public returns (bool) {

        require(_erc20.balanceOf(msg.sender) >= _seedsToTree + _seedsMediane, "not enough seeds owned");
        require(_canPlant, "season must be opened to plant");

        _erc20.transferFrom(msg.sender, _erc20.owner(), _seedsToTree);

        _currentId++;

        uint rnd = PRNG();
        uint production = _seedsMediane/7;
        if(production == 0) production++;

        Tree memory tree = Tree(_currentId, production + rnd%production, 0);

        _treesOfOwner[msg.sender].push(tree);
        _treesById[_currentId] = tree;
        _treeToOwner[_currentId] = to;

        _erc721.mintToken(to, _currentId);

        emit TreePlanted(msg.sender, tree.id);

        return true;
    }





    function _removeFromArray(address owner, uint id) private {
        uint size = _treesOfOwner[owner].length;
        for (uint index = 0; index < size; index++) {
            if (_treesOfOwner[owner][index].id == id) {
                if (index < size - 1) {
                    _treesOfOwner[owner][index] = _treesOfOwner[owner][size - 1];
                }
                delete _treesOfOwner[owner][size - 1];
            }
        }
    }

    function deadtree(uint id) public onlyOwnerOftree(id) {
        _erc721.burnToken(msg.sender, id);
        _removeFromArray(msg.sender, id);
        delete _treesById[id];
        delete _treeToOwner[id];
        emit TreeDeleted(msg.sender, id);
    }
          
}