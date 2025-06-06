// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AimStakingEvm is Ownable {
    IERC20 public immutable STAKING_TOKEN;

    enum StakeStatus { Active, Unstaked, EmergencyUnstaked }

    struct Stake {
        uint256 stakeId;
        address user;
        uint256 amount;
        bytes32 projectId;
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

    constructor(address stakingTokenAddress, address initialOwner) Ownable(initialOwner) {
        STAKING_TOKEN = IERC20(stakingTokenAddress);
    }

    function registerProject(bytes32 projectId) external onlyOwner {
        require(!registeredProjects[projectId], "Project already registered");
        registeredProjects[projectId] = true;
        emit ProjectRegistered(projectId);
    }

    function unregisterProject(bytes32 projectId) external onlyOwner {
        require(registeredProjects[projectId], "Project not registered");
        registeredProjects[projectId] = false;
        emit ProjectUnregistered(projectId);
    }

    function addDurationOption(uint256 durationInDays) external onlyOwner {
        require(durationInDays > 0, "Duration must be positive");
        require(!durationOptions[durationInDays], "Duration option already exists");
        durationOptions[durationInDays] = true;
        emit DurationOptionAdded(durationInDays);
    }

    function removeDurationOption(uint256 durationInDays) external onlyOwner {
        require(durationOptions[durationInDays], "Duration option not found");
        durationOptions[durationInDays] = false;
        emit DurationOptionRemoved(durationInDays);
    }

    function stake(uint256 amount, uint256 durationInDays, bytes32 projectId) external {
        require(amount > 0, "Amount must be > 0");
        require(durationOptions[durationInDays], "Invalid duration");
        require(registeredProjects[projectId], "Project not registered");

        STAKING_TOKEN.transferFrom(msg.sender, address(this), amount);

        uint256 stakeId = ++_stakeCounter;
        uint256 durationInSeconds = durationInDays * 1 days;
        uint256 unlockedAt = block.timestamp + durationInSeconds;

        stakes[stakeId] = Stake({
            stakeId: stakeId,
            user: msg.sender,
            amount: amount,
            projectId: projectId,
            stakedAt: block.timestamp,
            duration: durationInSeconds,
            unlockedAt: unlockedAt,
            status: StakeStatus.Active
        });

        userStakes[msg.sender].push(stakeId);
        projectStakes[projectId].push(stakeId);

        emit Staked(stakeId, msg.sender, amount, projectId, durationInSeconds);
    }

    function unstake(uint256 stakeId) external {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");
        require(block.timestamp >= userStake.unlockedAt, "Stake still locked");

        userStake.status = StakeStatus.Unstaked;
        STAKING_TOKEN.transfer(msg.sender, userStake.amount);

        emit Unstaked(stakeId, msg.sender, userStake.amount);
    }

    function emergencyUnstake(uint256 stakeId) external {
        Stake storage userStake = stakes[stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.status == StakeStatus.Active, "Stake not active");

        userStake.status = StakeStatus.EmergencyUnstaked;
        STAKING_TOKEN.transfer(msg.sender, userStake.amount);

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