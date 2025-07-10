# Internal Audit Tech Spec: AimStaking Contract

## Changelog

- **Version 1.0.1 (2025-06-22)**: Initial version of the staking contract.

## Project outline

This project provides a generalized, upgradeable ERC20 token staking contract named `AimStaking`. It is designed to allow multiple "projects" to have their own staking pools with distinct staking tokens. Users can stake tokens for a chosen duration to support a project and earn potential (off-chain) rewards. The contract includes features for regular and emergency unstaking, with configurable fees for each.

## Blockchain features and solution design

-   **Blockchain:** The contract is designed for EVM-compatible blockchains. The project configuration specifies deployments to **Base Mainnet** and **Base Sepolia** testnet.
-   **On-chain Interactions:**
    -   All interactions are on-chain transactions with the `AimStaking` smart contract.
    -   Users' wallets are external (e.g., MetaMask). Users directly interact with the contract to stake, unstake, and emergency unstake tokens.
    -   The contract interacts with various ERC20 token contracts, which are specified on a per-project basis by a contract manager.
-   **Cross-chain:** There is no native cross-chain functionality involved in the current design.

## Scope

The scope of this audit covers all write and security-relevant read operations of the `AimStaking.sol` smart contract.

**Write Operations / Signed Transactions:**

-   **User Actions:**
    -   `stake(amount, durationInDays, projectId)`: A user signs a transaction to approve the contract as a spender for their ERC20 tokens, then calls `stake` to transfer tokens into the contract.
    -   `unstake(stakeId)`: A user signs a transaction to withdraw their tokens after the lock-up period.
    -   `emergencyUnstake(stakeId)`: A user signs a transaction to withdraw their tokens before the lock-up period ends, incurring a higher fee.
-   **Privileged Actions (Manager Role):**
    -   `setFeeWallet(address)`
    -   `setUnstakeFeeRate(rate)`
    -   `setEmergencyUnstakeFeeRate(rate)`
    -   `setProjectStakingToken(projectId, tokenAddress)`
    -   `registerProject(projectId)`
    -   `unregisterProject(projectId)`
    -   `addDurationOption(durationInDays)`
    -   `removeDurationOption(durationInDays)`
-   **Privileged Actions (Admin Role):**
    -   `grantRole(role, account)`
    -   `revokeRole(role, account)`
    -   `renounceRole(role, account)`
    -   Contract upgrades (performed by the deployer account, which should be the admin).

**Contract upgrades (performed by the deployer account, which should be the admin).**

-   upgrade(proxyAddress, newImplementationAddress): This function is called on the ProxyAdmin contract to point the proxy to a new logic contract address. The scripts/upgrade.ts script in your project likely encapsulates this operation.
-   changeProxyAdmin(proxyAddress, newAdminAddress): Transfers the administrative control of a specific proxy contract to a new ProxyAdmin contract or address.
-   transferOwnership(newOwner): Transfers the ownership of the ProxyAdmin contract itself.

**Security-Relevant Read Operations:**

-   `stakes(stakeId)`: Reading details of a specific stake.
-   `getUserStakes(user)`: Reading all stake IDs for a user.
-   `getActiveUserStakes(user)`: Reading active stakes, which could be used by a UI to determine user actions.

## Smart contracts design

The solution consists of a single primary contract, `AimStaking`.

-   **Contract Name:** `AimStaking.sol`
-   **Solidity Version:** `0.8.21`
-   **External Dependencies:**
    -   `@openzeppelin/contracts-upgradeable`: For `AccessControlEnumerableUpgradeable` (role-based access control), `ReentrancyGuardUpgradeable` (security), and `Initializable` (for upgradeable constructor logic).
    -   `@animoca/ethereum-contracts`: For the `IERC20` interface.
-   **Design:**
    -   The contract is **upgradeable** using the UUPS proxy pattern via OpenZeppelin's Hardhat Upgrades plugin.
    -   It serves as a vault for various ERC20 tokens staked by users.
    -   It uses a `struct Stake` to track individual stake details, including user, amount, project, and lock-up duration.
    -   It uses `AccessControl` for managing permissions.

