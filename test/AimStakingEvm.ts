import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { AimStakingEvm, MockERC20 } from "../typechain-types";

describe("AimStakingEvm", function () {
    const PROJECT_ID = ethers.encodeBytes32String("test-project");
    const DURATION_7_DAYS = 7;
    const DURATION_14_DAYS = 14;
    const DURATION_30_DAYS = 30;

    async function deployAimStakingEvmFixture() {
        const [owner, staker1, staker2] = await ethers.getSigners();

        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        const stakingToken = await MockERC20Factory.deploy("Test Token", "TST");
        await stakingToken.waitForDeployment();

        const AimStakingEvmFactory = await ethers.getContractFactory("AimStakingEvm");
        const aimStakingEvm = await AimStakingEvmFactory.deploy(await stakingToken.getAddress(), owner.address);
        await aimStakingEvm.waitForDeployment();

        // Mint some tokens to stakers
        await stakingToken.mint(staker1.address, ethers.parseEther("1000"));
        await stakingToken.mint(staker2.address, ethers.parseEther("1000"));

        // Register project and add duration options
        await aimStakingEvm.registerProject(PROJECT_ID);
        await aimStakingEvm.addDurationOption(DURATION_7_DAYS);
        await aimStakingEvm.addDurationOption(DURATION_14_DAYS);
        await aimStakingEvm.addDurationOption(DURATION_30_DAYS);

        return { aimStakingEvm, stakingToken, owner, staker1, staker2 };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { aimStakingEvm, owner } = await loadFixture(deployAimStakingEvmFixture);
            expect(await aimStakingEvm.owner()).to.equal(owner.address);
        });

        it("Should set the right staking token", async function () {
            const { aimStakingEvm, stakingToken } = await loadFixture(deployAimStakingEvmFixture);
            expect(await aimStakingEvm.STAKING_TOKEN()).to.equal(await stakingToken.getAddress());
        });
    });

    describe("Admin Functions", function () {
        it("Should allow owner to register a project", async function () {
            const { aimStakingEvm } = await loadFixture(deployAimStakingEvmFixture);
            const newProjectId = ethers.encodeBytes32String("new-project");
            await aimStakingEvm.registerProject(newProjectId);
            expect(await aimStakingEvm.registeredProjects(newProjectId)).to.be.true;
        });

        it("Should allow owner to add a duration option", async function () {
            const { aimStakingEvm } = await loadFixture(deployAimStakingEvmFixture);
            const newDuration = 60;
            await aimStakingEvm.addDurationOption(newDuration);
            expect(await aimStakingEvm.durationOptions(newDuration)).to.be.true;
        });
    });

    describe("Staking", function () {
        it("Should allow a user to stake tokens", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            await aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID);

            const stake = await aimStakingEvm.stakes(1);
            expect(stake.amount).to.equal(stakeAmount);
            expect(stake.user).to.equal(staker1.address);
            expect(await stakingToken.balanceOf(await aimStakingEvm.getAddress())).to.equal(stakeAmount);
        });

        it("Should emit a Staked event", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            
            await expect(aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID))
                .to.emit(aimStakingEvm, "Staked")
                .withArgs(1, staker1.address, stakeAmount, PROJECT_ID, DURATION_7_DAYS * 24 * 60 * 60);
        });
    });

    describe("Unstaking", function () {
        it("Should allow a user to unstake after the lock period", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            await aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID);
            
            await time.increase(DURATION_7_DAYS * 24 * 60 * 60);

            const initialBalance = await stakingToken.balanceOf(staker1.address);
            await aimStakingEvm.connect(staker1).unstake(1);
            const finalBalance = await stakingToken.balanceOf(staker1.address);

            const stake = await aimStakingEvm.stakes(1);
            expect(stake.status).to.equal(1); // Unstaked
            expect(finalBalance).to.be.gt(initialBalance);
        });

        it("Should prevent unstaking before the lock period ends", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            await aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID);
            
            await expect(aimStakingEvm.connect(staker1).unstake(1)).to.be.revertedWith("Stake still locked");
        });
    });

    describe("Emergency Unstake", function () {
        it("Should allow a user to emergency unstake", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            await aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID);

            const initialBalance = await stakingToken.balanceOf(staker1.address);
            await aimStakingEvm.connect(staker1).emergencyUnstake(1);
            const finalBalance = await stakingToken.balanceOf(staker1.address);

            const stake = await aimStakingEvm.stakes(1);
            expect(stake.status).to.equal(2); // EmergencyUnstaked
            expect(finalBalance).to.be.gt(initialBalance);
        });

        it("Should emit an EmergencyUnstaked event", async function () {
            const { aimStakingEvm, stakingToken, staker1 } = await loadFixture(deployAimStakingEvmFixture);
            const stakeAmount = ethers.parseEther("100");

            await stakingToken.connect(staker1).approve(await aimStakingEvm.getAddress(), stakeAmount);
            await aimStakingEvm.connect(staker1).stake(stakeAmount, DURATION_7_DAYS, PROJECT_ID);

            await expect(aimStakingEvm.connect(staker1).emergencyUnstake(1))
                .to.emit(aimStakingEvm, "EmergencyUnstaked")
                .withArgs(1, staker1.address, stakeAmount);
        });
    });
}); 