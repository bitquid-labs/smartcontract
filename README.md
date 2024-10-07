# Contract changes

## InsurancePool Contract

- Deposit function now accepts extra parameter `_amount` for the value the user wants to deposit:

```solidity
function deposit(uint256 _poolId, uint256 _amount) public nonReentrant
```

## InsuranceCover Contract

- Purchase cover now accepts an extra parameter `_coverFee` for the dynamic cover fee from the frontend:

```solidity
function purchaseCover(
        uint256 _coverId,
        uint256 _coverValue,
        uint256 _coverPeriod,
        uint256 _coverFee
    ) public nonReentrant
```

# Contract Addresses

## **BEVM**

- **BQTOKEN**: 0xc910FE89A0835d95f210247Ed4069A11f335a1C4
- **BQBTC TOKEN**: 0x1A6E4F8F8A0E34E6D74119C2588Cf41560F09757
- **INSURANCEPOOL**: 0xeC18ae0Bf2Dd05968cFAA4caf96Bdc033DFcD291
- **GOVERNANCE**: 0xda4d320823c4767DE91C58694daf7285C9774A3E
- **INSURANCECOVER**: 0xa4ac73E642400B2dB4Ae51f5999FB01DD57BFf1E
