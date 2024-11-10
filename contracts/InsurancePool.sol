// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CoverLib.sol";

interface ICover {
    function updateMaxAmount(uint256 _coverId) external;
    function getDepositClaimableDays(
        address user,
        uint256 _poolId
    ) external view returns (uint256);
    function getLastClaimTime(
        address user,
        uint256 _poolId
    ) external view returns (uint256);
}

interface IbqBTC {
    function bqMint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IGov {
    struct ProposalParams {
        address user;
        CoverLib.RiskType riskType;
        uint256 coverId;
        string txHash;
        string description;
        uint256 poolId;
        uint256 claimAmount;
    }

    struct Proposal {
        uint256 id;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 deadline;
        uint256 timeleft;
        ProposalStaus status;
        bool executed;
        ProposalParams proposalParam;
    }

    enum ProposalStaus {
        Submitted,
        Pending,
        Approved,
        Claimed,
        Rejected
    }

    function getProposalDetails(
        uint256 _proposalId
    ) external returns (Proposal memory);
    function updateProposalStatusToClaimed(uint256 proposalId) external;
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

    struct NPool {
        uint256 poolId;
        string poolName;
        CoverLib.RiskType riskType;
        uint256 apy;
        uint256 minPeriod;
        uint256 tvl;
        uint256 tcp; // Total claim paid to users
        bool isActive; // Pool status to handle soft deletion
        uint256 percentageSplitBalance;
    }

    struct Deposits {
        address lp;
        uint256 amount;
        uint256 poolId;
        uint256 dailyPayout;
        Status status;
        uint256 daysLeft;
        uint256 startDate;
        uint256 expiryDate;
        uint256 accruedPayout;
    }

    struct PoolInfo {
        string poolName;
        uint256 poolId;
        uint256 dailyPayout;
        uint256 depositAmount;
        uint256 apy;
        uint256 minPeriod;
        uint256 tvl;
        uint256 tcp; // Total claim paid to users
        bool isActive; // Pool status to handle soft deletion
        uint256 accruedPayout;
    }

    enum Status {
        Active,
        Withdrawn
    }

    mapping(uint256 => CoverLib.Cover[]) poolToCovers;
    mapping(uint256 => Pool) public pools;
    uint256 public poolCount;
    address public governance;
    ICover public ICoverContract;
    IGov public IGovernanceContract;
    IbqBTC public bqBTC;
    address public bqBTCAddress;
    address public coverContract;
    address public initialOwner;
    address[] public participants;
    mapping(address => uint256) public participation;

    event Deposited(address indexed user, uint256 amount, string pool);
    event Withdraw(address indexed user, uint256 amount, string pool);
    event ClaimPaid(address indexed recipient, string pool, uint256 amount);
    event PoolCreated(uint256 indexed id, string poolName);
    event PoolUpdated(uint256 indexed poolId, uint256 apy, uint256 _minPeriod);
    event ClaimAttempt(uint256, uint256, address);

    constructor(address _initialOwner, address _bqBTC) Ownable(_initialOwner) {
        initialOwner = _initialOwner;
        bqBTC = IbqBTC(_bqBTC);
        bqBTCAddress = _bqBTC;
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

    function reducePercentageSplit(
        uint256 _poolId,
        uint256 __poolPercentageSplit
    ) public onlyCover {
        pools[_poolId].percentageSplitBalance -= __poolPercentageSplit;
    }

    function increasePercentageSplit(
        uint256 _poolId,
        uint256 __poolPercentageSplit
    ) public onlyCover {
        pools[_poolId].percentageSplitBalance += __poolPercentageSplit;
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

    function getAllPools() public view returns (NPool[] memory) {
        NPool[] memory result = new NPool[](poolCount);
        for (uint256 i = 1; i <= poolCount; i++) {
            Pool storage pool = pools[i];
            result[i - 1] = NPool({
                poolId: i,
                poolName: pool.poolName,
                riskType: pool.riskType,
                apy: pool.apy,
                minPeriod: pool.minPeriod,
                tvl: pool.tvl,
                tcp: pool.tcp,
                isActive: pool.isActive,
                percentageSplitBalance: pool.percentageSplitBalance
            });
        }
        return result;
    }

    function updatePoolCovers(
        uint256 _poolId,
        CoverLib.Cover memory _cover
    ) public onlyCover {
        for (uint i = 0; i < poolToCovers[_poolId].length; i++) {
            if (poolToCovers[_poolId][i].id == _cover.id) {
                poolToCovers[_poolId][i] = _cover;
                break;
            }
        }
    }

    function addPoolCover(
        uint256 _poolId,
        CoverLib.Cover memory _cover
    ) public onlyCover {
        poolToCovers[_poolId].push(_cover);
    }

    function getPoolCovers(
        uint256 _poolId
    ) public view returns (CoverLib.Cover[] memory) {
        return poolToCovers[_poolId];
    }

    function getPoolsByAddress(
        address _userAddress
    ) public view returns (PoolInfo[] memory) {
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
            Deposits memory userDeposit = pools[i].deposits[_userAddress];
            uint256 claimableDays = ICoverContract.getDepositClaimableDays(
                _userAddress,
                i
            );
            uint256 accruedPayout = userDeposit.dailyPayout * claimableDays;
            if (pool.deposits[_userAddress].amount > 0) {
                result[resultIndex++] = PoolInfo({
                    poolName: pool.poolName,
                    poolId: i,
                    dailyPayout: pool.deposits[_userAddress].dailyPayout,
                    depositAmount: pool.deposits[_userAddress].amount,
                    apy: pool.apy,
                    minPeriod: pool.minPeriod,
                    tvl: pool.tvl,
                    tcp: pool.tcp,
                    isActive: pool.isActive,
                    accruedPayout: accruedPayout
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

        bqBTC.bqMint(msg.sender, userDeposit.amount);

        emit Withdraw(msg.sender, userDeposit.amount, selectedPool.poolName);
    }

    function deposit(uint256 _poolId, uint256 _amount) public nonReentrant {
        Pool storage selectedPool = pools[_poolId];

        require(_amount > 0, "Amount must be greater than 0");
        require(selectedPool.isActive, "Pool is inactive or does not exist");

        bqBTC.burn(msg.sender, _amount);
        selectedPool.tvl += _amount;

        if (selectedPool.deposits[msg.sender].amount > 0) {
            uint256 amount = selectedPool.deposits[msg.sender].amount + _amount;
            selectedPool.deposits[msg.sender].amount = amount;
            selectedPool.deposits[msg.sender].expiryDate =
                block.timestamp +
                (selectedPool.minPeriod * 1 days);
            selectedPool.deposits[msg.sender].startDate = block.timestamp;
            selectedPool.deposits[msg.sender].dailyPayout =
                (amount * selectedPool.apy) /
                100 /
                365;
            selectedPool.deposits[msg.sender].daysLeft = (selectedPool
                .minPeriod * 1 days);
        } else {
            uint256 dailyPayout = (_amount * selectedPool.apy) / 100 / 365;
            selectedPool.deposits[msg.sender] = Deposits({
                lp: msg.sender,
                amount: _amount,
                poolId: _poolId,
                dailyPayout: dailyPayout,
                status: Status.Active,
                daysLeft: selectedPool.minPeriod,
                startDate: block.timestamp,
                expiryDate: block.timestamp +
                    (selectedPool.minPeriod * 1 minutes),
                accruedPayout: 0
            });
        }

        CoverLib.Cover[] memory poolCovers = getPoolCovers(_poolId);
        for (uint i = 0; i < poolCovers.length; i++) {
            ICoverContract.updateMaxAmount(poolCovers[i].id);
        }

        bool userExists = false;
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i] == msg.sender) {
                userExists = true;
                break;
            }
        }

        if (!userExists) {
            participants.push(msg.sender);
        }

        participation[msg.sender] += 1;

        emit Deposited(msg.sender, _amount, selectedPool.poolName);
    }

    function claimProposalFunds(uint256 _proposalId) public nonReentrant {
        IGov.Proposal memory proposal = IGovernanceContract.getProposalDetails(
            _proposalId
        );
        IGov.ProposalParams memory proposalParam = proposal.proposalParam;
        require(
            proposal.status == IGov.ProposalStaus.Approved && proposal.executed,
            "Proposal not approved"
        );
        Pool storage pool = pools[proposalParam.poolId];
        require(msg.sender == proposalParam.user, "Not a valid proposal");
        require(pool.isActive, "Pool is not active");
        require(
            pool.tvl >= proposalParam.claimAmount,
            "Not enough funds in the pool"
        );

        pool.tcp += proposalParam.claimAmount;
        pool.tvl -= proposalParam.claimAmount;
        CoverLib.Cover[] memory poolCovers = getPoolCovers(
            proposalParam.poolId
        );
        for (uint i = 0; i < poolCovers.length; i++) {
            ICoverContract.updateMaxAmount(poolCovers[i].id);
        }

        IGovernanceContract.updateProposalStatusToClaimed(_proposalId);

        emit ClaimAttempt(
            proposalParam.poolId,
            proposalParam.claimAmount,
            proposalParam.user
        );

        bqBTC.bqMint(msg.sender, proposalParam.claimAmount);

        emit ClaimPaid(msg.sender, pool.poolName, proposalParam.claimAmount);
    }

    function getUDep(
        uint256 _poolId,
        address _user
    ) public view returns (Deposits memory) {
        return pools[_poolId].deposits[_user];
    }

    function externalFunctions(
        uint256 _poolId,
        address _user
    ) public view returns (uint256, uint256) {
        uint256 claimTime = ICoverContract.getLastClaimTime(_user, _poolId);
        uint256 claimableDays = ICoverContract.getDepositClaimableDays(
            _user,
            _poolId
        );

        return (claimTime, claimableDays);
    }

    function getUserDeposit(
        uint256 _poolId,
        address _user
    ) public view returns (Deposits memory) {
        Deposits memory userDeposit = pools[_poolId].deposits[_user];
        uint256 claimTime = ICoverContract.getLastClaimTime(_user, _poolId);
        uint lastClaimTime;
        if (claimTime == 0) {
            lastClaimTime = userDeposit.startDate;
        } else {
            lastClaimTime = claimTime;
        }
        uint256 currentTime = block.timestamp;
        if (currentTime > userDeposit.expiryDate) {
            currentTime = userDeposit.expiryDate;
        }
        uint256 claimableDays = (currentTime - lastClaimTime) / 5 minutes;
        userDeposit.accruedPayout = userDeposit.dailyPayout * claimableDays;
        if (userDeposit.expiryDate <= block.timestamp) {
            userDeposit.daysLeft = 0;
        } else {
            uint256 timeLeft = userDeposit.expiryDate - block.timestamp;
            userDeposit.daysLeft = (timeLeft + 1 days - 1) / 1 days; // Round up
        }
        return userDeposit;
    }

    function getPoolTVL(uint256 _poolId) public view returns (uint256) {
        return pools[_poolId].tvl;
    }

    function poolActive(uint256 poolId) public view returns (bool) {
        Pool storage pool = pools[poolId];
        return pool.isActive;
    }

    function getAllParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getUserParticipation(address user) public view returns (uint256) {
        return participation[user];
    }

    function setGovernance(address _governance) external onlyOwner {
        require(governance == address(0), "Governance already set");
        require(_governance != address(0), "Governance address cannot be zero");
        governance = _governance;
        IGovernanceContract = IGov(_governance);
    }

    function setCover(address _coverContract) external onlyOwner {
        require(coverContract == address(0), "Governance already set");
        require(
            _coverContract != address(0),
            "Governance address cannot be zero"
        );
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
