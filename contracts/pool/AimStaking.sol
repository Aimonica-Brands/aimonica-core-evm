// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20.sol";

contract AimStaking is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public feeWallet;
    uint256 public unstakeFeeRate; // in basis points, e.g., 100 = 1%
    uint256 public emergencyUnstakeFeeRate; // in basis points, e.g., 100 = 1%

    mapping(bytes32 => address) public projectStakingTokens;

    enum StakeStatus { Active, Unstaked, EmergencyUnstaked }

    struct Stake {
        uint256 stakeId;
        address user;
        uint256 amount;
        bytes32 projectId;
        address stakingToken;
        uint256 stakedAt;
        uint256 duration; // in seconds
        uint256 unlockedAt;
        StakeStatus status;
    }

    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) private userStakes;
    mapping(bytes32 => uint256[]) private projectStakes;
    mapping(bytes32 => bool) public registeredProjects;
    mapping(uint256 => bool) public durationOptions; // duration in days

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

    function initialize(address admin) external initializer {
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
        feeWallet = admin;
    }

    function setFeeWallet(address _feeWallet) external onlyRole(MANAGER_ROLE) {
        require(_feeWallet != address(0), "Invalid fee wallet address");
        feeWallet = _feeWallet;
        emit FeeWalletSet(_feeWallet);
    }

    function setUnstakeFeeRate(uint256 _unstakeFeeRate) external onlyRole(MANAGER_ROLE) {
        require(_unstakeFeeRate <= 10000, "Fee rate cannot exceed 100%");
        unstakeFeeRate = _unstakeFeeRate;
        emit UnstakeFeeRateSet(_unstakeFeeRate);
    }

    function setEmergencyUnstakeFeeRate(uint256 _emergencyUnstakeFeeRate) external onlyRole(MANAGER_ROLE) {
        require(_emergencyUnstakeFeeRate <= 10000, "Fee rate cannot exceed 100%");
        emergencyUnstakeFeeRate = _emergencyUnstakeFeeRate;
        emit EmergencyUnstakeFeeRateSet(_emergencyUnstakeFeeRate);
    }

    function setProjectStakingToken(bytes32 projectId, address stakingTokenAddress) external onlyRole(MANAGER_ROLE) {
        require(registeredProjects[projectId], "Project not registered");
        require(stakingTokenAddress != address(0), "AimStaking: Invalid staking token address");
        projectStakingTokens[projectId] = stakingTokenAddress;
        emit ProjectStakingTokenSet(projectId, stakingTokenAddress);
    }

    function registerProject(bytes32 projectId) external onlyRole(MANAGER_ROLE) {
        require(!registeredProjects[projectId], "Project already registered");
        registeredProjects[projectId] = true;
        emit ProjectRegistered(projectId);
    }

    function unregisterProject(bytes32 projectId) external onlyRole(MANAGER_ROLE) {
        require(registeredProjects[projectId], "Project not registered");
        registeredProjects[projectId] = false;
        emit ProjectUnregistered(projectId);
    }

    function addDurationOption(uint256 durationInDays) external onlyRole(MANAGER_ROLE) {
        require(durationInDays > 0, "Duration must be positive");
        require(!durationOptions[durationInDays], "Duration option already exists");
        durationOptions[durationInDays] = true;
        emit DurationOptionAdded(durationInDays);
    }

    function removeDurationOption(uint256 durationInDays) external onlyRole(MANAGER_ROLE) {
        require(durationOptions[durationInDays], "Duration option not found");
        durationOptions[durationInDays] = false;
        emit DurationOptionRemoved(durationInDays);
    }

    function stake(uint256 amount, uint256 durationInDays, bytes32 projectId) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(durationOptions[durationInDays], "Invalid duration");
        require(registeredProjects[projectId], "Project not registered");
        address stakingTokenAddress = projectStakingTokens[projectId];
        require(stakingTokenAddress != address(0), "Staking token not set for project");

        IERC20(stakingTokenAddress).transferFrom(msg.sender, address(this), amount);

        uint256 stakeId = ++_stakeCounter;
        uint256 durationInSeconds = durationInDays * 1 days;
        uint256 unlockedAt = block.timestamp + durationInSeconds;

        stakes[stakeId] = Stake({
            stakeId: stakeId,
            user: msg.sender,
            amount: amount,
            projectId: projectId,
            stakingToken: stakingTokenAddress,
            stakedAt: block.timestamp,
            duration: durationInSeconds,
            unlockedAt: unlockedAt,
            status: StakeStatus.Active
        });

        userStakes[msg.sender].push(stakeId);
        projectStakes[projectId].push(stakeId);

        emit Staked(stakeId, msg.sender, amount, projectId, durationInSeconds);
    }

    function unstake(uint256 stakeId) external nonReentrant {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");
        require(block.timestamp >= userStake.unlockedAt, "Stake still locked");

        userStake.status = StakeStatus.Unstaked;

        uint256 amountToUnstake = userStake.amount;
        if (unstakeFeeRate > 0 && feeWallet != address(0)) {
            uint256 fee = (amountToUnstake * unstakeFeeRate) / 10000;
            if (fee > 0) {
                IERC20(userStake.stakingToken).transfer(feeWallet, fee);
            }
            amountToUnstake -= fee;
        }

        IERC20(userStake.stakingToken).transfer(msg.sender, amountToUnstake);

        emit Unstaked(stakeId, msg.sender, userStake.amount);
    }

    function emergencyUnstake(uint256 stakeId) external nonReentrant {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");

        userStake.status = StakeStatus.EmergencyUnstaked;

        uint256 amountToUnstake = userStake.amount;
        if (emergencyUnstakeFeeRate > 0 && feeWallet != address(0)) {
            uint256 fee = (amountToUnstake * emergencyUnstakeFeeRate) / 10000;
            if (fee > 0) {
                IERC20(userStake.stakingToken).transfer(feeWallet, fee);
            }
            amountToUnstake -= fee;
        }

        IERC20(userStake.stakingToken).transfer(msg.sender, amountToUnstake);

        emit EmergencyUnstaked(stakeId, msg.sender, userStake.amount);
    }

    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakes[user];
    }
    
    function getProjectStakes(bytes32 projectId) external view returns (uint256[] memory) {
        return projectStakes[projectId];
    }

    function getActiveUserStakes(address user) external view returns (uint256[] memory) {
        uint256[] memory allStakes = userStakes[user];
        uint256 activeCount = 0;
        for (uint i = 0; i < allStakes.length; i++) {
            if (stakes[allStakes[i]].status == StakeStatus.Active) {
                activeCount++;
            }
        }

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
} 