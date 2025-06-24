# AIM Launchpad EVM Staking Contracts

This repository contains the EVM-compatible smart contracts for the AIM Launchpad, a multi-chain staking platform. The `AimStaking` contract is designed to be deployed on EVM chains and is upgradeable using the OpenZeppelin UUPS proxy pattern, ensuring that the contract logic can be updated without data migration.

## Table of Contents

- [AIM Launchpad EVM Staking Contracts](#aim-launchpad-evm-staking-contracts)
  - [Table of Contents](#table-of-contents)
  - [Technical Documentation](#technical-documentation)
    - [Contract Architecture](#contract-architecture)
    - [Core Concepts](#core-concepts)
    - [Roles (Access Control)](#roles-access-control)
    - [State Variables & Data Structures](#state-variables--data-structures)
    - [Functions](#functions)
    - [Events](#events)
  - [Deployment and Operations Guide](#deployment-and-operations-guide)
    - [Prerequisites](#prerequisites)
    - [1. Setup](#1-setup)
    - [2. Configuration](#2-configuration)
    - [3. Compile](#3-compile)
    - [4. Deploy](#4-deploy)
    - [5. Upgrade](#5-upgrade)
    - [6. Verify on Etherscan](#6-verify-on-etherscan)
  - [Project Structure](#project-structure)

## Technical Documentation

### Contract Architecture

-   **AimStaking.sol**: The core contract containing all staking logic.
-   **Upgradeable Design (UUPS)**: The contract uses the UUPS (Universal Upgradeable Proxy Standard) pattern. This means the contract is deployed behind a proxy, and the logic contract (implementation) can be swapped out for a new one. This allows for seamless upgrades to add features or fix bugs without affecting user data or requiring migration.
-   **Security**: Inherits from OpenZeppelin's `AccessControlEnumerableUpgradeable` for role-based permissions and `ReentrancyGuardUpgradeable` to prevent re-entrancy attacks.

### Core Concepts

-   **Projects**: The platform supports multiple staking projects. Each project is identified by a unique `bytes32 projectId`. A manager must register a project before users can stake in it.
-   **Staking Tokens**: Each registered project has its own designated ERC20 token for staking. The token address must be set by a manager for the corresponding project.
-   **Staking Durations**: The contract supports fixed-term staking. A manager can define a list of allowed staking durations (e.g., 7, 14, 30 days). Users must choose from one of these predefined durations when staking.
-   **Fees**:
    -   `unstakeFeeRate`: A percentage fee taken on a normal unstake after the lock period.
    -   `emergencyUnstakeFeeRate`: A percentage fee (typically higher) for withdrawing a stake before the lock period expires.
    -   Fees are specified in basis points (100 = 1%) and are sent to a designated `feeWallet`.

### Roles (Access Control)

The contract is governed by two main roles:

-   `DEFAULT_ADMIN_ROLE`: The highest level of authority. This role can grant and revoke any role, including `MANAGER_ROLE` and itself. It is critical to keep the address holding this role secure.
-   `MANAGER_ROLE`: This role handles the day-to-day administration of the staking platform. Responsibilities include:
    -   Managing projects (registering, unregistering).
    -   Setting the staking token for each project.
    -   Managing allowed staking durations.
    -   Configuring fee rates and the fee wallet.

### State Variables & Data Structures

-   `Stake`: A `struct` that stores all information for a single stake, including `stakeId`, `user`, `amount`, `projectId`, `stakedAt`, `unlockedAt`, and `status`.
-   `StakeStatus`: An `enum` to track the state of a stake (`Active`, `Unstaked`, `EmergencyUnstaked`).
-   `stakes`: `mapping(uint256 => Stake)` a mapping from a stake ID to the `Stake` struct.
-   `projectStakingTokens`: `mapping(bytes32 => address)` a mapping from a project ID to its designated ERC20 staking token address.
-   `registeredProjects`: `mapping(bytes32 => bool)` tracks whether a project ID is valid.
-   `durationOptions`: `mapping(uint256 => bool)` tracks valid staking durations in days.

### Functions

#### User-Facing Functions

-   `stake(uint256 amount, uint256 durationInDays, bytes32 projectId)`: Stakes a specified `amount` of the project's token for the user.
-   `unstake(uint256 stakeId)`: Withdraws a stake after its lock period has ended.
-   `emergencyUnstake(uint256 stakeId)`: Withdraws a stake before its lock period has ended, subject to a penalty fee.
-   `getUserStakes(address user)`: Returns an array of IDs for all stakes made by a user.
-   `getActiveUserStakes(address user)`: Returns an array of IDs for a user's currently active stakes.

#### Manager-Facing Functions (`onlyRole(MANAGER_ROLE)`)

-   `setFeeWallet(address _feeWallet)`: Sets the wallet address where fees are collected.
-   `setUnstakeFeeRate(uint256 _unstakeFeeRate)`: Sets the fee for normal unstaking.
-   `setEmergencyUnstakeFeeRate(uint256 _emergencyUnstakeFeeRate)`: Sets the fee for emergency unstaking.
-   `registerProject(bytes32 projectId)` / `unregisterProject(bytes32 projectId)`: Manages the lifecycle of a project.
-   `setProjectStakingToken(bytes32 projectId, address stakingTokenAddress)`: Assigns an ERC20 token to a project.
-   `addDurationOption(uint256 durationInDays)` / `removeDurationOption(uint256 durationInDays)`: Manages the available staking lock-up periods.

### Events

The contract emits events for all significant actions, allowing for easy off-chain monitoring and backend integration.

-   `Staked(uint256 stakeId, address indexed user, ...)`
-   `Unstaked(uint256 stakeId, address indexed user, ...)`
-   `EmergencyUnstaked(uint256 stakeId, address indexed user, ...)`
-   `ProjectRegistered(bytes32 projectId)` / `ProjectUnregistered(bytes32 projectId)`
-   `ProjectStakingTokenSet(bytes32 indexed projectId, address tokenAddress)`
-   `DurationOptionAdded(uint256 duration)` / `DurationOptionRemoved(uint256 duration)`
-   `FeeWalletSet(address indexed newWallet)`

## Deployment and Operations Guide

### Prerequisites

-   [Node.js](https://nodejs.org/en/) (v18 or higher)
-   [npm](https://www.npmjs.com/) or [Yarn](https://yarnpkg.com/)
-   Git

### 1. Setup

Clone the repository and install the required dependencies.

```bash
git clone <repository-url>
cd aimonica-core-evm
npm install
```

### 2. Configuration

All configuration is managed in `hardhat.config.ts`. You must edit this file to set up your target network and Etherscan API key for verification.

```typescript
// hardhat.config.ts

// ...
  networks: {
    sepolia: { // Example network
      url: "https://rpc.sepolia.org", // Replace with your RPC endpoint
      accounts: ["YOUR_PRIVATE_KEY_HERE"], // Replace with the private key of the deployer wallet
    },
  },
  etherscan: {
    apiKey: "YOUR_ETHERSCAN_API_KEY", // Replace with your Etherscan API key
  },
// ...
```

**Security Warning**: Hardcoding private keys is highly insecure and not recommended for production. Consider using a secure method like environment variables (e.g., with `dotenv`) to handle sensitive data.

### 3. Compile

Compile the smart contracts and generate TypeChain artifacts. This step ensures your contracts are ready for deployment and that all type definitions are up-to-date.

```bash
npx hardhat compile
```

### 4. Deploy

The contract is deployed as a UUPS proxy using the `deployProxy.ts` script.

**Action Required**:
1.  Open the `scripts/deployProxy.ts` file.
2.  Locate the `initializeArgs` array.
3.  Replace the placeholder `"=====Admin Address====="` with the wallet address that will receive the `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`. This address will have full control over the contract.

```typescript
// scripts/deployProxy.ts
const initializeArgs: any[] = [
  "0xYourAdminWalletAddressHere" // <--- EDIT THIS LINE
];
```

**Deploy Command**:
Run the following command, replacing `<your-network-name>` with the network key you configured in `hardhat.config.ts` (e.g., `sepolia`).

```bash
npx hardhat run scripts/deployProxy.ts --network <your-network-name>
```

Upon successful execution, the script will print the **proxy contract address**. Save this address, as you will need it for upgrades and interaction.

```
AimStaking contract successfully deployed: 0xProxyContractAddress...
```

### 5. Upgrade

To upgrade the contract, you first make changes to `AimStaking.sol`, and then run the `upgrade.ts` script.

**Action Required**:
1.  Open the `scripts/upgrade.ts` file.
2.  Replace the placeholder `'=====Deployed Proxy Address====='` with the proxy address you received during deployment.

```typescript
// scripts/upgrade.ts
await upgrades.upgradeProxy('0xProxyContractAddress...', factory); // <--- EDIT THIS LINE
```

**Upgrade Command**:
Run the script to deploy the new implementation and link it to the existing proxy.

```bash
npx hardhat run scripts/upgrade.ts --network <your-network-name>
```

### 6. Verify on Etherscan

After deploying or upgrading, you must verify the **implementation contract**, not the proxy.

**How to find the Implementation Address**:
The implementation address is stored by the OpenZeppelin upgrades plugin in the `.openzeppelin` directory. After deploying to a network, a JSON file for that network will be created (e.g., `.openzeppelin/sepolia.json`). Open it and find the `address` field under your contract—this is the latest implementation address.

```json
// .openzeppelin/sepolia.json (example)
{
  "proxies": [
    {
      "address": "0xProxyContractAddress...",
      "txHash": "...",
      "kind": "uups"
    }
  ],
  "impls": {
    "ab12cdef...": { // Previous implementation version
      "address": "0xOldImplementationAddress...",
      "layout": { ... }
    },
    "1234abcd...": { // Current implementation version
      "address": "0xNewImplementationAddress...", // <-- THIS IS THE ADDRESS YOU NEED
      "layout": { ... }
    }
  }
}
```

**Action Required**:
1.  Open the `scripts/verify.ts` file.
2.  Replace the placeholder `'=====Implementation Contract Address====='` with the implementation address you found.

```typescript
// scripts/verify.ts
await hre.run("verify:verify", {
  address: '0xNewImplementationAddress...', // <--- EDIT THIS LINE
  // ...
});
```

**Verification Command**:
Run the script to publish the source code on Etherscan.

```bash
npx hardhat run scripts/verify.ts --network <your-network-name>
```

## Project Structure

```
.
├── contracts/
│   └── pool/
│       └── AimStaking.sol      # The main upgradeable staking contract
├── scripts/
│   ├── deployProxy.ts          # Script for deploying the contract as a proxy
│   ├── upgrade.ts              # Script for upgrading the contract implementation
│   ├── verify.ts               # Script for verifying the implementation on Etherscan
│   └── deploy.ts               # Script for a simple, non-upgradeable deployment
├── hardhat.config.ts           # Hardhat configuration file
└── package.json                # Project dependencies
```



## Deployed Programs and Accounts (Mainnet)

This section lists the contract addresses and related account information deployed on the BASE mainnet, captured from test execution.

### `AimStaking` Contract

*   **Proxy Contract Address**: `0x29ecDC454121184C5F06E0f067ae11aA2d43184f`
*   **Implementation Contract Address**: `0xC1cbBAf6F6BB21E68434B10d6b81bF2e6C305786`

### Key Actors & Wallets

*   **Platform Administrator (Admin)**: `0xf379d24dCE0Bb73d87d3499D4F1cC87F0Bd0091F`
    - Holds `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`
    - Can grant and revoke any role permissions
*   **Project Manager**: `0xA30D18C731c9944F904fFB1011c17B75280d2A08`
    - Holds `MANAGER_ROLE`
    - Responsible for daily management operations
*   **User Wallet**: `0x6716EEc26c82a8a025Cef05D301E0aF8cb8dA33D`
*   **Fee Wallet**: `0x85287192f6436bD963Af7D9bf10Aed3751647570`

### Staking Project: "demo"

This project was registered and interacted with during the test run.

*   **Project Name**: `demo`
*   **Project ID**: `0x64656d6f00000000000000000000000000000000000000000000000000000000` 
    - (keccak256 hash of the string "demo")
*   **Staking Token Contract Address**: `0x3d1c275aa98d45c99258a51be98b08fc8572c074`
*   **Staking Token Name**: `Baby Kibshi (BKIBSHI)`
*   **Staking Token Initial Supply**: `1,000,000,000 BKIBSHI`

### User Staking Data

*   **User Token Balance**: `6495 BKIBSHI`
*   **First Stake Information**:
    - **Stake ID**: `1`
    - **Stake Amount**: `100 BKIBSHI`
    - **Staking Duration**: `7 days`
    - **Stake Status**: `Active`
*   **Second Stake Information**:
    - **Stake ID**: `2`
    - **Stake Amount**: `150 BKIBSHI`
    - **Staking Duration**: `1 day`
    - **Stake Status**: `EmergencyUnstake`

### Platform Configuration & System Parameters

*   **Regular Unstake Fee Rate**: `100` (1%)
*   **Emergency Unstake Fee Rate**: `1000` (10%)
*   **Supported Staking Duration Options**: 
    - `1 day`
    - `7 days`
    - `14 days`
    - `30 days`
