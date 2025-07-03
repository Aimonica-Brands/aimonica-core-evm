import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-etherscan";
import "solidity-coverage";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";



const PRIVATE_KEY =
  process.env.PRIVATE_KEY! ||
  "c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

const config: any = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{
      version: "0.8.28", settings: {
        viaIR: true,
        optimizer: {
          enabled: true,
          runs: 200,
        },
      }
    }],
  },
  networks: {
    hardhat: {},
    localhost: {},
    "base-sepolia": {
      url: "https://base-sepolia-rpc.publicnode.com",
      chainId: 84532,
      accounts: [PRIVATE_KEY]
    },
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts: [PRIVATE_KEY]
    },
    // testnet: {
    //   url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    //   chainId: 97,
    //   accounts: [PRIVATE_KEY]
    // },
    // mainnet: {
    //   url: "https://bsc-dataseed1.ninicoin.io/",
    //   chainId: 56,
    //   accounts: [PRIVATE_KEY]
    // },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
    },
  },
  etherscan: {
    apiKey: {
      base: ETHERSCAN_API_KEY,
      "base-sepolia": ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "base-sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  },
};

export default config;