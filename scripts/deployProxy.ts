// Import required modules from Hardhat and ethers
import { ethers, upgrades } from "hardhat";

/**
 * Main function to deploy and verify the contract
 */
async function main() {
  // Define initialize arguments for the contract
  const initializeArgs: any[] = [
    "=====Admin Address====="
  ];

  // Set the name of the contract to be deployed
  const contractName = "AimStaking";

  // Get the contract factory
  const factory = await ethers.getContractFactory(contractName);

  // Deploy the contract with constructor arguments
  const contract = await upgrades.deployProxy(factory, initializeArgs, { initializer: "initialize" });

  // Wait for the contract to be deployed
  await contract.deployed();

  // Log the deployed contract address
  console.log(`${contractName} contract successfully deployed:`, contract.address);
}

// Execute the main function
main()
  .then(() => process.exit(0))  // Exit with success code if everything went well
  .catch((error) => {
    console.error(error);  // Log any errors
    process.exit(1);  // Exit with error code if something went wrong
  });
