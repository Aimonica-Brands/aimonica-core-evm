# AIM Launchpad EVM Staking Contracts

This repository contains the EVM-compatible smart contracts for the AIM Launchpad, a multi-chain staking platform. This contract, `AimStakingEvm`, is designed to be deployed on EVM chains such as Base, Ethereum, Arbitrum, etc.

## Features

- **ERC20 Token Staking**: Stake any ERC20-compliant token.
- **Time-Locked Staking**: Supports fixed staking durations (e.g., 7, 14, 30 days), configurable by the contract owner.
- **Stake Metadata**: Stores essential data for each stake, including amount, timestamp, duration, and project ID.
- **Emergency Unstake**: Allows users to withdraw their stake before the lock period ends. An `EmergencyUnstaked` event is emitted, allowing a backend system to apply a score penalty.
- **Admin Controls**: Secure functions for the contract owner to manage registered projects and valid staking durations.
- **Event-Driven**: Emits detailed events for `Staked`, `Unstaked`, and `EmergencyUnstaked` actions, simplifying backend integration for indexing and scoring.

## Project Structure

```
.
├── contracts/
│   ├── AimStakingEvm.sol  # The main staking contract
│   └── mocks/
│       └── MockERC20.sol    # A mock ERC20 token for testing
├── scripts/
│   └── deploy.ts          # Script for deploying the contracts
├── test/
│   └── AimStakingEvm.ts   # Tests for the staking contract
├── hardhat.config.ts      # Hardhat configuration file
└── package.json           # Project dependencies
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

### Run Tests

To ensure the contracts are working as expected, run the test suite:

```bash
npx hardhat test
```

The tests cover various scenarios, including deployment, staking, regular unstaking, emergency unstaking, and admin functions.

### Deploy Contracts

The provided deployment script (`scripts/deploy.ts`) can be used to deploy the `AimStakingEvm` contract.

1.  **Update the script**: The script currently deploys a `MockERC20` token for testing purposes. For a live deployment, you should update `scripts/deploy.ts` to use the address of your actual staking token.

2.  **Configure your network**: Open `hardhat.config.ts` and add a configuration for your target network (e.g., Base, Ethereum Mainnet, or a testnet). You will need an RPC URL and a private key for deployment.

    ```typescript
    // example network configuration in hardhat.config.ts
    // ...
    networks: {
      base_mainnet: {
        url: "YOUR_RPC_URL",
        accounts: ["YOUR_PRIVATE_KEY"],
      },
    },
    // ...
    ```

3.  **Run the deployment script**:

    ```bash
    npx hardhat run scripts/deploy.ts --network <your-network-name>
    ```

    For example, to deploy to the `base_mainnet` network configured above:
    ```bash
    npx hardhat run scripts/deploy.ts --network base_mainnet
    ```
    The script will deploy the contracts and perform the initial setup (registering a default project and adding staking durations).

## Smart Contracts

### `AimStakingEvm.sol`

This is the core contract that handles all staking logic. It is owned by an admin address that has exclusive rights to manage projects and staking options.

### `mocks/MockERC20.sol`

This is a simple ERC20 contract used for local testing and deployment simulation. It includes a `mint` function to create tokens for test accounts.
