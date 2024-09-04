const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InsurancePool", function () {
  let insurancePool, owner, governance, user1, user2;

  beforeEach(async function () {
    [owner, governance, user1, user2] = await ethers.getSigners();

    const InsurancePool = await ethers.getContractFactory("InsurancePool");
    insurancePool = await InsurancePool.deploy(owner.address);
  });

  describe("Pool Management", function () {
    it("should allow the owner to create a pool", async function () {
      await insurancePool.createPool("Test Pool", 5, 30);

      const pool = await insurancePool.getPool(1);
      expect(pool.apy).to.equal(5);
      expect(pool.minPeriod).to.equal(30);
      expect(pool.isActive).to.be.true;
    });

    it("should allow the owner to update a pool", async function () {
      await insurancePool.createPool("Test Pool", 5, 30);
      await insurancePool.updatePool(1, 10, 60);

      const pool = await insurancePool.getPool(1);
      expect(pool.apy).to.equal(10);
      expect(pool.minPeriod).to.equal(60);
    });

    it("should revert when trying to update an inactive pool", async function () {
      await insurancePool.createPool("Test Pool", 5, 30);
      await insurancePool.deactivatePool(1);

      await expect(insurancePool.updatePool(1, 10, 60)).to.be.revertedWith(
        "Pool does not exist or is inactive"
      );
    });
  });

  describe("Deposits and Withdrawals", function () {
    beforeEach(async function () {
      await insurancePool.createPool("Test Pool", 5, 30);
    });

    it("should allow a user to deposit funds", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("1.0"),
      });

      const deposit = await insurancePool.getUserDeposit(1, user1.address);
      expect(deposit.amount).to.equal(ethers.parseEther("1.0"));
      expect(deposit.status).to.equal(0); // Status.Active
    });

    it("should allow a user to withdraw funds after the period ends", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("1.0"),
      });

      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // Increase time by 30 days
      await ethers.provider.send("evm_mine", []);

      await insurancePool.connect(user1).withdraw(1);

      const deposit = await insurancePool.getUserDeposit(1, user1.address);
      expect(deposit.status).to.equal(1); // Status.Withdrawn
    });

    it("should revert withdrawal if the period has not ended", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("1.0"),
      });

      await expect(insurancePool.connect(user1).withdraw(1)).to.be.revertedWith(
        "Deposit period has not ended"
      );
    });
  });

  describe("Claims", function () {
    beforeEach(async function () {
      await insurancePool.createPool("Test Pool", 5, 30);
      await insurancePool.setGovernance(governance.address);
    });

    it("should allow governance to pay a claim", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("5.0"),
      });

      await insurancePool
        .connect(governance)
        .payClaim(1, ethers.parseEther("1.0"), user2.address);

      const poolTVL = await insurancePool.getPoolTVL(1);
      expect(poolTVL).to.equal(ethers.parseEther("4.0"));
    });

    it("should revert if non-governance tries to pay a claim", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("5.0"),
      });

      await expect(
        insurancePool
          .connect(user1)
          .payClaim(1, ethers.parseEther("1.0"), user2.address)
      ).to.be.revertedWith("Caller is not the governance contract");
    });

    it("should revert if there are insufficient funds in the pool", async function () {
      await insurancePool.connect(user1).deposit(1, 30, {
        value: ethers.parseEther("1.0"),
      });

      await expect(
        insurancePool
          .connect(governance)
          .payClaim(1, ethers.parseEther("2.0"), user2.address)
      ).to.be.revertedWith("Not enough funds in the pool");
    });
  });
});
