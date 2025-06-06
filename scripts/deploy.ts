import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy MockERC20 token
  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const stakingToken = await MockERC20Factory.deploy("Test Token", "TST");
  await stakingToken.waitForDeployment();
  const stakingTokenAddress = await stakingToken.getAddress();
  console.log(`MockERC20 deployed to: ${stakingTokenAddress}`);

  // Deploy AimStakingEvm contract
  const AimStakingEvmFactory = await ethers.getContractFactory("AimStakingEvm");
  const aimStakingEvm = await AimStakingEvmFactory.deploy(stakingTokenAddress, deployer.address);
  await aimStakingEvm.waitForDeployment();
  const aimStakingEvmAddress = await aimStakingEvm.getAddress();
  console.log(`AimStakingEvm deployed to: ${aimStakingEvmAddress}`);
  
  // Initial setup
  console.log("Performing initial setup...");
  const PROJECT_ID = ethers.encodeBytes32String("test-project");
  await aimStakingEvm.registerProject(PROJECT_ID);
  console.log(`Registered project: ${ethers.decodeBytes32String(PROJECT_ID)}`);

  const durations = [7, 14, 30];
  for (const duration of durations) {
    await aimStakingEvm.addDurationOption(duration);
    console.log(`Added duration option: ${duration} days`);
  }
  
  console.log("Initial setup complete.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 