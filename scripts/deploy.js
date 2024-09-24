const { ethers } = require("hardhat");

const OWNER = "0xDA01D79Ca36b493C7906F3C032D2365Fb3470aEC";
const DECIMALS = 18;
const INITIAL_SUPPLY = 200000000000000;
const NAME = "BitQuid";
const SYMBOL = "BQ";
const GOVTOKEN = "0x73795572FB8c1c737513156ecb8b1Cc9a3f9cA46";

async function main() {
  console.log("Starting deployment script");
  try {
    const Token = await ethers.getContractFactory("MockERC20");
    const token = await Token.deploy(NAME, SYMBOL, DECIMALS, INITIAL_SUPPLY);
    const tokenAddress = await token.getAddress();

    console.log(`Token Address: ${tokenAddress}`);

    const InsurancePool = await ethers.getContractFactory("InsurancePool");
    const insurancePool = await InsurancePool.deploy(OWNER);
    const poolAddress = await insurancePool.getAddress();

    console.log(`Pool Address: ${poolAddress}`);

    const Governance = await ethers.getContractFactory("Governance");
    const governance = await Governance.deploy(GOVTOKEN, poolAddress, 5, OWNER);
    const govAddress = await governance.getAddress();

    console.log(`Gov Address: ${govAddress}`);

    const InsuraceCover = await ethers.getContractFactory("InsuranceCover");
    const coverContract = await InsuraceCover.deploy(
      poolAddress,
      OWNER,
      govAddress
    );

    const coverAddress = await coverContract.getAddress();
    console.log(`Cover Address: ${coverAddress}`);

    console.log("Setting contracts...");

    await governance.setCoverContract(coverAddress);
    await insurancePool.setCover(coverAddress);
    await insurancePool.setGovernance(coverAddress);

    console.log("All contracts set");
  } catch (error) {
    console.error("An error occurred:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
