// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CoverLib {
    struct Cover {
        uint256 id;
        string coverName;
        RiskType riskType;
        string chains;
        uint256 capacity;
        uint256 cost;
        uint256 capacityAmount;
        uint256 coverValues;
        uint256 maxAmount;
        uint256 poolId;
        string CID;
    }

    struct GenericCoverInfo {
        address user;
        uint256 coverId;
        RiskType riskType;
        string coverName;
        uint256 coverValue; // This is the value of the cover purchased
        uint256 claimPaid;
        uint256 coverPeriod; // This is the period the cover is purchased for in days
        uint256 endDay; // When the cover expires
        bool isActive;
    }

    enum RiskType {
        Slashing,
        SmartContract,
        Stablecoin,
        Protocol
    }

    struct GenericCover {
        RiskType riskType;
        bytes coverData;
    }

}
