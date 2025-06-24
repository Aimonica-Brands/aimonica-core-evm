// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../pool/AimStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MaliciousReentrancy
 * @dev A contract that attempts to perform reentrancy attacks on AimStaking
 */
contract MaliciousReentrancy {
    AimStaking public aimStaking;
    IERC20 public stakingToken;
    uint256 public stakeId;
    bool public attacking = false;

    constructor(address _aimStaking, address _stakingToken) {
        aimStaking = AimStaking(_aimStaking);
        stakingToken = IERC20(_stakingToken);
    }



    function stakeTokens(uint256 amount, uint256 duration, bytes32 projectId) external {
        stakingToken.approve(address(aimStaking), amount);
        aimStaking.stake(amount, duration, projectId);
        stakeId = 1; // Assume this is the first stake
    }

    function attackUnstake() external {
        attacking = true;
        try aimStaking.unstake(stakeId) {
            // Normal unstake should work
        } catch {
            // If it fails, check why
        }
        attacking = false;
    }

    function attackEmergencyUnstake() external {
        attacking = true;
        try aimStaking.emergencyUnstake(stakeId) {
            // Normal emergency unstake should work
        } catch {
            // If it fails, check why
        }
        attacking = false;
    }

    // Fallback function that might be called during token transfers
    receive() external payable {
        if (attacking) {
            _onTokenReceived();
        }
    }

    function _onTokenReceived() internal {
        if (attacking && stakeId > 0) {
            // Try to reenter the unstake function
            try aimStaking.unstake(stakeId) {
                // If this succeeds, reentrancy guard failed
            } catch {
                // Expected - reentrancy guard should prevent this
            }
        }
    }
} 