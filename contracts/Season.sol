pragma solidity >= 0.4.24;

import "./Forest.sol";
import "./Crowdshare.sol";
import "./Ownable.sol"; //might be removed if oracle

contract Season is Ownable {
    uint seedsCollected;

    Forest private _forest;
    Crowdshare private _crowdshare;

    mapping(address => uint) _treeUsed;

    uint _mediane;
    uint _seasonDays;

    constructor(Forest forest, Crowdshare crowdshare) public {
        _forest = forest;
        _crowdshare = crowdshare;
    }

    function quickSort(uint[] memory arr, uint left, uint right) internal pure {
        uint i = left;
        uint j = right;
        uint pivot = arr[left + (right - left) / 2];
        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (pivot < arr[j]) j--;
            if (i <= j) {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);

        if (i < right)
            quickSort(arr, i, right);
    }

    function calculateMediane() internal{
        uint[] memory balances;
        uint count = _crowdshare.getInvestorCount();
        address[] memory investors = _crowdshare.getInvestors();
        for(uint i = 0; i < count; i++) balances[i] = _forest.getSeeds().balanceOf(investors[i]);
        quickSort(balances, 0, balances.length - 1);
        _mediane = balances[balances.length/2];
        delete balances;
        delete investors;
        //update mediane et s2t
    }

    function calculateLeak(address user2bLeaked) internal view returns (int256) {
        uint balance = _forest.getSeeds().balanceOf(user2bLeaked);
        int256 Leak;
        if (balance <= _mediane){
            Leak = 0;
            uint treeId = _treeUsed[user2bLeaked];
            if(treeId != 0){
                Leak = -int256(_forest.getTreeSeeds(treeId));
            }
        }
        else Leak = int256(((balance - _mediane) / _seasonDays - 1) + 1);
        return Leak;
    }

    function Leak() public onlyOwner(){ //try to find way to trigger every 24h with Oracle
        int256 leak;
        int256 balance;
        uint count = _crowdshare.getInvestorCount();
        address[] memory investors = _crowdshare.getInvestors();
        for(uint i = 0; i < count; i++){
            balance = int256(_forest.getSeeds().balanceOf(investors[i]));
            leak = calculateLeak(investors[i]);
            if(leak < 0){
                if(balance - leak < int256(_mediane)) leak = balance - int256(_mediane);
                _forest.getSeeds().leakFromTrusted(investors[i],uint(leak));
            }
            else{
                if(balance - leak > int256(_mediane)) leak = int256(_mediane) - balance;
                _forest.getSeeds().transferFromTrusted(investors[i],uint(leak));
            }
        }
        _seasonDays++;
        //if _seasonDays < 7 then call Leak again in 24h else endSeason
    }

    function startSeason() public onlyOwner(){
        _forest.openTreeSeason();
        //Leak();
    }

    function endSeason() public onlyOwner(){
        _forest.closeTreeSeason();
        uint count = _crowdshare.getInvestorCount();
        address[] memory investors = _crowdshare.getInvestors();
        for(uint i = 0; i < count; i++)_forest.treeGetOlder(_treeUsed[investors[i]]);
        _seasonDays = 0;
    }

    function treeToUse(uint treeId) public returns(bool) {
        require(_forest.isOwnerOfTree(treeId), "not owner of tree");
        _treeUsed[msg.sender] = treeId;
        return true;
    }
}