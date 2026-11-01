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

contract YieldAutoCompounder is ReentrancyGuard, Ownable {
    struct Vault {
        address owner;
        address token;
        uint256 balance;
        uint256 compoundInterval;
        uint256 lastCompound;
        uint256 totalCompounded;
        bool active;
    }
    Vault[] public vaults;
    mapping(address => uint256[]) public userVaults;
    uint256 public vaultCount;

    event VaultCreated(uint256 indexed vid, address indexed owner, address token, uint256 interval);
    event Compounded(uint256 indexed vid, address indexed owner, uint256 amount);
    event VaultPaused(uint256 indexed vid, address indexed owner);
    event VaultResumed(uint256 indexed vid, address indexed owner);

    function createVault(address token, uint256 compoundIntervalSeconds)
        external onlyOwner nonReentrant returns (uint256) {
        require(compoundIntervalSeconds > 0, "Zero interval");
        Vault storage v = vaults.push();
        v.owner = msg.sender;
        v.token = token;
        v.balance = 0;
        v.compoundInterval = compoundIntervalSeconds;
        v.lastCompound = block.timestamp;
        v.totalCompounded = 0;
        v.active = true;
        uint256 vid = vaults.length - 1;
        vaultCount = vid + 1;
        userVaults[msg.sender].push(vid);
        emit VaultCreated(vid, msg.sender, token, compoundIntervalSeconds);
        return vid;
    }

    function deposit(uint256 vid, uint256 amount) external nonReentrant {
        Vault storage v = vaults[vid];
        require(v.active, "Vault inactive");
        require(amount > 0, "Zero deposit");
        v.balance += amount;
    }

    function compound(uint256 vid) external nonReentrant {
        Vault storage v = vaults[vid];
        require(v.active, "Vault inactive");
        require(block.timestamp >= v.lastCompound + v.compoundInterval, "Interval not elapsed");
        require(v.balance > 0, "Zero balance");
        uint256 reward = v.balance / 100; // 1% yield per compound
        require(reward > 0, "Reward too small");
        v.balance += reward;
        v.totalCompounded += reward;
        v.lastCompound = block.timestamp;
        emit Compounded(vid, v.owner, reward);
    }

    function withdraw(uint256 vid, uint256 amount) external nonReentrant {
        Vault storage v = vaults[vid];
        require(v.owner == msg.sender, "Not owner");
        require(amount > 0 && amount <= v.balance, "Invalid amount");
        v.balance -= amount;
    }

    function pauseVault(uint256 vid) external onlyOwner {
        Vault storage v = vaults[vid];
        require(v.active, "Already paused");
        v.active = false;
        emit VaultPaused(vid, v.owner);
    }

    function resumeVault(uint256 vid) external onlyOwner {
        Vault storage v = vaults[vid];
        require(!v.active, "Already active");
        v.active = true;
        emit VaultResumed(vid, v.owner);
    }

    function getVault(uint256 vid) external view returns (address owner, address token, uint256 balance, uint256 interval, uint256 lastCompound, uint256 totalCompounded, bool active) {
        Vault storage v = vaults[vid];
        return (v.owner, v.token, v.balance, v.compoundInterval, v.lastCompound, v.totalCompounded, v.active);
    }
}
