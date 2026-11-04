// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    bool private _nonReentrant;
    constructor() { _nonReentrant = false; }
    modifier nonReentrant() {
        require(!_nonReentrant, "ReentrancyGuard: reentrant call");
        _nonReentrant = true;
        _;
        _nonReentrant = false;
    }
}
abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _owner = msg.sender; emit OwnershipTransferred(address(0), _owner); }
    modifier onlyOwner() { require(_owner == msg.sender, "Ownable: caller is not the owner"); _; }
    function owner() public view returns (address) { return _owner; }
}


interface IVaultToken { function balanceOf(address) external view returns(uint256); function decimals() external view returns(uint8); }
contract YieldAutoCompounder is ReentrancyGuard, Ownable {
    struct Vault { address owner; address token; uint256 balance; uint256 compoundInterval; uint256 lastCompound; uint256 totalCompounded; bool active; }
    Vault[] public vaults;
    mapping(address=>uint256[]) public userVaults;
    mapping(uint256=>mapping(address=>uint256)) public sharesOf;
    mapping(uint256=>uint256) public totalShares;
    mapping(uint256=>uint256) public rewardReserve;
    uint256 public vaultCount;
    event VaultCreated(uint256 indexed vid,address indexed owner,address token,uint256 interval);
    event Compounded(uint256 indexed vid,address indexed owner,uint256 amount);
    event Deposited(uint256 indexed vid,address indexed user,uint256 amount,uint256 shares);
    event Withdrawn(uint256 indexed vid,address indexed user,uint256 amount,uint256 shares);
    event RewardsFunded(uint256 indexed vid,uint256 amount);
    event VaultPaused(uint256 indexed vid,address indexed owner);
    event VaultResumed(uint256 indexed vid,address indexed owner);
    function _token(address token,bytes memory data) private { (bool ok,bytes memory out)=token.call(data);require(ok&&(out.length==0||abi.decode(out,(bool))),"Token transfer failed"); }
    function _pull(address token,uint256 amount) private { uint256 beforeBalance=IVaultToken(token).balanceOf(address(this));_token(token,abi.encodeWithSignature("transferFrom(address,address,uint256)",msg.sender,address(this),amount));require(IVaultToken(token).balanceOf(address(this))==beforeBalance+amount,"Unsupported transfer-fee token"); }
    function createVault(address token,uint256 compoundIntervalSeconds) external onlyOwner nonReentrant returns(uint256 vid) {
        require(token.code.length>0&&compoundIntervalSeconds>0,"Invalid vault");require(IVaultToken(token).decimals()==18,"Only 18-decimal assets supported");vid=vaults.length;vaults.push(Vault(msg.sender,token,0,compoundIntervalSeconds,block.timestamp,0,true));vaultCount++;userVaults[msg.sender].push(vid);emit VaultCreated(vid,msg.sender,token,compoundIntervalSeconds);
    }
    function deposit(uint256 vid,uint256 amount) external nonReentrant {
        Vault storage v=vaults[vid];require(v.active&&amount>0,"Invalid deposit");uint256 shares=totalShares[vid]==0?amount:amount*totalShares[vid]/v.balance;require(shares>0,"Deposit too small");_pull(v.token,amount);v.balance+=amount;totalShares[vid]+=shares;sharesOf[vid][msg.sender]+=shares;emit Deposited(vid,msg.sender,amount,shares);
    }
    function fundRewards(uint256 vid,uint256 amount) external onlyOwner nonReentrant { require(amount>0,"Zero rewards");_pull(vaults[vid].token,amount);rewardReserve[vid]+=amount;emit RewardsFunded(vid,amount); }
    function compound(uint256 vid) external nonReentrant {
        Vault storage v=vaults[vid];require(v.active&&totalShares[vid]>0,"Inactive vault");require(block.timestamp>=v.lastCompound+v.compoundInterval,"Interval not elapsed");uint256 reward=v.balance/100;if(reward>rewardReserve[vid])reward=rewardReserve[vid];require(reward>0,"No funded rewards");rewardReserve[vid]-=reward;v.balance+=reward;v.totalCompounded+=reward;v.lastCompound=block.timestamp;emit Compounded(vid,v.owner,reward);
    }
    function withdraw(uint256 vid,uint256 amount) external nonReentrant {
        Vault storage v=vaults[vid];require(amount>0&&amount<=v.balance,"Invalid amount");uint256 shares=(amount*totalShares[vid]+v.balance-1)/v.balance;require(sharesOf[vid][msg.sender]>=shares,"Insufficient shares");require(shares<totalShares[vid]||amount==v.balance,"Redeem final shares in full");sharesOf[vid][msg.sender]-=shares;totalShares[vid]-=shares;v.balance-=amount;_token(v.token,abi.encodeWithSignature("transfer(address,uint256)",msg.sender,amount));emit Withdrawn(vid,msg.sender,amount,shares);
    }
    function redeem(uint256 vid,uint256 shares) external nonReentrant {
        Vault storage v=vaults[vid];require(shares>0&&sharesOf[vid][msg.sender]>=shares,"Insufficient shares");uint256 amount=shares*v.balance/totalShares[vid];require(amount>0,"Zero redemption");sharesOf[vid][msg.sender]-=shares;totalShares[vid]-=shares;v.balance-=amount;_token(v.token,abi.encodeWithSignature("transfer(address,uint256)",msg.sender,amount));emit Withdrawn(vid,msg.sender,amount,shares);
    }
    function withdrawUnusedRewards(uint256 vid) external onlyOwner nonReentrant { require(totalShares[vid]==0,"Depositors remain");uint256 amount=rewardReserve[vid];rewardReserve[vid]=0;_token(vaults[vid].token,abi.encodeWithSignature("transfer(address,uint256)",owner(),amount)); }
    function pauseVault(uint256 vid) external onlyOwner { require(vaults[vid].active,"Already paused");vaults[vid].active=false;emit VaultPaused(vid,msg.sender); }
    function resumeVault(uint256 vid) external onlyOwner { require(!vaults[vid].active,"Already active");vaults[vid].active=true;emit VaultResumed(vid,msg.sender); }
    function getVault(uint256 vid) external view returns(address owner,address token,uint256 balance,uint256 interval,uint256 lastCompound,uint256 totalCompounded,bool active) { Vault storage v=vaults[vid];return(v.owner,v.token,v.balance,v.compoundInterval,v.lastCompound,v.totalCompounded,v.active); }
}

