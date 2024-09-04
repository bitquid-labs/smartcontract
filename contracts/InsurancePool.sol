// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CoverLib.sol";

interface ICover {
    function updateMaxAmount(uint256 _coverId) external ;
}

contract InsurancePool is ReentrancyGuard, Ownable {
    using CoverLib for *;
    error LpNotActive();

    struct Pool {
        string poolName;
        CoverLib.RiskType riskType;
        uint256 apy;
        uint256 minPeriod;
        uint256 tvl;
        uint256 tcp; // Total claim paid to users
        bool isActive; // Pool status to handle soft deletion
        uint256 percentageSplitBalance;
        mapping(address => Deposits) deposits; // Mapping of user address to their deposit
    }

    struct Deposits {
        address lp;
        uint256 amount;
        uint256 poolId;
        uint256 period;
        uint256 dailyPayout;
        Status status;
        uint256 expiryDate;
    }

    // Define PoolInfo struct
    struct PoolInfo {
        string poolName;
        uint256 apy;
        uint256 minPeriod;
        uint256 tvl;
        uint256 tcp; // Total claim paid to users
        bool isActive; // Pool status to handle soft deletion
    }

    enum Status {
        Active,
        Withdrawn
    }

    mapping (uint256 => CoverLib.Cover[]) poolToCovers;
    mapping(uint256 => Pool) public pools;
    uint256 public poolCount;
    address public governance;
    ICover public ICoverContract;
    address public coverContract;
    address public initialOwner;

    event Deposited(address indexed user, uint256 amount, string pool);
    event Withdraw(address indexed user, uint256 amount, string pool);
    event ClaimPaid(address indexed recipient, string pool, uint256 amount);
    event PoolCreated(uint256 indexed id, string poolName);
    event PoolUpdated(uint256 indexed poolId, uint256 apy, uint256 _minPeriod);
    event ClaimAttempt(uint256, uint256, address);

    constructor(address _initialOwner) Ownable(_initialOwner) {
        initialOwner = _initialOwner;
    }

    function createPool(
        CoverLib.RiskType _riskType,
        string memory _poolName,
        uint256 _apy,
        uint256 _minPeriod
    ) public onlyOwner {
        poolCount += 1;
        Pool storage newPool = pools[poolCount];
        newPool.poolName = _poolName;
        newPool.apy = _apy;
        newPool.minPeriod = _minPeriod;
        newPool.tvl = 0;
        newPool.isActive = true;
        newPool.riskType = _riskType;
        newPool.percentageSplitBalance = 100;

        emit PoolCreated(poolCount, _poolName);
    }

    function updatePool(
        uint256 _poolId,
        uint256 _apy,
        uint256 _minPeriod
    ) public onlyOwner {
        require(pools[_poolId].isActive, "Pool does not exist or is inactive");
        require(_apy > 0, "Invalid APY");
        require(_minPeriod > 0, "Invalid minimum period");

        pools[_poolId].apy = _apy;
        pools[_poolId].minPeriod = _minPeriod;

        emit PoolUpdated(_poolId, _apy, _minPeriod);
    }

    function updatePercentageSplit(uint256 _poolId,uint256 __poolPercentageSplit) public onlyCover {
        pools[_poolId].percentageSplitBalance -= __poolPercentageSplit;
    }

    function deactivatePool(uint256 _poolId) public onlyOwner {
        if (!pools[_poolId].isActive) {
            revert LpNotActive();
        }
        pools[_poolId].isActive = false;
    }

    function getPool(
        uint256 _poolId
    )
        public
        view
        returns (
            string memory name,
            CoverLib.RiskType riskType,
            uint256 apy,
            uint256 minPeriod,
            uint256 tvl,
            bool isActive,
            uint256 percentageSplitBalance
        )
    {
        Pool storage pool = pools[_poolId];
        return (
            pool.poolName,
            pool.riskType,
            pool.apy,
            pool.minPeriod,
            pool.tvl,
            pool.isActive,
            pool.percentageSplitBalance
        );
    }

    // Function to get all pools
    function getAllPools() public view returns (PoolInfo[] memory) {
        PoolInfo[] memory result = new PoolInfo[](poolCount);

        for (uint256 i = 1; i <= poolCount; i++) {
            Pool storage pool = pools[i];
            result[i - 1] = PoolInfo({
                poolName: pool.poolName,
                apy: pool.apy,
                minPeriod: pool.minPeriod,
                tvl: pool.tvl,
                tcp: pool.tcp,
                isActive: pool.isActive
            });
        }
        return result;
    }

    function updatePoolCovers(uint256 _poolId, CoverLib.Cover memory _cover) public onlyCover {
        poolToCovers[_poolId].push(_cover);
    }

    function getPoolCovers(uint256 _poolId) public view returns (CoverLib.Cover[] memory) {
        return poolToCovers[_poolId];
    }

    function getPoolsByAddress(address _userAddress)
        public
        view
        returns (PoolInfo[] memory)
    {
        uint256 resultCount = 0;
        for (uint256 i = 1; i <= poolCount; i++) {
            Pool storage pool = pools[i];
            if (pool.deposits[_userAddress].amount > 0) {
                resultCount++;
            }
        }

        PoolInfo[] memory result = new PoolInfo[](resultCount);

        uint256 resultIndex = 0;

        for (uint256 i = 1; i <= poolCount; i++) {
            Pool storage pool = pools[i];
            if (pool.deposits[_userAddress].amount > 0) {
                result[resultIndex++] = PoolInfo({
                    poolName: pool.poolName,
                    apy: pool.apy,
                    minPeriod: pool.minPeriod,
                    tvl: pool.tvl,
                    tcp: pool.tcp,
                    isActive: pool.isActive
                });
            }
        }
        return result;
    }

    function withdraw(uint256 _poolId) public nonReentrant {
        Pool storage selectedPool = pools[_poolId];
        Deposits storage userDeposit = selectedPool.deposits[msg.sender];

        require(userDeposit.amount > 0, "No deposit found for this address");
        require(userDeposit.status == Status.Active, "Deposit is not active");
        require(
            block.timestamp >= userDeposit.expiryDate,
            "Deposit period has not ended"
        );

        userDeposit.status = Status.Withdrawn;
        selectedPool.tvl -= userDeposit.amount;
        CoverLib.Cover[] memory poolCovers = getPoolCovers(_poolId);
        for (uint i = 0; i < poolCovers.length; i++) {
            ICoverContract.updateMaxAmount(poolCovers[i].id);
        }

        (bool success, ) = msg.sender.call{value: userDeposit.amount}("");
        require(success, "Withdrawal failed");

        emit Withdraw(msg.sender, userDeposit.amount, selectedPool.poolName);
    }

    function deposit(
        uint256 _poolId,
        uint256 _period
    ) public payable nonReentrant {
        Pool storage selectedPool = pools[_poolId];

        require(msg.value > 0, "Amount must be greater than 0");
        require(selectedPool.isActive, "Pool is inactive or does not exist");
        require(
            _period >= selectedPool.minPeriod,
            "Deposit period is less than the minimum required"
        );

        if (selectedPool.deposits[msg.sender].amount > 0) {
            uint256 amount = selectedPool.deposits[msg.sender].amount + msg.value;
            selectedPool.deposits[msg.sender].amount = amount;
            selectedPool.deposits[msg.sender].period = _period;
            selectedPool.deposits[msg.sender].expiryDate = block.timestamp + (_period * 1 days);
            selectedPool.deposits[msg.sender].dailyPayout = (amount * selectedPool.apy) / 100 / 365;
        } else {
            uint256 dailyPayout = (msg.value * selectedPool.apy) / 100 / 365;
            selectedPool.deposits[msg.sender] = Deposits({
                lp: msg.sender,
                amount: msg.value,
                poolId: _poolId,
                period: _period,
                dailyPayout: dailyPayout,
                status: Status.Active,
                expiryDate: block.timestamp + (_period * 1 days)
            });
        }

        selectedPool.tvl += msg.value;
        CoverLib.Cover[] memory poolCovers = getPoolCovers(_poolId);
        for (uint i = 0; i < poolCovers.length; i++) {
            ICoverContract.updateMaxAmount(poolCovers[i].id);
        }

        emit Deposited(msg.sender, msg.value, selectedPool.poolName);
    }

    function payClaim(
        uint256 poolId,
        uint256 claimAmount,
        address payable recipient
    ) public onlyGovernance nonReentrant {
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool is not active");
        require(pool.tvl >= claimAmount, "Not enough funds in the pool");

        emit ClaimAttempt(poolId, claimAmount, recipient); // Add this line to debug

        recipient.transfer(claimAmount);

        pool.tcp += claimAmount;
        pool.tvl -= claimAmount;
        CoverLib.Cover[] memory poolCovers = getPoolCovers(poolId);
        for (uint i = 0; i < poolCovers.length; i++) {
            ICoverContract.updateMaxAmount(poolCovers[i].id);
        }

        emit ClaimPaid(msg.sender, pool.poolName, claimAmount);
    }

    function getUserDeposit(
        uint256 _poolId,
        address _user
    ) public view returns (Deposits memory) {
        return pools[_poolId].deposits[_user];
    }

    function getPoolTVL(uint256 _poolId) public view returns (uint256) {
        return pools[_poolId].tvl;
    }

    function poolActive(uint256 poolId) public view returns (bool) {
        Pool storage pool = pools[poolId];
        return pool.isActive;
    }

    function setGovernance(address _governance) external onlyOwner {
        require(governance == address(0), "Governance already set");
        require(_governance != address(0), "Governance address cannot be zero");
        governance = _governance;
    }

    function setCover(address _coverContract) external onlyOwner {
        require(coverContract == address(0), "Governance already set");
        require(_coverContract != address(0), "Governance address cannot be zero");
        ICoverContract = ICover(_coverContract);
        coverContract = _coverContract;
    }

    modifier onlyGovernance() {
        require(
            msg.sender == governance || msg.sender == initialOwner,
            "Caller is not the governance contract"
        );
        _;
    }

    modifier onlyCover() {
        require(
            msg.sender == coverContract || msg.sender == initialOwner,
            "Caller is not the governance contract"
        );
        _;
    }
}
