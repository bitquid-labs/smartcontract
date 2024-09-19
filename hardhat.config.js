require("@nomicfoundation/hardhat-toolbox");
<<<<<<< HEAD
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
=======
>>>>>>> master

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
<<<<<<< HEAD
  networks: {
    bitcoinplus: {
      url: "https://bitcoinplus.pwrlabs.io/",
      accounts: [PRIVATE_KEY],
    },
    b2Testnet: {
      url: "https://zkevm-rpc.bsquared.network",
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
  },
=======
>>>>>>> master
};
