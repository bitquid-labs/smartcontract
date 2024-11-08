const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance Contract", function () {
  let lpContract, coverContract, governance, bqbtc, bqtoken;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const BQBTC = await ethers.getContractFactory("bqBTC");
    bqbtc = await BQBTC.deploy(
      "BitQuid",
      "BQ",
      18,
      ethers.parseEther("1000000"),
      owner.address
    );

    const BQToken = await ethers.getContractFactory("BQToken");
    bqtoken = await BQToken.deploy(
      "BitQuid",
      "BQ",
      18,
      ethers.parseEther("1000000")
    );

    const LPContract = await ethers.getContractFactory("InsurancePool");
    lpContract = await LPContract.deploy(owner.address, bqbtc.target);

    Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(
      bqtoken.target,
      lpContract.target,
      1,
      owner.address
    );

    const CoverContract = await ethers.getContractFactory("InsuranceCover");
    coverContract = await CoverContract.deploy(
      lpContract.target,
      owner.address,
      governance.target,
      bqbtc.target
    );

    await lpContract.setGovernance(governance.target);
    await governance.setCoverContract(coverContract.target);
    await lpContract.setCover(coverContract.target);
    await bqbtc.setPoolandCover(lpContract.target, coverContract.target);
  });

  it("Should create a proposal successfully", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0,
      coverId: 1,
      txHash:
        "0x88d42e4bfcc4a801beefba2b52b032908a9c1f03b38937405c31f58430b40ad0",
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("2"),
    };

    await lpContract.connect(owner).createPool(0, "Random Pool", 3, 28);
    await bqbtc.mint(addr1.address, ethers.parseEther("1"));
    await bqbtc.mint(addr2.address, ethers.parseEther("10"));
    await lpContract.connect(addr2).deposit(1, ethers.parseEther("10"));

    await coverContract
      .connect(owner)
      .createCover(1, "cid", 0, "testCover", "chains", 50, 5, 1);

    await coverContract
      .connect(addr1)
      .purchaseCover(1, ethers.parseEther("3"), 120, 120000);

    await expect(governance.connect(addr1).createProposal(proposalParams))
      .to.emit(governance, "ProposalCreated")
      .withArgs(
        1,
        addr1.address,
        "Claim 100 tokens",
        0,
        ethers.parseEther("2"),
        0
      );

    await governance.getProposalDetails(1);
    const proposal = await governance.proposals(1);

    expect(proposal.id).to.equal(1);
    expect(proposal.proposalParam.user).to.equal(addr1.address);
    expect(proposal.proposalParam.claimAmount).to.equal(ethers.parseEther("2"));
    expect(proposal.status).to.equal(0);
  });

  it("Should allow voting on a proposal", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0,
      coverId: 1,
      txHash:
        "0x88d42e4bfcc4a801beefba2b52b032908a9c1f03b38937405c31f58430b40ad0",
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("2"),
    };

    await lpContract.connect(owner).createPool(0, "Random Pool", 3, 28);
    await bqbtc.mint(addr1.address, ethers.parseEther("1"));
    await bqbtc.mint(addr2.address, ethers.parseEther("10"));
    await bqtoken.mint(addr2.address, ethers.parseEther("10"));
    await lpContract.connect(addr2).deposit(1, ethers.parseEther("10"));

    await coverContract
      .connect(owner)
      .createCover(1, "cid", 0, "testCover", "chains", 50, 5, 1);

    await coverContract
      .connect(addr1)
      .purchaseCover(1, ethers.parseEther("3"), 120, 120000);

    await governance.connect(addr1).createProposal(proposalParams);

    await expect(governance.connect(addr2).vote(1, true))
      .to.emit(governance, "VoteCast")
      .withArgs(addr2.address, 1, true, ethers.parseEther("10"));

    await governance.getProposalDetails(1);
    const proposal = await governance.proposals(1);
    expect(proposal.votesFor).to.equal(ethers.parseEther("10"));
    expect(proposal.status).to.equal(1);
  });

  it("Should execute a proposal and update the user's cover value and claim paid", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0,
      coverId: 1,
      txHash:
        "0x88d42e4bfcc4a801beefba2b52b032908a9c1f03b38937405c31f58430b40ad0",
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("2"),
    };

    await lpContract.connect(owner).createPool(0, "Random Pool", 3, 28);
    await bqbtc.mint(addr1.address, ethers.parseEther("1"));
    await bqbtc.mint(addr2.address, ethers.parseEther("10"));
    await bqtoken.mint(addr2.address, ethers.parseEther("10"));
    await lpContract.connect(addr2).deposit(1, ethers.parseEther("10"));

    await coverContract
      .connect(owner)
      .createCover(1, "cid", 0, "testCover", "chains", 50, 5, 1);

    await coverContract
      .connect(addr1)
      .purchaseCover(1, ethers.parseEther("3"), 120, 120000);

    await governance.connect(addr1).createProposal(proposalParams);
    await governance.connect(addr2).vote(1, true);

    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    await expect(governance.connect(owner).executeProposal())
      .to.emit(governance, "ProposalExecuted")
      .withArgs(1, true);

    const proposal = await governance.proposals(1);
    expect(proposal.executed).to.be.true;
    expect(proposal.status).to.equal(2);

    const coverinfo = await coverContract.getUserCoverInfo(
      proposal.proposalParam.user,
      proposal.proposalParam.coverId
    );

    expect(coverinfo.coverValue).to.equal(ethers.parseEther("1"));
    expect(coverinfo.claimPaid).to.equal(ethers.parseEther("2"));
  });
});
