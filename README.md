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

- **BQTOKEN**: 0x69Ca60C40d9E688a69f513e392fB4f07aC3a2a7b
- **BQBTC TOKEN**: 0x0611a6e8D876a9E5D408986deFde849C6A56a465
- **INSURANCEPOOL**: 0x1bc400fe309268A39D3b68093A14257c2c87C531
- **GOVERNANCE**: 0x1C0608698877c5ec29f5DE71a28659Eb3300483b
- **INSURANCECOVER**: 0xB69527aa72653A71908e95FA166ba3821BA0B79a

## **CORE**

- **BQTOKEN**: 0x7057918e198581E31816A2779C77871e6dF6771F
- **BQBTC TOKEN**: 0x0B541754e858535365bcBE5E066831420Ed427d8
- **INSURANCEPOOL**: 0x8382Fbd2CcFE308556fa9Fe8E9E5f3a584bb48A9
- **GOVERNANCE**: 0x04Ba95577Fe875957C16Af37d1EaB7F9D0aE143c
- **INSURANCECOVER**: 0xF50Ce038D7cb97A60811fd2E03ec96Db24b36112
