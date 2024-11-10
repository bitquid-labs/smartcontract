require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    bitcoinplus: {
      url: "https://bitcoinplus.pwrlabs.io/",
      accounts: [PRIVATE_KEY],
    },
    b2Testnet: {
      url: "https://rpc.ankr.com/b2_testnet",
      accounts: [PRIVATE_KEY],
    },
    merlin: {
      url: "https://testnet-rpc.merlinchain.io",
      accounts: [PRIVATE_KEY],
    },
    bob: {
      url: "https://bob-sepolia.rpc.gobob.xyz/",
      accounts: [PRIVATE_KEY],
    },
    bitlayer: {
      url: "https://testnet-rpc.bitlayer.org/",
      accounts: [PRIVATE_KEY],
    },
    bevm: {
      url: "https://testnet.bevm.io/",
      accounts: [PRIVATE_KEY],
    },
    anduro: {
      url: "localhost:8545",
      accounts: [PRIVATE_KEY],
    },
    zulu: {
      url: "https://rpc-testnet.zulunetwork.io/",
      accounts: [PRIVATE_KEY],
    },
    rootstock: {
      url: "https://rpc.testnet.rootstock.io/0xmYpavxwaSj27BhDo1j5rzrLEd8Gt-T",
      accounts: [PRIVATE_KEY],
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/VtFb4uQ7Vc5l414EGwXDDzcSClkHv9TY",
      accounts: [PRIVATE_KEY],
    },
    core: {
      url: "https://rpc.test.btcs.network/",
      accounts: [PRIVATE_KEY],
    },
    bsc: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      accounts: [PRIVATE_KEY],
    },
  },
};
