import hre, { ethers } from "hardhat";

function sleep(s: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, s * 1000);
  })
}

async function main() {
  const constructorArgs: any[] = [
  ];
  const contractName = "AimStaking";
  const factory = await ethers.getContractFactory(`contracts/pool/${contractName}.sol`);
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployed();
  console.log(`${contractName} contract successfully deployed:`, contract.address);
  await sleep(20);
  await hre.run("verify:verify", {
    address: contract.address,
    contract: `contracts/pool/${contractName}.sol`,
    constructorArguments: constructorArgs
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
