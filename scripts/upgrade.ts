// Import required modules from Hardhat and ethers
import { ethers, upgrades } from "hardhat";

/**
 * Main function to deploy and verify the contract
 */
async function main() {
  // Set the name of the contract to be deployed
  const contractName = "AimStaking";

  // Get the contract factory
  const factory = await ethers.getContractFactory(contractName);

  // Upgrade the contract
  await upgrades.upgradeProxy('=====Deployed Proxy Address=====', factory);
  console.log("contract upgraded");
}

// Execute the main function
main()
  .then(() => process.exit(0))  // Exit with success code if everything went well
  .catch((error) => {
    console.error(error);  // Log any errors
    process.exit(1);  // Exit with error code if something went wrong
  });
