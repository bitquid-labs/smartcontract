const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InsurancePool", function () {
  let insuranceCover, insurancePool, governance, bqbtc, governanceToken;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const GovernanceToken = await ethers.getContractFactory("BQToken");
    governanceToken = await GovernanceToken.deploy(
      "BitQuid",
      "BQ",
      18,
      ethers.parseEther("1000000")
    );

    const BQBTC = await ethers.getContractFactory("bqBTC");
    bqbtc = await BQBTC.deploy(
      "BitQuid",
      "BQ",
      18,
      ethers.parseEther("1000000"),
      owner.address
    );

    const InsurancePool = await ethers.getContractFactory("InsurancePool");
    insurancePool = await InsurancePool.deploy(owner.address, bqbtc.target);

    const Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(
      governanceToken.target,
      insurancePool.target,
      1,
      owner.address
    );

    const InsuranceCoverFactory = await ethers.getContractFactory(
      "InsuranceCover"
    );
    insuranceCover = await InsuranceCoverFactory.deploy(
      insurancePool.target,
      owner.address,
      governance.target,
      bqbtc.target
    );

    await insurancePool.setCover(insuranceCover.target);
    await insurancePool.setGovernance(governance.target);
    await governance.setCoverContract(insuranceCover.target);
    await bqbtc.setPoolandCover(insurancePool.target, insuranceCover.target);
  });

  describe("Pool Management", function () {
    it("should allow the owner to create a pool", async function () {
      await expect(insurancePool.createPool(0, "Test Pool", 5, 30))
        .to.emit(insurancePool, "PoolCreated")
        .withArgs(1, "Test Pool");

      const pool = await insurancePool.getPool(1);
      expect(pool.apy).to.equal(5);
      expect(pool.minPeriod).to.equal(30);
      expect(pool.isActive).to.be.true;
    });

    it("should allow the owner to update a pool", async function () {
      await insurancePool.createPool(0, "Test Pool", 5, 30);
      await expect(insurancePool.updatePool(1, 10, 60))
        .to.emit(insurancePool, "PoolUpdated")
        .withArgs(1, 10, 60);

      const pool = await insurancePool.getPool(1);
      expect(pool.apy).to.equal(10);
      expect(pool.minPeriod).to.equal(60);
    });

    it("should revert when trying to update an inactive pool", async function () {
      await insurancePool.createPool(0, "Test Pool", 5, 30);
      await insurancePool.deactivatePool(1);

      await expect(insurancePool.updatePool(1, 10, 60)).to.be.revertedWith(
        "Pool does not exist or is inactive"
      );
    });

    it("should revert when a non-owner tries to create a pool", async function () {
      await expect(
        insurancePool.connect(user1).createPool(0, "User Pool", 5, 30)
      ).to.be.revertedWithCustomError(
        insurancePool,
        "OwnableUnauthorizedAccount"
      );
    });
  });

  describe("Deposits and Withdrawals", function () {
    beforeEach(async function () {
      await bqbtc.mint(user1.address, ethers.parseEther("100"));
      await insurancePool.createPool(0, "Test Pool", 5, 30);
    });

    it("should allow a user to deposit funds", async function () {
      await expect(
        insurancePool.connect(user1).deposit(1, ethers.parseEther("10"))
      )
        .to.emit(insurancePool, "Deposited")
        .withArgs(user1.address, ethers.parseEther("10"), "Test Pool");

      const deposit = await insurancePool.getUserDeposit(1, user1.address);
      expect(deposit.amount).to.equal(ethers.parseEther("10"));
      expect(deposit.status).to.equal(0);
    });

    it("should revert if a user deposits zero amount", async function () {
      await expect(
        insurancePool.connect(user1).deposit(1, 0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("should allow a user to withdraw funds after the period ends", async function () {
      await insurancePool.connect(user1).deposit(1, ethers.parseEther("10"));

      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      await expect(insurancePool.connect(user1).withdraw(1))
        .to.emit(insurancePool, "Withdraw")
        .withArgs(user1.address, ethers.parseEther("10"), "Test Pool");

      const deposit = await insurancePool.getUserDeposit(1, user1.address);
      expect(deposit.status).to.equal(1);
    });

    it("should revert withdrawal if the period has not ended", async function () {
      await insurancePool.connect(user1).deposit(1, ethers.parseEther("10"));

      await expect(insurancePool.connect(user1).withdraw(1)).to.be.revertedWith(
        "Deposit period has not ended"
      );
    });
  });

  describe("Claims", function () {
    beforeEach(async function () {
      await insurancePool.createPool(0, "Test Pool", 5, 30);

      const proposalParams = {
        user: user1.address,
        riskType: 0,
        coverId: 1,
        txHash:
          "0x88d42e4bfcc4a801beefba2b52b032908a9c1f03b38937405c31f58430b40ad0",
        description: "Claim 100 tokens",
        poolId: 1,
        claimAmount: ethers.parseEther("2"),
      };

      await bqbtc.mint(user1.address, ethers.parseEther("1"));
      await bqbtc.mint(user2.address, ethers.parseEther("10"));
      await governanceToken.mint(user2.address, ethers.parseEther("10"));
      await insurancePool.connect(user2).deposit(1, ethers.parseEther("10"));

      await insuranceCover
        .connect(owner)
        .createCover(1, "cid", 0, "testCover", "chains", 50, 5, 1);

      await insuranceCover
        .connect(user1)
        .purchaseCover(1, ethers.parseEther("3"), 120, 120000);

      await governance.connect(user1).createProposal(proposalParams);
      await governance.connect(user2).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      await governance.connect(owner).executeProposal();
    });

    it("should allow user to make a claim", async function () {
      await expect(insurancePool.connect(user1).claimProposalFunds(1))
        .to.emit(insurancePool, "ClaimPaid")
        .withArgs(user1.address, "Test Pool", ethers.parseEther("2"));

      const poolTVL = await insurancePool.getPoolTVL(1);
      expect(poolTVL).to.equal(ethers.parseEther("8"));
    });

    it("should revert if a wrong user tries to make a claim", async function () {
      await expect(
        insurancePool.connect(user2).claimProposalFunds(1)
      ).to.be.revertedWith("Not a valid proposal");
    });
  });
});
