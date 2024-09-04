// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CoverLib.sol";

interface ILP {
    struct Deposits {
        address lp;
        uint256 amount;
        uint256 poolId;
        uint256 period;
        uint256 dailyPayout;
        Status status;
        uint256 expiryDate;
    }

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

    enum Status {
        Active,
        Expired
    }

    function getUserDeposit(
        uint256 _poolId,
        address _user
    ) external view returns (Deposits memory);

    function getPool(
        uint256 _poolId
    )
        external
        view
        returns (
            string memory name,
            CoverLib.RiskType riskType,
            uint256 apy,
            uint256 minPeriod,
            uint256 tvl,
            bool isActive,
            uint256 percentageSplitBalance
        );

        function updatePercentageSplit(uint256 _poolId,uint256 __poolPercentageSplit) external ;
        function updatePoolCovers(uint256 _poolId, CoverLib.Cover memory _cover) external ;
}

contract InsuranceCover is ReentrancyGuard, Ownable {
    using CoverLib for *;

    error LpNotActive();
    error InsufficientPoolBalance();
    error NoClaimableReward();
    error InvalidCoverDuration();
    error CoverNotAvailable();
    error InvalidAmount();
    error UnsupportedCoverType();
    error WrongPool();

    uint public coverFeeBalance;
    ILP public lpContract;
    address public lpAddress;
    address public governance;

    mapping(uint256 => bool) public coverExists;
    mapping(address => uint256) public NextLpClaimTime;

    mapping(address => mapping(uint256 => CoverLib.GenericCoverInfo)) public userCovers;
    mapping(uint256 => CoverLib.Cover) public covers;

    uint256 public coverCount;

    event CoverCreated(
        string name,
        CoverLib.RiskType riskType
    );
    event CoverPurchased(
        address indexed user,
        uint256 coverValue,
        uint256 coverFee,
        CoverLib.RiskType riskType
    );
    event PayoutClaimed(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    constructor(
        address _lpContract,
        address _initialOwner,
        address _governace
    ) Ownable(_initialOwner) {
        lpContract = ILP(_lpContract);
        lpAddress = _lpContract;
        governance = _governace;
    }

    function createCover(
        string memory _cid,
        CoverLib.RiskType _riskType,
        string memory _coverName,
        string memory _chains,
        uint256 _capacity,
        uint256 _cost,
        uint256 _poolId
    ) public onlyOwner {
        (, CoverLib.RiskType risk, , , uint256 tvl, , uint256 _percentageSplitBalance) = lpContract.getPool(_poolId);

        if (risk != _riskType || _capacity > _percentageSplitBalance) {
            revert WrongPool();
        }

        uint256 _maxAmount = tvl * (_capacity * 1e18 / 100) / 1e18;

        lpContract.updatePercentageSplit(_poolId, _capacity);

        coverCount++;
        CoverLib.Cover memory cover =  CoverLib.Cover({
            id: coverCount,
            coverName: _coverName,
            riskType: _riskType,
            chains: _chains,
            capacity: _capacity,
            cost: _cost,
            capacityAmount: _maxAmount,
            coverValues: 0,
            maxAmount: _maxAmount,
            poolId: _poolId,
            CID: _cid
        });
        covers[coverCount] = cover;
        lpContract.updatePoolCovers(_poolId, cover);
        coverExists[coverCount] = true;

        emit CoverCreated(_coverName, _riskType);
    }

    function purchaseCover(
        uint256 _coverId,
        uint256 _coverValue,
        uint256 _coverPeriod
    ) public payable nonReentrant {
        if (msg.value <= 0) {
            revert InvalidAmount();
        }
        if (_coverPeriod <= 27 || _coverPeriod >= 366) {
            revert InvalidCoverDuration();
        }
        if (!coverExists[_coverId]) {
            revert CoverNotAvailable();
        }

        CoverLib.Cover storage cover = covers[_coverId];
        if (_coverValue > cover.maxAmount) {
            revert InsufficientPoolBalance();
        }

        cover.capacityAmount -= _coverValue;
        cover.coverValues += _coverValue;
        cover.maxAmount = (cover.capacityAmount - cover.coverValues);
        CoverLib.GenericCoverInfo storage userCover = userCovers[msg.sender][_coverId];
        
        if (userCover.coverValue == 0) {
            userCovers[msg.sender][_coverId] = CoverLib.GenericCoverInfo({
                user: msg.sender,
                coverId: _coverId,
                riskType: cover.riskType,
                coverName: cover.coverName,
                coverValue: _coverValue,
                claimPaid: 0,
                coverPeriod: _coverPeriod,
                endDay: block.timestamp + (_coverPeriod * 1 days),
                isActive: true
            });
        } else {
            require((userCover.coverPeriod + _coverPeriod) < 366, "Total cover period must be less than 365");
            userCover.coverValue += _coverValue;
            userCover.coverPeriod += _coverPeriod;
            userCover.endDay += (userCover.coverPeriod * 1 days);
        }

        emit CoverPurchased(msg.sender, _coverValue, msg.value, cover.riskType);
    }

    function getAllUserCovers(address user) external view returns (CoverLib.GenericCoverInfo[] memory) {
        CoverLib.GenericCoverInfo[] memory userCoverList = new CoverLib.GenericCoverInfo[](coverCount);
        uint256 actualCount = 0;

        for (uint256 i = 1; i <= coverCount; i++) {
            if (userCovers[user][i].coverValue > 0) {
                userCoverList[actualCount] = userCovers[user][i];
                actualCount++;
            }
        }

        assembly {
            mstore(userCoverList, actualCount)
        }

        return userCoverList;
    }

    function getAllAvailableCovers() external view returns (CoverLib.Cover[] memory) {
        CoverLib.Cover[] memory availableCovers = new CoverLib.Cover[](coverCount);
        uint256 actualCount = 0;

        for (uint256 i = 1; i <= coverCount; i++) {
            if (coverExists[i]) {
                availableCovers[actualCount] = covers[i];
                actualCount++;
            }
        }
        assembly {
            mstore(availableCovers, actualCount)
        }
        return availableCovers;
    }

    function getUserCoverInfo(address user, uint256 _coverId) external view returns (CoverLib.GenericCoverInfo memory) {
        return userCovers[user][_coverId];
    }

    function updateUserCoverValue(address user, uint256 _coverId, uint256 _claimPaid) public onlyGovernance nonReentrant {
        userCovers[user][_coverId].coverValue -= _claimPaid;
        userCovers[user][_coverId].claimPaid += _claimPaid;
    }

    function updateMaxAmount(uint256 _coverId) public onlyPool nonReentrant {
        CoverLib.Cover storage cover = covers[_coverId];
        (, , , , uint256 tvl, , ) = lpContract.getPool(cover.poolId);
        require(tvl > 0, "TVL is zero");
        require(cover.capacity > 0, "Invalid cover capacity");
        uint256 amount = tvl * (cover.capacity * 1e18 / 100) / 1e18;
        covers[_coverId].capacityAmount = amount;
        covers[_coverId].maxAmount = (covers[_coverId].capacityAmount - covers[_coverId].coverValues);
    }

    function claimPayoutForLP(uint256 _poolId) external nonReentrant {
        ILP.Deposits memory depositInfo = lpContract.getUserDeposit(_poolId, msg.sender);
        if (depositInfo.status != ILP.Status.Active) {
            revert LpNotActive();
        }
        
        uint256 lastClaimTime = NextLpClaimTime[msg.sender];
        uint256 claimableDays = (block.timestamp - lastClaimTime) / 1 days;

        if (claimableDays <= 0) {
            revert NoClaimableReward();
        }
        uint256 claimableAmount = depositInfo.dailyPayout * claimableDays;

        if (claimableAmount > coverFeeBalance) {
            revert InsufficientPoolBalance();
        }
        NextLpClaimTime[msg.sender] = block.timestamp;

        (bool success, ) = msg.sender.call{value: claimableAmount}("");
        require(success, "Transfer failed");

        coverFeeBalance -= claimableAmount;

        emit PayoutClaimed(msg.sender, _poolId, claimableAmount);
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Not authorized");
        _;
    }

    modifier onlyPool() {
        require(msg.sender == lpAddress, "Not authorized");
        _;
    }
}
