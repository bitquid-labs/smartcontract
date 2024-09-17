const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance Contract", function () {
  let Governance,
    governanceAddress,
    governanceTokenAdreess,
    lpContractAddress,
    coverContractAddress,
    owner,
    addr1,
    addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const GovernanceToken = await ethers.getContractFactory("MockERC20");
    governanceToken = await GovernanceToken.deploy(
      "BitQuid",
      "BQ",
      18,
      ethers.parseEther("1000000")
    );
    governanceTokenAdreess = governanceToken.target;

    const LPContract = await ethers.getContractFactory("InsurancePool");
    lpContract = await LPContract.deploy(owner.address);
    lpContractAddress = lpContract.target;

    Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(
      governanceToken.target,
      lpContract.target,
      1,
      owner.address
    );
    governanceAddress = governance.target;

    const CoverContract = await ethers.getContractFactory("InsuranceCover");
    coverContract = await CoverContract.deploy(
      lpContract.target,
      owner.address,
      governance.target
    );
    coverContractAddress = coverContract.target;

    await lpContract.setGovernance(governanceAddress);

    // if (coverContract.target) {
    //   await governance.setCoverContract(coverContract.target);
    // } else {
    //   console.error("Cover contract address is null");
    // }
  });

  it("Should create a proposal successfully", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0, // This would be a slashing cover
      coverId: 1,
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("100"),
    };

    await lpContract.createPool(0, "Random Pool", 3, 28);

    await governance.connect(addr1).createProposal(proposalParams);

    const proposal = await governance.getProposalDetails(1);
    expect(proposal.id).to.equal(1);
    expect(proposal.proposalParam.user).to.equal(addr1.address);
    expect(proposal.proposalParam.claimAmount).to.equal(
      ethers.parseEther("100")
    );
  });

  it("Should allow voting on a proposal", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0,
      coverId: 1,
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("100"),
    };

    await lpContract.createPool(0, "Random Pool", 3, 28);
    await governance.connect(addr1).createProposal(proposalParams);

    await governanceToken.transfer(addr2.address, ethers.parseEther("100"));

    await governance.connect(addr2).vote(1, true);

    const proposal = await governance.getProposalDetails(1);
    expect(proposal.votesFor).to.equal(ethers.parseEther("100"));
  });

  it("Should execute a proposal and update the user's cover value and claim paid", async function () {
    const proposalParams = {
      user: addr1.address,
      riskType: 0,
      coverId: 1,
      description: "Claim 100 tokens",
      poolId: 1,
      claimAmount: ethers.parseEther("100"),
    };

    console.log();

    await lpContract.createPool(0, "Random Pool", 3, 28);
    const pool = await lpContract.getPool(1);
    await lpContract.connect(addr2).deposit(1, 150, {
      value: ethers.parseEther("1000"),
    });

    const updatedPool = await lpContract.getPool(1);
    // await governance.connect(owner).setCoverContract(coverContract.target);

    await governance.connect(addr1).createProposal(proposalParams);
    const propos = await governance.getProposalDetails(1);
    console.log("Proposal details:", propos);

    await governanceToken.transfer(addr2.address, ethers.parseEther("100"));

    await governance.connect(addr2).vote(1, true);

    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    const poolBalance = await ethers.provider.getBalance(lpContract.target);
    try {
      const tx = await governance.connect(owner).executeProposal(1);
      const receipt = await tx.wait();
    } catch (error) {
      console.error("Error executing proposal:", error.message);
      if (error.data) {
        const decodedError = ethers.AbiCoder.defaultAbiCoder().decode(
          ["string"],
          error.data
        );
        console.error("Decoded error:", decodedError);
      }
    }
    const proposal = await governance.getProposalDetails(1);
    expect(proposal.executed).to.be.true;

    const [coverValue, claimPaid] = await coverContract.getUserCoverDetails(
      proposal.proposalParam.user,
      proposal.proposalParam.coverId,
      proposal.proposalParam.riskType
    );

    expect(coverValue).to.equal(ethers.parseEther("0"));
    expect(claimPaid).to.equal(ethers.parseEther("100"));
  });

  // it("Should allow owner to set the Cover Contract", async function () {
  //   await governance.connect(owner).setCoverContract(coverContract.target);
  //   expect(await governance.coverContract()).to.equal(coverContract.target);
  // });

  // it("Should revert if trying to set the Cover Contract again", async function () {
  //   await governance.connect(owner).setCoverContract(coverContract.target);
  //   await expect(
  //     governance.connect(owner).setCoverContract(coverContract.target)
  //   ).to.be.revertedWith("Governance already set");
  // });
});
