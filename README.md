# AIM Launchpad EVM Staking Contracts

This repository contains the EVM-compatible smart contracts for the AIM Launchpad, a multi-chain staking platform. The `AimStaking` contract is designed to be deployed on EVM chains and is upgradeable using the OpenZeppelin UUPS proxy pattern.

## Features

- **Multi-Project Staking**: Each registered project can have its own ERC20 staking token.
- **Upgradeable**: The contract logic can be upgraded without migrating user data, ensuring future-proof functionality.
- **Time-Locked Staking**: Supports fixed staking durations (e.g., 7, 14, 30 days), configurable by the contract manager.
- **Stake Metadata**: Stores essential data for each stake, including amount, timestamp, duration, and project ID.
- **Emergency Unstake**: Allows users to withdraw their stake before the lock period ends. An `EmergencyUnstaked` event is emitted, allowing a backend system to apply a score penalty.
- **Role-Based Access Control**: Uses `AccessControlEnumerable` for fine-grained permissions.
    - `DEFAULT_ADMIN_ROLE`: Can grant and revoke roles.
    - `MANAGER_ROLE`: Can manage registered projects, staking durations, and project-specific settings.
- **Event-Driven**: Emits detailed events for `Staked`, `Unstaked`, and `EmergencyUnstaked` actions, simplifying backend integration for indexing and scoring.

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

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/en/) (v18 or higher recommended)
- [npm](https://www.npmjs.com/) or [Yarn](https://yarnpkg.com/)

### Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    ```
2.  Navigate to the project directory:
    ```bash
    cd aimonica-core-evm
    ```
3.  Install the dependencies:
    ```bash
    npm install
    ```

## Usage

### Compile Contracts

To compile the smart contracts and generate TypeChain artifacts, run:

```bash
npx hardhat compile
```

### Deploying the Upgradeable Contract

The standard deployment process uses an upgradeable proxy.

#### 1. Deploy the Proxy

The `scripts/deployProxy.ts` script deploys the `AimStaking` contract as a UUPS proxy.

- **Configure the admin**: Open `scripts/deployProxy.ts` and replace the placeholder `"=====Admin Address====="` with the wallet address that will have the `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.

- **Run the deployment script**:
    ```bash
    npx hardhat run scripts/deployProxy.ts --network <your-network-name>
    ```
    This will deploy the proxy contract and its initial implementation, then print the proxy's address.

#### 2. Upgrading the Contract

To upgrade the contract to a new version:

- **Deploy the new implementation**: Make your changes to `AimStaking.sol`.
- **Update the upgrade script**: Open `scripts/upgrade.ts` and replace the placeholder `'=====Deployed Proxy Address====='` with the address of your deployed proxy contract.
- **Run the upgrade script**:
    ```bash
    npx hardhat run scripts/upgrade.ts --network <your-network-name>
    ```
    This will deploy the new implementation and update the proxy to point to it.

#### 3. Verifying the Contract on Etherscan

After deployment or an upgrade, you must verify the **implementation** contract. The proxy itself does not need verification in the same way.

- **Get the implementation address**: After running a deployment or upgrade, the new implementation address will be stored in the `.openzeppelin` directory in a file corresponding to your network (e.g., `.openzeppelin/sepolia.json`).
- **Configure Hardhat**: Add your Etherscan API key to `hardhat.config.ts`.
- **Update the verification script**: Open `scripts/verify.ts` and replace the placeholder `'=====Implementation Contract Address====='` with the new implementation address.
- **Run the verification script**:
    ```bash
    npx hardhat run scripts/verify.ts --network <your-network-name>
    ```

### Non-Upgradeable Deployment (for Testing)

The `scripts/deploy.ts` script provides a simple, non-upgradeable deployment of the `AimStaking` contract. This is useful for development and testing but is **not recommended for production**.

```bash
npx hardhat run scripts/deploy.ts --network <your-network-name>
```

## Smart Contracts

### `AimStaking.sol`

This is the core contract that handles all staking logic. It is designed to be upgradeable and uses `AccessControlEnumerableUpgradeable` to manage permissions. The `MANAGER_ROLE` is responsible for administrative tasks, while the `DEFAULT_ADMIN_ROLE` can manage roles.
