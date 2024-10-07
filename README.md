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

- **BQTOKEN**: 0xeC523e0e1f4039Fc5210d8f849Aa96363647586e
- **BQBTC TOKEN**: 0xd4d6D32774267870CB38dd00af8B7edB96eBEfC7
- **INSURANCEPOOL**: 0xFe0330bCAafb69BFB5B6038Be0eBfDB65E2EE10f
- **GOVERNANCE**: 0x95bEa6bdd0f0adaC1714910069128a4B7F75e135
- **INSURANCECOVER**: 0xEbC11e13375DEc4c43118b8f530b0dc31fF9e4a7
