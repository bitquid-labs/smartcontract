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

- **BQTOKEN**: 0x418Ee12F117070D47AC9BE7d3564C4F834d0A8E4
- **BQBTC TOKEN**: 0xf3617C7AAfe6b2e6e8eCabB942cd67144a66E624
- **INSURANCEPOOL**: 0x967D7f5D3d38CBdFee4808Cc0b5FE9FBBce8e188
- **GOVERNANCE**: 0x176363D6F403B6c7408DBeF56FfFCe982372da24
- **INSURANCECOVER**: 0x9552c86e01B431066AddE3096DFB482CbD82A185

## **CORE**

- **BQTOKEN**: 0xeC523e0e1f4039Fc5210d8f849Aa96363647586e
- **BQBTC TOKEN**: 0xd4d6D32774267870CB38dd00af8B7edB96eBEfC7
- **INSURANCEPOOL**: 0xFe0330bCAafb69BFB5B6038Be0eBfDB65E2EE10f
- **GOVERNANCE**: 0x95bEa6bdd0f0adaC1714910069128a4B7F75e135
- **INSURANCECOVER**: 0xEbC11e13375DEc4c43118b8f530b0dc31fF9e4a7

## **MERLIN**

- **BQTOKEN**: 0xC05F41e638A82c6eB6854624957227aAB992892C
- **BQBTC TOKEN**: 0x41d4E0605002D4dbe450A42f8e89ae5Ed5f9bE7a
- **INSURANCEPOOL**: 0xd80f79bC4cf0AC7094b22aB1a3E4010cFeB78669
- **GOVERNANCE**: 0xe3f9e3fD647e31d46045A43b7781EAed8e4D46AD
- **INSURANCECOVER**: 0x180e565b81422e9F38e8e852Cd7CA3CD50AB8777

## **BOB**

- **BQTOKEN**: 0xF801e55031D91602123f5d7f3ac80F4BF204EE3E
- **BQBTC TOKEN**: 0x5ca39c56F3EE9aFb85De57bd1dD76662F6578991
- **INSURANCEPOOL**: 0xFa51d5DCb5F0b689169c7Fa4F9D70B7d4286846d
- **GOVERNANCE**: 0x0Bec905ED08A0B9f2f00D7B517C2276B60fD0D50
- **INSURANCECOVER**: 0x6C2F9C23F528a409bDD8e9ACCf3617dB82E796D4

## **BITLAYER**

- **BQTOKEN**: 0x3B4990516950C355Da590ec8E034c02802d4daF2
- **BQBTC TOKEN**: 0x260E26e2Cdcdf05C4C93d7a2bd380AaE9D13d0BF
- **INSURANCEPOOL**: 0xD19F579fA1d4E53e951fE62cD7acDD9966e62855
- **GOVERNANCE**: 0x238E8Be85D7C58E85AFAd4eaB80C69333957359A
- **INSURANCECOVER**: 0x325fEb760bBD9117a0be901FCA79F10D87FDF709

## **ROOTSTOCK**

- **BQTOKEN**: 0x7cBDCa7f78B3A43Da33892bdF7D10c80351b799c
- **BQBTC TOKEN**: 0x1EfE902d6aFf44d3C8d245f2d4144db84964a9b4
- **INSURANCEPOOL**: 0x68543e919B6cd5D884E22Ed85f912daE5De2371b
- **GOVERNANCE**: 0x483842959b2457179561820E9e676da53B63bCD0
- **INSURANCECOVER**: 0xfAB08717d5779DBe49Aa6b547b553593f52744c0
