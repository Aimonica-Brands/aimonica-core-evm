// Import required modules from Hardhat and ethers
import hre, { ethers, upgrades } from "hardhat";

/**
 * Main function to deploy and verify the contract
 */
async function main() {
  // Set the name of the contract to be deployed
  const contractName = "AimStaking";

  // Verify the contract on Etherscan
  await hre.run("verify:verify", {
    address: '=====Implementation Contract Address=====',
    contract: `contracts/pool/${contractName}.sol:${contractName}`,
    constructorArguments: [],
  });
}

// Execute the main function
main()
  .then(() => process.exit(0))  // Exit with success code if everything went well
  .catch((error) => {
    console.error(error);  // Log any errors
    process.exit(1);  // Exit with error code if something went wrong
  });
