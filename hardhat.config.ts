const avalanche = require("avalanche");
const balance = require("@openzeppelin/test-helpers/src/balance");

import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-spdx-license-identifier";
//import "hardhat-typechain";
import "hardhat-watcher";
import "@tenderly/hardhat-tenderly";
import "solidity-coverage";
//import "./tasks";

import { HardhatUserConfig } from "hardhat/types";

const accounts = {
  mnemonic:
    process.env.MNEMONIC ||
    "test test test test test test test test test test test junk",
  // accountsBalance: "990000000000000000000",
};

const config: HardhatUserConfig = {
  abiExporter: {
    path: "./abi",
    clear: false,
    flat: true,
    // only: [],
    // except: []
  },
  mocha: {
    timeout: 20000,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    developer: {
      default: 1,
    },
    treasury: {
      default: 2,
    },
    gamerewards: {
      default: 3,
    },
    fees: {
      default: 4,
    },
    admin1: {
      default: 5,
    },
    admin2: {
      default: 6,
    },
    admin3: {
      default: 7,
    },
    admin4: {
      default: 8,
    },
  },

  networks: {
    localhost: {
      live: false,
      saveDeployments: true,
      tags: ["local"],
    },
    hardhat: {
      gasPrice: 470000000000,
      chainId: 43112,
    },
    avash: {
      url: "http://localhost:9650/ext/bc/C/rpc",
      gasPrice: 470000000000,
      chainId: 43112,
      accounts: [],
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: [],
      chainId: 43113,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gasMultiplier: 2,
      gasPrice: 470000000000,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [],
      chainId: 43114,
      live: true,
      saveDeployments: true,
      gasPrice: 470000000000,
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      accounts,
      chainId: 56,
      live: true,
      saveDeployments: true,
    },
    "bsc-testnet": {
      url: "https://data-seed-prebsc-2-s3.binance.org:8545",
      accounts,
      chainId: 97,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gasMultiplier: 2,
    },
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "deploy",
    deployments: "deployments",
    imports: "imports",
    sources: "contracts",
    tests: "test",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.3",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
};

export default config;
