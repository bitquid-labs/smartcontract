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
        uint256 dailyPayout;
        Status status;
        uint256 daysLeft;
        uint256 startDate;
        uint256 expiryDate;
        uint256 accruedPayout;
    }

    enum Status {
        Active,
        Expired
    }

    function poolActive(uint256 poolId) external view returns (bool);
}

interface ICover {
    function updateUserCoverValue(
        address user,
        uint256 _coverId,
        uint256 _claimPaid
    ) external;
}

contract Governance is ReentrancyGuard, Ownable {
    error VotingTimeElapsed();
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

    struct Voter {
        bool voted;
        bool vote;
        uint256 weight;
    }

    struct ProposalParams {
        address user;
        CoverLib.RiskType riskType;
        uint256 coverId;
        string txHash;
        string description;
        uint256 poolId;
        uint256 claimAmount;
    }

    enum ProposalStaus {
        Submitted, 
        Pending,
        Approved,
        Claimed,
        Rejected
    }

    uint256 public proposalCounter;
    uint256 public votingDuration;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Voter)) public voters;
    uint256[] public proposalIds;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed creator,
        string description,
        CoverLib.RiskType riskType,
        uint256 claimAmount,
        ProposalStaus status
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool vote,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId, bool approved);

    IERC20 public governanceToken;
    ILP public lpContract;
    ICover public ICoverContract;
    address public coverContract;
    address public poolContract;

    constructor(
        address _governanceToken,
        address _insurancePool,
        uint256 _votingDuration,
        address _initialOwner
    ) Ownable(_initialOwner) {
        governanceToken = IERC20(_governanceToken);
        lpContract = ILP(_insurancePool);
        poolContract = _insurancePool;
        votingDuration = _votingDuration * 1 minutes;
    }

    function createProposal(ProposalParams memory params) external {
        require(lpContract.poolActive(params.poolId), "Pool does not exist");
        require(params.claimAmount > 0, "Claim amount must be greater than 0");

        proposalCounter++;

        proposals[proposalCounter] = Proposal({
            id: proposalCounter,
            votesFor: 0,
            votesAgainst: 0,
            createdAt: block.timestamp,
            deadline: 0,
            timeleft: 0,
            executed: false,
            status: ProposalStaus.Submitted,
            proposalParam: params
        });

        proposalIds.push(proposalCounter); // Track the proposal ID

        emit ProposalCreated(
            proposalCounter,
            params.user,
            params.description,
            params.riskType,
            params.claimAmount,
            ProposalStaus.Submitted
        );
    }

    function vote(uint256 _proposalId, bool _vote) external {
        require(!voters[_proposalId][msg.sender].voted, "Already voted");
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.createdAt != 0, "Proposal does not exist");
        
        if (proposal.status == ProposalStaus.Submitted) {
            proposal.status = ProposalStaus.Pending;
            proposal.deadline = block.timestamp + votingDuration;
            proposal.timeleft = (proposal.deadline - block.timestamp) / 1 minutes;
        } else if (block.timestamp >= proposal.deadline) {
            proposal.timeleft = 0;
            revert VotingTimeElapsed();
        }

        proposal.timeleft = (proposal.deadline - block.timestamp) / 1 minutes;
        uint256 voterWeight = governanceToken.balanceOf(msg.sender);
        require(voterWeight > 0, "No voting weight");

        voters[_proposalId][msg.sender] = Voter({
            voted: true,
            vote: _vote,
            weight: voterWeight
        });

        if (_vote) {
            proposal.votesFor += voterWeight;
        } else {
            proposal.votesAgainst += voterWeight;
        }

        emit VoteCast(msg.sender, _proposalId, _vote, voterWeight);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner nonReentrant {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStaus.Pending, "Proposal not pending");
        require(
            block.timestamp > proposal.deadline,
            "Voting period is still active"
        );
        require(!proposal.executed, "Proposal already executed");
        proposal.executed = true;

        if (proposal.votesFor > proposal.votesAgainst) {

            proposals[_proposalId].status = ProposalStaus.Approved;

            ICoverContract.updateUserCoverValue(
                proposal.proposalParam.user,
                proposal.proposalParam.coverId,
                proposal.proposalParam.claimAmount
            );

            emit ProposalExecuted(_proposalId, true);
        } else {
            proposals[_proposalId].status = ProposalStaus.Rejected;
            emit ProposalExecuted(_proposalId, false);
        }
    }

    function updateProposalStatusToClaimed(uint256 proposalId) public nonReentrant {
        require(msg.sender == proposals[proposalId].proposalParam.user || msg.sender == poolContract, "Not the valid proposer");
        proposals[proposalId].status = ProposalStaus.Claimed;
    }

    function setVotingDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration > 0, "Voting duration must be greater than 0");
        votingDuration = _newDuration;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCounter;
    }

    function getProposalDetails(
        uint256 _proposalId
    ) external returns (Proposal memory) {
        if (block.timestamp >= proposals[_proposalId].deadline) {
            proposals[_proposalId].timeleft = 0;
        } else {
            proposals[_proposalId].timeleft = (proposals[_proposalId].deadline - block.timestamp) / 1 minutes;
        }
        return proposals[_proposalId];
    }

    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory result = new Proposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            result[i] = proposals[proposalIds[i]];
            if (block.timestamp >= result[i].deadline) {
                result[i].timeleft = 0;
            } else {
                result[i].timeleft = (result[i].deadline - block.timestamp) / 1 minutes;
            }
        }
        return result;
    }

    function getActiveProposals() public view returns (Proposal[] memory) {
        Proposal[] memory result = new Proposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposals[proposalIds[i]].status == ProposalStaus.Submitted || proposals[proposalIds[i]].deadline >= block.timestamp) {
                result[i] = proposals[proposalIds[i]];
                if (block.timestamp == result[i].deadline) {
                    result[i].timeleft = 0;
                } else {
                    result[i].timeleft = (result[i].deadline - block.timestamp) / 1 minutes;
                }
            }
        }
        return result;
    }

    function getPastProposals() public view returns (Proposal[] memory) {
        Proposal[] memory result = new Proposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposals[proposalIds[i]].status != ProposalStaus.Submitted && proposals[proposalIds[i]].deadline < block.timestamp) {
                result[i] = proposals[proposalIds[i]];
                result[i].timeleft = 0;
            }
        }
        return result;
    }

    function setCoverContract(address _coverContract) external onlyOwner {
        require(coverContract == address(0), "Governance already set");
        require(
            _coverContract != address(0),
            "Governance address cannot be zero"
        );
        ICoverContract = ICover(_coverContract);
        coverContract = _coverContract;
    }
}
