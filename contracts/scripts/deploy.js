const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying HestiaAnchor contract...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  const HestiaAnchor = await ethers.getContractFactory("HestiaAnchor");
  const contract = await HestiaAnchor.deploy();

  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log("\n========================================");
  console.log("HestiaAnchor deployed successfully!");
  console.log("Contract address:", address);
  console.log("========================================\n");

  console.log("Add this to your configuration:");
  console.log(`HESTIA_CONTRACT_ADDRESS=${address}`);

  // Test the contract
  console.log("\nTesting contract...");
  
  const testHash = ethers.keccak256(ethers.toUtf8Bytes("test anchor"));
  const tx = await contract.recordAnchor(testHash, "test");
  await tx.wait();
  
  const [exists, timestamp, anchorType, recorder] = await contract.verifyAnchor(testHash);
  console.log("Test anchor recorded:", { exists, timestamp: timestamp.toString(), anchorType, recorder });

  console.log("\nDeployment complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