-   **Privileged Roles:**
    -   **`DEFAULT_ADMIN_ROLE`**: This is the highest authority. This role can manage other roles (grant/revoke) and is the only one that can authorize contract upgrades.
        -   **Holder(s):** A single external account (EOA) or a Multi-Sig wallet, specified during deployment.
        -   **Capabilities:** Grant/revoke any role, perform contract upgrades.
    -   **`MANAGER_ROLE`**: This role is responsible for the operational management of the staking contract.
        -   **Holder(s):** Initially granted to the same address as the `DEFAULT_ADMIN_ROLE`. The admin can grant this role to other addresses.
        -   **Capabilities:**
            -   Set the fee-collecting wallet address.
            -   Set the regular and emergency unstake fee rates.
            -   Register/unregister projects.
            -   Define the specific ERC20 token for each project.
            -   Add/remove valid staking durations.
-   **Standards Followed:**
    -   Interacts with tokens that follow the **ERC20** standard.

## Migrations design

-   **Deployment:** The contract is deployed using a proxy pattern. The `scripts/deployProxy.ts` script handles the deployment.
-   **Initialization:** The `initialize(address admin)` function is called once upon initial deployment. It sets the `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE` to the provided `admin` address.
-   **Upgrades:** Upgrades are performed using the `scripts/upgrade.ts` script and the OpenZeppelin Hardhat Upgrades plugin. This allows for modifying the contract logic without changing the contract address or losing state.

## Backend design

There is no backend component within this project's scope. All logic is self-contained within the smart contract. A backend service could potentially be used to monitor contract events for analytics, but it is not part of this repository.

## Frontend design

There is no frontend component within this project's scope. Users are expected to interact with the smart contract via a compatible Web3 frontend (e.g., a custom dApp, or directly through block explorers like Basescan) that connects to their wallet (e.g., MetaMask).

## Roles

*This section duplicates information from "Smart contracts design" but is kept for structural compliance with the template.*

-   **`DEFAULT_ADMIN_ROLE`**: The ultimate controller of the contract, responsible for assigning roles and executing upgrades.
-   **`MANAGER_ROLE`**: Manages the day-to-day operational parameters of the staking pools.

---

## Wallets

### Company-Managed Wallets

| Wallet Name              | Type                      | Access List                               | Security Measures                                                                                               |
| ------------------------ | ------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Contract Deployer/Admin**  | Multi-Sig | Project's core technical/security team. | **MUST** be a hardware wallet or a Gnosis Safe Multi-Sig (e.g., 2-of-3 signature scheme) to prevent a single point of failure. |
| **Manager Wallet**       | Multi-Sig | Project's operational team.           | Should be a Multi-Sig for any significant operations. Can be a separate, less-privileged wallet than the Admin.      |
| **Fee Wallet**           | Multi-Sig | Project's finance/treasury team.      | **MUST** be a secure, audited Multi-Sig wallet. Access should be strictly controlled.                       |

### Supported User Wallets

The contract is compatible with any standard EVM wallet that supports the ERC20 token standard and can connect to a dApp via common providers. This includes but is not limited to:

-   MetaMask
-   WalletConnect-compatible wallets (e.g., Trust Wallet, Rainbow Wallet)
-   Hardware wallets used with a browser extension (e.g., Ledger, Trezor)

## Deployment Flow

The deployment process is scripted and managed via Hardhat.

1.  **Preparation:**
    -   Configure the `.env` file with the `PRIVATE_KEY` of the deployer wallet and the `ETHERSCAN_API_KEY` for the target network (e.g., `base` or `base-sepolia`).
    -   Update the placeholder `"=====Admin Address====="` in `scripts/deployProxy.ts` with the actual address for the contract admin (ideally a Multi-Sig).

2.  **Execution:**
    -   Run the deployment command for the desired network:
        -   **Testnet (Base Sepolia):** `npm run deploy-proxy-testnet`
        -   **Mainnet (Base):** `npm run deploy-proxy`

3.  **Process:**
    -   The script compiles the contracts.
    -   It deploys an instance of the `AimStaking` logic contract.
    -   It deploys a `TransparentUpgradeableProxy` contract, linking it to the logic contract.
    -   It calls the `initialize(admin)` function on the proxy, setting the initial roles.
    -   The address of the proxy is logged, which is the public-facing address for the staking contract.

4.  **Verification (Optional but Recommended):**
    -   After deployment, the `verify` scripts can be run to publish the source code to Basescan, linking it to the proxy address.
      - **Testnet:** `npm run verify-testnet`
      - **Mainnet:** `npm run verify` 