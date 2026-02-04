const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HestiaAnchor", function () {
  let hestiaAnchor;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const HestiaAnchor = await ethers.getContractFactory("HestiaAnchor");
    hestiaAnchor = await HestiaAnchor.deploy();
    await hestiaAnchor.waitForDeployment();
  });

  describe("recordAnchor", function () {
    it("Should record a new anchor", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
      const anchorType = "meeting";

      await expect(hestiaAnchor.recordAnchor(anchorHash, anchorType))
        .to.emit(hestiaAnchor, "AnchorRecorded")
        .withArgs(anchorHash, anchorType, anyValue, owner.address);

      expect(await hestiaAnchor.exists(anchorHash)).to.be.true;
    });

    it("Should return false for duplicate anchor", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
      
      await hestiaAnchor.recordAnchor(anchorHash, "meeting");
      
      // Second call should return false but not revert
      const tx = await hestiaAnchor.recordAnchor(anchorHash, "meeting");
      const receipt = await tx.wait();
      
      // Should not emit event for duplicate
      const events = receipt.logs.filter(
        log => log.fragment?.name === "AnchorRecorded"
      );
      expect(events.length).to.equal(0);
    });

    it("Should store correct anchor details", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
      const anchorType = "genomics";

      await hestiaAnchor.recordAnchor(anchorHash, anchorType);

      const [exists, timestamp, type, recorder] = await hestiaAnchor.verifyAnchor(anchorHash);

      expect(exists).to.be.true;
      expect(timestamp).to.be.gt(0);
      expect(type).to.equal(anchorType);
      expect(recorder).to.equal(owner.address);
    });
  });

  describe("recordAnchorStrict", function () {
    it("Should revert for duplicate anchor", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
      
      await hestiaAnchor.recordAnchorStrict(anchorHash, "meeting");
      
      await expect(
        hestiaAnchor.recordAnchorStrict(anchorHash, "meeting")
      ).to.be.revertedWith("HestiaAnchor: anchor already exists");
    });
  });

  describe("recordAnchors (batch)", function () {
    it("Should record multiple anchors", async function () {
      const hashes = [
        ethers.keccak256(ethers.toUtf8Bytes("data1")),
        ethers.keccak256(ethers.toUtf8Bytes("data2")),
        ethers.keccak256(ethers.toUtf8Bytes("data3"))
      ];
      const types = ["meeting", "genomics", "research"];

      await expect(hestiaAnchor.recordAnchors(hashes, types))
        .to.emit(hestiaAnchor, "BatchRecorded")
        .withArgs(3, owner.address);

      for (const hash of hashes) {
        expect(await hestiaAnchor.exists(hash)).to.be.true;
      }
    });

    it("Should skip existing anchors in batch", async function () {
      const hash1 = ethers.keccak256(ethers.toUtf8Bytes("data1"));
      const hash2 = ethers.keccak256(ethers.toUtf8Bytes("data2"));

      // Record first anchor
      await hestiaAnchor.recordAnchor(hash1, "meeting");

      // Batch includes existing anchor
      const tx = await hestiaAnchor.recordAnchors([hash1, hash2], ["meeting", "meeting"]);
      const receipt = await tx.wait();

      // Check only 1 was recorded
      const batchEvent = receipt.logs.find(
        log => log.fragment?.name === "BatchRecorded"
      );
      expect(batchEvent.args[0]).to.equal(1n);
    });

    it("Should revert if arrays length mismatch", async function () {
      const hashes = [
        ethers.keccak256(ethers.toUtf8Bytes("data1")),
        ethers.keccak256(ethers.toUtf8Bytes("data2"))
      ];
      const types = ["meeting"];

      await expect(
        hestiaAnchor.recordAnchors(hashes, types)
      ).to.be.revertedWith("HestiaAnchor: arrays length mismatch");
    });

    it("Should revert if batch too large", async function () {
      const hashes = [];
      const types = [];
      for (let i = 0; i < 101; i++) {
        hashes.push(ethers.keccak256(ethers.toUtf8Bytes(`data${i}`)));
        types.push("meeting");
      }

      await expect(
        hestiaAnchor.recordAnchors(hashes, types)
      ).to.be.revertedWith("HestiaAnchor: batch too large (max 100)");
    });
  });

  describe("recordAnchorsSameType", function () {
    it("Should record multiple anchors with same type", async function () {
      const hashes = [
        ethers.keccak256(ethers.toUtf8Bytes("data1")),
        ethers.keccak256(ethers.toUtf8Bytes("data2")),
        ethers.keccak256(ethers.toUtf8Bytes("data3"))
      ];

      await hestiaAnchor.recordAnchorsSameType(hashes, "meeting");

      for (const hash of hashes) {
        expect(await hestiaAnchor.getType(hash)).to.equal("meeting");
      }
    });
  });

  describe("verifyAnchor", function () {
    it("Should return correct data for existing anchor", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await hestiaAnchor.recordAnchor(anchorHash, "meeting");

      const [exists, timestamp, type, recorder] = await hestiaAnchor.verifyAnchor(anchorHash);

      expect(exists).to.be.true;
      expect(timestamp).to.be.gt(0);
      expect(type).to.equal("meeting");
      expect(recorder).to.equal(owner.address);
    });

    it("Should return default values for non-existing anchor", async function () {
      const anchorHash = ethers.keccak256(ethers.toUtf8Bytes("nonexistent"));

      const [exists, timestamp, type, recorder] = await hestiaAnchor.verifyAnchor(anchorHash);

      expect(exists).to.be.false;
      expect(timestamp).to.equal(0);
      expect(type).to.equal("");
      expect(recorder).to.equal(ethers.ZeroAddress);
    });
  });

  describe("totalAnchors", function () {
    it("Should track total anchors", async function () {
      expect(await hestiaAnchor.totalAnchors()).to.equal(0);

      await hestiaAnchor.recordAnchor(
        ethers.keccak256(ethers.toUtf8Bytes("data1")),
        "meeting"
      );
      expect(await hestiaAnchor.totalAnchors()).to.equal(1);

      await hestiaAnchor.recordAnchors(
        [
          ethers.keccak256(ethers.toUtf8Bytes("data2")),
          ethers.keccak256(ethers.toUtf8Bytes("data3"))
        ],
        ["meeting", "meeting"]
      );
      expect(await hestiaAnchor.totalAnchors()).to.equal(3);
    });
  });

  describe("Gas optimization", function () {
    it("Batch should be more gas efficient than individual calls", async function () {
      // Single calls
      const singleGas = [];
      for (let i = 0; i < 5; i++) {
        const hash = ethers.keccak256(ethers.toUtf8Bytes(`single${i}`));
        const tx = await hestiaAnchor.recordAnchor(hash, "meeting");
        const receipt = await tx.wait();
        singleGas.push(receipt.gasUsed);
      }
      const totalSingleGas = singleGas.reduce((a, b) => a + b, 0n);

      // Batch call (new contract instance to avoid duplicates)
      const HestiaAnchor = await ethers.getContractFactory("HestiaAnchor");
      const batchContract = await HestiaAnchor.deploy();
      await batchContract.waitForDeployment();

      const batchHashes = [];
      const batchTypes = [];
      for (let i = 0; i < 5; i++) {
        batchHashes.push(ethers.keccak256(ethers.toUtf8Bytes(`batch${i}`)));
        batchTypes.push("meeting");
      }

      const batchTx = await batchContract.recordAnchors(batchHashes, batchTypes);
      const batchReceipt = await batchTx.wait();
      const batchGas = batchReceipt.gasUsed;

      console.log(`Single calls total gas: ${totalSingleGas}`);
      console.log(`Batch call gas: ${batchGas}`);
      console.log(`Savings: ${((totalSingleGas - batchGas) * 100n) / totalSingleGas}%`);

      // Batch should use less gas
      expect(batchGas).to.be.lt(totalSingleGas);
    });
  });
});

// Helper for any value matching
const anyValue = () => true;
