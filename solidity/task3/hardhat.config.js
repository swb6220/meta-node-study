require("@chainlink/env-enc").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy")

const PRIVATE_KEY = process.env.PK || "";
const SEPOLIA_RPPC_URL = process.env.SEPOLIA_PRC_ENDPOINT || "";
const AMOY_RPC_URL = process.env.AMOY_PRC_ENDPOINT || "";

// console.log(`url: ${SEPOLIA_PRC_URL}`);
// console.log(`pk: ${PRIVATE_KEY}`);

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  namedAccounts: {
    firstAccount: {
      default: 0 
    },
    masterDeployer: {
      default: 0 // the first account is the master deployer
    },
    slaveDeployer: {
      default: 0 // the second account is the second account
    }
  },
  networks: {
    sepolia: {
      chainId: 11155111,
      url: SEPOLIA_RPPC_URL,
      accounts: [PRIVATE_KEY]
    },
    amoy: {
      chainId: 80002,
      url: AMOY_RPC_URL,
      accounts: [PRIVATE_KEY]
    }
  }
};
