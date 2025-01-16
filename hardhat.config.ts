import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const LOWEST_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.5.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1,
    },
    outputSelection: {
      "*": {
        "*": ["storageLayout"]
      }
    }
  },
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.5.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"]
            }
          }
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"]
            }
          }
        },
      },
      {
        version: '0.7.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"]
            }
          }
        },
      },
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"]
            }
          }
        },
      },
    ],
    overrides: {
      'contracts/CWNat.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/CWNatDelegate.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
    },
  },
  networks: {
    flare: {
      url: "https://flare-api.flare.network/ext/C/rpc",
      chainId: 14
    },
    coston1: {
      url: "https://coston-api.flare.network/ext/C/rpc",
      chainId: 16
    },
    coston2: {
      url: "https://coston2-api.flare.network/ext/C/rpc",
      chainId: 114
    },
  },
  etherscan: {
    apiKey: {
      flare: "flare", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: 'flare',
        chainId: 14,
        urls: {
          apiURL: "https://flare-explorer.flare.network/api", //"https://api.routescan.io/v2/network/mainnet/evm/14/etherscan",
          browserURL: "https://flare-explorer.flare.network/" //"https://flare.routescan.io"
        },
      },
    ],
  },
  paths: {
    tests: "./tests",
  },
  mocha: {
    timeout: 600000
  }
};

export default config;