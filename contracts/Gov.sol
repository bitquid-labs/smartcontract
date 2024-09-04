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
        string category;
        uint256 apy;
        string pool;
        uint256 period;
        uint dailyPayout;
        Status status;
        uint256 expiryDate;
    }

    enum Status {
        Active,
        Expired
    }

    function getDeposit(address lp) external view returns (Deposits memory);
    function poolActive(uint256 poolId) external view returns (bool);
    function payClaim(
        uint256 poolId,
        uint256 amount,
        address recipient
    ) external view returns (bool);
}

interface ICover {
    function updateUserCoverValue(
        address user,
        uint256 _coverId,
        uint256 _claimPaid
    ) external;
}

contract Governance is ReentrancyGuard, Ownable {
    struct Proposal {
        uint256 id;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 deadline;
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
        string description;
        uint256 poolId;
        uint256 claimAmount;
    }

    enum ProposalStaus {
        Submitted, 
        Pending,
        Executed,
        Rejected
    }

    uint256 public proposalCounter;
    uint256 public votingDuration;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Voter)) public voters;
    uint256[] public proposalIds; // Array to track proposal IDs

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
    ICover public coverContract;

    constructor(
        address _governanceToken,
        address _insurancePool,
        uint256 _votingDuration,
        address _initialOwner
    ) Ownable(_initialOwner) {
        governanceToken = IERC20(_governanceToken);
        lpContract = ILP(_insurancePool);
        votingDuration = _votingDuration * 1 days;
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
            deadline: block.timestamp + votingDuration,
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
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp <= proposal.deadline,
            "Voting period has ended"
        );
        require(!voters[_proposalId][msg.sender].voted, "Already voted");

        uint256 voterWeight = governanceToken.balanceOf(msg.sender);
        require(voterWeight > 0, "No voting weight");
        require(governanceToken.transfer(msg.sender, 100000000000000000000), "Reward transfer failed");

        if (proposal.status == ProposalStaus.Submitted) {
            proposals[_proposalId].status = ProposalStaus.Pending;
        }

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
        require(
            block.timestamp > proposal.deadline,
            "Voting period is still active"
        );
        require(!proposal.executed, "Proposal already executed");
        proposal.executed = true;

        if (proposal.votesFor > proposal.votesAgainst) {
            require(
                lpContract.payClaim(
                    proposal.proposalParam.poolId,
                    proposal.proposalParam.claimAmount,
                    proposal.proposalParam.user
                ),
                "Error Claiming pay"
            );

            if (proposal.status == ProposalStaus.Pending) {
                proposals[_proposalId].status = ProposalStaus.Executed;
            }

            coverContract.updateUserCoverValue(
                proposal.proposalParam.user,
                proposal.proposalParam.coverId,
                proposal.proposalParam.claimAmount
            );

            emit ProposalExecuted(_proposalId, true);
        } else {
            if (proposal.status == ProposalStaus.Pending) {
                proposals[_proposalId].status = ProposalStaus.Rejected;
            }
            emit ProposalExecuted(_proposalId, false);
        }
    }

    function setVotingDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration > 0, "Voting duration must be greater than 0");
        votingDuration = _newDuration;
    }

    function getProposalDetails(
        uint256 _proposalId
    ) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory result = new Proposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            result[i] = proposals[proposalIds[i]];
        }
        return result;
    }

    function setCoverContract(address _coverContract) external onlyOwner {
        require(_coverContract == address(0), "Governance already set");
        require(
            _coverContract != address(0),
            "Governance address cannot be zero"
        );
        coverContract = ICover(_coverContract);
    }
}
