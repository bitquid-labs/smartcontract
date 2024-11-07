const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InsuranceCover", function () {
  let insuranceCover, lpContractMock, governance, bqbtc, governanceToken;
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

    const LPContractMock = await ethers.getContractFactory("InsurancePool");
    lpContractMock = await LPContractMock.deploy(owner.address, bqbtc.target);

    const Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(
      governanceToken.target,
      lpContractMock.target,
      1,
      owner.address
    );

    const InsuranceCoverFactory = await ethers.getContractFactory(
      "InsuranceCover"
    );
    insuranceCover = await InsuranceCoverFactory.deploy(
      lpContractMock.target,
      owner.address,
      governance.target,
      bqbtc.target
    );

    await lpContractMock.setCover(insuranceCover.target);
    await lpContractMock.setGovernance(governance.target);
    await governance.setCoverContract(insuranceCover.target);
    await bqbtc.setPoolandCover(lpContractMock.target, insuranceCover.target);
  });

  describe("Cover Creation", function () {
    beforeEach(async function () {
      await bqbtc.mint(user2.address, ethers.parseEther("10"));
      await lpContractMock
        .connect(owner)
        .createPool(0, "Slashing pool", 3, 120);
      await lpContractMock.connect(user2).deposit(1, ethers.parseEther("10"));
    });

    it("Should create a new slashing cover successfully", async function () {
      await expect(
        insuranceCover
          .connect(owner)
          .createCover(1, "cid", 0, "Slashing Cover", "Ethereum", 50, 5, 1)
      )
        .to.emit(insuranceCover, "CoverCreated")
        .withArgs(1, "Slashing Cover", 0);

      const cover = await insuranceCover.covers(1);
      expect(cover.coverName).to.equal("Slashing Cover");
      expect(cover.chains).to.equal("Ethereum");
      expect(cover.capacity).to.equal(50);
      expect(cover.cost).to.equal(5);
    });

    it("Should revert if non-owner tries to create a cover", async function () {
      await expect(
        insuranceCover
          .connect(user1)
          .createCover(1, "cid", 0, "Unauthorized Cover", "Ethereum", 50, 5, 1)
      ).to.be.revertedWithCustomError(
        insuranceCover,
        "OwnableUnauthorizedAccount"
      );
    });
  });

  describe("Cover Purchase", function () {
    beforeEach(async function () {
      await bqbtc.mint(user2.address, ethers.parseEther("10"));
      await lpContractMock
        .connect(owner)
        .createPool(0, "Slashing pool", 3, 120);
      await lpContractMock.connect(user2).deposit(1, ethers.parseEther("10"));

      await insuranceCover
        .connect(owner)
        .createCover(1, "cid", 0, "Slashing Cover", "Ethereum", 50, 5, 1);
      await bqbtc.mint(user1.address, ethers.parseEther("100"));
    });

    it("Should allow a user to purchase a slashing cover successfully", async function () {
      const coverValue = ethers.parseEther("3");
      await expect(
        insuranceCover
          .connect(user1)
          .purchaseCover(1, coverValue, 30, ethers.parseEther("5"))
      )
        .to.emit(insuranceCover, "CoverPurchased")
        .withArgs(user1.address, coverValue, ethers.parseEther("5"), 0);

      const userCover = await insuranceCover.getUserCoverInfo(user1.address, 1);
      expect(userCover.coverValue).to.equal(coverValue);
      expect(userCover.isActive).to.be.true;
    });

    it("Should revert if cover period is invalid", async function () {
      await expect(
        insuranceCover
          .connect(user1)
          .purchaseCover(1, ethers.parseEther("10"), 10, ethers.parseEther("5"))
      ).to.be.revertedWithCustomError(insuranceCover, "InvalidCoverDuration");
    });

    it("Should revert if cover value exceeds the cover balance", async function () {
      await expect(
        insuranceCover
          .connect(user1)
          .purchaseCover(
            1,
            ethers.parseEther("1000"),
            30,
            ethers.parseEther("5")
          )
      ).to.be.revertedWithCustomError(
        insuranceCover,
        "InsufficientPoolBalance"
      );
    });
  });

  describe("Claim Payout", function () {
    beforeEach(async function () {
      await bqbtc.mint(user2.address, ethers.parseEther("11"));
      await bqbtc.mint(user1.address, ethers.parseEther("16"));
      await lpContractMock
        .connect(owner)
        .createPool(0, "Slashing pool", 3, 120);
      await lpContractMock.connect(user2).deposit(1, ethers.parseEther("10"));

      await insuranceCover
        .connect(owner)
        .createCover(1, "cid", 0, "Slashing Cover", "Ethereum", 50, 5, 1);

      await insuranceCover
        .connect(user1)
        .purchaseCover(1, ethers.parseEther("3"), 30, ethers.parseEther("5"));
    });

    it("Should allow LP to claim a payout if eligible", async function () {
      await lpContractMock.connect(user1).deposit(1, ethers.parseEther("10"));

      const initialBalance = await bqbtc.balanceOf(user1.address);

      await ethers.provider.send("evm_increaseTime", [12 * 60]);
      await ethers.provider.send("evm_mine", []);

      await expect(insuranceCover.connect(user1).claimPayoutForLP(1)).to.emit(
        insuranceCover,
        "PayoutClaimed"
      );

      const finalBalance = await bqbtc.balanceOf(user1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should revert if LP is not active", async function () {
      await expect(
        insuranceCover.connect(user1).claimPayoutForLP(1)
      ).to.be.revertedWithCustomError(insuranceCover, "NoClaimableReward");
    });
  });
});
