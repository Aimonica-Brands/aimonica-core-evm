// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20.sol";

/**
 * @title AimStaking
 * @dev A contract for staking ERC20 tokens for different projects with various lock-up durations.
 * It allows project managers to define staking parameters and collect fees.
 * This contract is upgradeable.
 */
contract AimStaking is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @dev Role identifier for managers who can configure staking parameters.
     */
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /**
     * @dev The wallet address where collected fees are sent.
     */
    address public feeWallet;
    /**
     * @dev The fee rate for regular unstaking, in basis points (1/10000). E.g., 100 means 1%.
     */
    uint256 public unstakeFeeRate; // in basis points, e.g., 100 = 1%
    /**
     * @dev The fee rate for emergency unstaking, in basis points. E.g., 500 means 5%.
     */
    uint256 public emergencyUnstakeFeeRate; // in basis points, e.g., 100 = 1%

    /**
     * @dev Mapping from a project ID to its designated staking token address.
     */
    mapping(bytes32 => address) public projectStakingTokens;

    /**
     * @dev The possible statuses of a stake.
     */
    enum StakeStatus { Active, Unstaked, EmergencyUnstaked }

    /**
     * @dev Represents a single stake instance.
     */
    struct Stake {
        uint256 stakeId;      // Unique identifier for the stake.
        address user;         // The address of the staker.
        uint256 amount;       // The amount of tokens staked.
        bytes32 projectId;    // The project for which the tokens are staked.
        address stakingToken; // The address of the staked ERC20 token.
        uint256 stakedAt;     // Timestamp of when the stake was created.
        uint256 duration;     // The lock-up duration in seconds.
        uint256 unlockedAt;   // Timestamp when the stake becomes unlockable.
        StakeStatus status;   // The current status of the stake.
    }

    /**
     * @dev Mapping from a stake ID to the Stake struct.
     */
    mapping(uint256 => Stake) public stakes;
    /**
     * @dev Mapping from a user's address to an array of their stake IDs.
     */
    mapping(address => uint256[]) private userStakes;
    /**
     * @dev Mapping from a project ID to an array of its associated stake IDs.
     */
    mapping(bytes32 => uint256[]) private projectStakes;
    /**
     * @dev Mapping to track registered projects. Only registered projects can be staked into.
     */
    mapping(bytes32 => bool) public registeredProjects;
    /**
     * @dev Mapping to store valid staking duration options in days.
     */
    mapping(uint256 => bool) public durationOptions; // duration in days

    /**
     * @dev A counter to generate unique stake IDs.
     */
    uint256 private _stakeCounter;

    event ProjectRegistered(bytes32 projectId);
    event ProjectUnregistered(bytes32 projectId);
    event DurationOptionAdded(uint256 duration);
    event DurationOptionRemoved(uint256 duration);
    event Staked(
        uint256 stakeId,
        address indexed user,
        uint256 amount,
        bytes32 indexed projectId,
        uint256 duration
    );
    event Unstaked(uint256 stakeId, address indexed user, uint256 amount);
    event EmergencyUnstaked(uint256 stakeId, address indexed user, uint256 amount);
    event ProjectStakingTokenSet(bytes32 indexed projectId, address tokenAddress);

    event FeeWalletSet(address indexed newWallet);
    event UnstakeFeeRateSet(uint256 newRate);
    event EmergencyUnstakeFeeRateSet(uint256 newRate);

    /**
     * @dev Initializes the contract, setting the admin role.
     * @param admin The address to be granted the default admin and manager roles.
     */
    function initialize(address admin) external initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
        feeWallet = admin;
    }

    /**
     * @dev Sets the wallet address for collecting fees.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param _feeWallet The new fee wallet address.
     */
    function setFeeWallet(address _feeWallet) external onlyRole(MANAGER_ROLE) {
        require(_feeWallet != address(0), "Invalid fee wallet address");
        feeWallet = _feeWallet;
        emit FeeWalletSet(_feeWallet);
    }

    /**
     * @dev Sets the fee rate for regular unstaking.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param _unstakeFeeRate The new unstake fee rate in basis points.
     */
    function setUnstakeFeeRate(uint256 _unstakeFeeRate) external onlyRole(MANAGER_ROLE) {
        require(_unstakeFeeRate <= 10000, "Fee rate cannot exceed 100%");
        unstakeFeeRate = _unstakeFeeRate;
        emit UnstakeFeeRateSet(_unstakeFeeRate);
    }

    /**
     * @dev Sets the fee rate for emergency unstaking.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param _emergencyUnstakeFeeRate The new emergency unstake fee rate in basis points.
     */
    function setEmergencyUnstakeFeeRate(uint256 _emergencyUnstakeFeeRate) external onlyRole(MANAGER_ROLE) {
        require(_emergencyUnstakeFeeRate <= 10000, "Fee rate cannot exceed 100%");
        emergencyUnstakeFeeRate = _emergencyUnstakeFeeRate;
        emit EmergencyUnstakeFeeRateSet(_emergencyUnstakeFeeRate);
    }

    /**
     * @dev Sets the staking token for a specific project.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param projectId The ID of the project.
     * @param stakingTokenAddress The address of the ERC20 token for staking.
     */
    function setProjectStakingToken(bytes32 projectId, address stakingTokenAddress) external onlyRole(MANAGER_ROLE) {
        require(registeredProjects[projectId], "Project not registered");
        require(stakingTokenAddress != address(0), "AimStaking: Invalid staking token address");
        projectStakingTokens[projectId] = stakingTokenAddress;
        emit ProjectStakingTokenSet(projectId, stakingTokenAddress);
    }

    /**
     * @dev Registers a new project and sets its staking token.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param projectId The ID of the project to register.
     * @param stakingTokenAddress The address of the ERC20 token for staking.
     */
    function registerProject(bytes32 projectId, address stakingTokenAddress) external onlyRole(MANAGER_ROLE) {
        require(!registeredProjects[projectId], "Project already registered");
        require(stakingTokenAddress != address(0), "AimStaking: Invalid staking token address");
        registeredProjects[projectId] = true;
        projectStakingTokens[projectId] = stakingTokenAddress;
        emit ProjectRegistered(projectId);
        emit ProjectStakingTokenSet(projectId, stakingTokenAddress);
    }

    /**
     * @dev Unregisters an existing project.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param projectId The ID of the project to unregister.
     */
    function unregisterProject(bytes32 projectId) external onlyRole(MANAGER_ROLE) {
        require(registeredProjects[projectId], "Project not registered");
        registeredProjects[projectId] = false;
        delete projectStakingTokens[projectId];
        emit ProjectUnregistered(projectId);
    }

    /**
     * @dev Adds a new valid staking duration option.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param durationInDays The new duration in days.
     */
    function addDurationOption(uint256 durationInDays) external onlyRole(MANAGER_ROLE) {
        require(durationInDays > 0, "Duration must be positive");
        require(!durationOptions[durationInDays], "Duration option already exists");
        durationOptions[durationInDays] = true;
        emit DurationOptionAdded(durationInDays);
    }

    /**
     * @dev Removes an existing staking duration option.
     * Can only be called by an address with the MANAGER_ROLE.
     * @param durationInDays The duration in days to remove.
     */
    function removeDurationOption(uint256 durationInDays) external onlyRole(MANAGER_ROLE) {
        require(durationOptions[durationInDays], "Duration option not found");
        durationOptions[durationInDays] = false;
        emit DurationOptionRemoved(durationInDays);
    }

    /**
     * @dev Stakes a specified amount of tokens for a given project and duration.
     * @param amount The amount of tokens to stake.
     * @param durationInDays The staking duration in days.
     * @param projectId The ID of the project to stake for.
     */
    function stake(uint256 amount, uint256 durationInDays, bytes32 projectId) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(durationOptions[durationInDays], "Invalid duration");
        require(registeredProjects[projectId], "Project not registered");
        address stakingTokenAddress = projectStakingTokens[projectId];
        require(stakingTokenAddress != address(0), "Staking token not set for project");

        // Transfer tokens from the user to this contract
        uint256 beforeBalance = IERC20(stakingTokenAddress).balanceOf(address(this));
        IERC20(stakingTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        uint256 actualReceived = IERC20(stakingTokenAddress).balanceOf(address(this)) - beforeBalance;

        // Create and store the new stake
        uint256 stakeId = ++_stakeCounter;
        uint256 durationInSeconds = durationInDays * 1 days;
        uint256 unlockedAt = block.timestamp + durationInSeconds;

        stakes[stakeId] = Stake({
            stakeId: stakeId,
            user: msg.sender,
            amount: actualReceived,
            projectId: projectId,
            stakingToken: stakingTokenAddress,
            stakedAt: block.timestamp,
            duration: durationInSeconds,
            unlockedAt: unlockedAt,
            status: StakeStatus.Active
        });

        // Track the stake for the user and the project
        userStakes[msg.sender].push(stakeId);
        projectStakes[projectId].push(stakeId);

        emit Staked(stakeId, msg.sender, actualReceived, projectId, durationInSeconds);
    }

    /**
     * @dev Unstakes tokens after the lock-up period has passed.
     * A fee may be applied.
     * @param stakeId The ID of the stake to unstake.
     */
    function unstake(uint256 stakeId) external nonReentrant {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");
        require(block.timestamp >= userStake.unlockedAt, "Stake still locked");

        userStake.status = StakeStatus.Unstaked;

        uint256 amountToUnstake = userStake.amount;
        // Apply unstake fee if applicable
        if (unstakeFeeRate > 0 && feeWallet != address(0)) {
            uint256 fee = (amountToUnstake * unstakeFeeRate) / 10000;
            if (fee > 0) {
                IERC20(userStake.stakingToken).safeTransfer(feeWallet, fee);
            }
            amountToUnstake -= fee;
        }

        // Transfer the remaining amount back to the user
        IERC20(userStake.stakingToken).safeTransfer(msg.sender, amountToUnstake);

        emit Unstaked(stakeId, msg.sender, userStake.amount);
    }

    /**
     * @dev Allows a user to unstake their tokens before the lock-up period ends.
     * A higher fee is applied for this action.
     * @param stakeId The ID of the stake to unstake.
     */
    function emergencyUnstake(uint256 stakeId) external nonReentrant {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");
        require(block.timestamp < userStake.unlockedAt, "Lockup period ended, use regular unstake");

        userStake.status = StakeStatus.EmergencyUnstaked;

        uint256 amountToUnstake = userStake.amount;
        // Apply emergency unstake fee if applicable
        if (emergencyUnstakeFeeRate > 0 && feeWallet != address(0)) {
            uint256 fee = (amountToUnstake * emergencyUnstakeFeeRate) / 10000;
            if (fee > 0) {
                IERC20(userStake.stakingToken).safeTransfer(feeWallet, fee);
            }
            amountToUnstake -= fee;
        }

        // Transfer the remaining amount back to the user
        IERC20(userStake.stakingToken).safeTransfer(msg.sender, amountToUnstake);

        emit EmergencyUnstaked(stakeId, msg.sender, userStake.amount);
    }

    /**
     * @dev Retrieves all stake IDs for a given user.
     * @param user The address of the user.
     * @return An array of stake IDs.
     */
    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakes[user];
    }
    
    /**
     * @dev Retrieves all stake IDs for a given project.
     * @param projectId The ID of the project.
     * @return An array of stake IDs.
     */
    function getProjectStakes(bytes32 projectId) external view returns (uint256[] memory) {
        return projectStakes[projectId];
    }

    /**
     * @dev Retrieves all active stake IDs for a given user.
     * This function is useful for UIs to display current user stakes.
     * @param user The address of the user.
     * @return An array of active stake IDs.
     */
    function getActiveUserStakes(address user) external view returns (uint256[] memory) {
        uint256[] memory allStakes = userStakes[user];
        uint256 activeCount = 0;
        // First, count the number of active stakes to initialize the array with the correct size.
        for (uint i = 0; i < allStakes.length; i++) {
            if (stakes[allStakes[i]].status == StakeStatus.Active) {
                activeCount++;
            }
        }

        // Populate the new array with active stake IDs.
        uint256[] memory activeStakes = new uint256[](activeCount);
        uint256 index = 0;
        for (uint i = 0; i < allStakes.length; i++) {
            if (stakes[allStakes[i]].status == StakeStatus.Active) {
                activeStakes[index] = allStakes[i];
                index++;
            }
        }
        return activeStakes;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap; // Storage gap for future upgrades
} 