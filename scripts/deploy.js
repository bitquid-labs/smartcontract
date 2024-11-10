const { ethers } = require("hardhat");

const OWNER = "0xDA01D79Ca36b493C7906F3C032D2365Fb3470aEC";
const GOVTOKEN = "0x73795572FB8c1c737513156ecb8b1Cc9a3f9cA46";
const BSCBTC = "0x6ce8da28e2f864420840cf74474eff5fd80e65b8";
const MIN = 20000000000000;

async function main() {
  console.log("Starting deployment script...");
  try {
    const Token = await ethers.getContractFactory("BQToken");
    const bqtoken = await Token.deploy("BitQuid", "BQ", 18, 200000000000000);
    const bqtokenAddress = await bqtoken.getAddress();

    console.log(`Token Address: ${bqtokenAddress}`);

    const bqBTCToken = await ethers.getContractFactory("bqBTC");
    const bqBTC = await bqBTCToken.deploy(
      "BQ BTC",
      "bqBTC",
      18,
      200000000000000,
      OWNER,
      BSCBTC,
      MIN
    );
    const bqBTCAddress = await bqBTC.getAddress();

    console.log(`BQ BTC Address: ${bqBTCAddress}`);

    const InsurancePool = await ethers.getContractFactory("InsurancePool");
    const insurancePool = await InsurancePool.deploy(OWNER, bqBTCAddress);
    const poolAddress = await insurancePool.getAddress();

    console.log(`Pool Address: ${poolAddress}`);

    const Governance = await ethers.getContractFactory("Governance");
    const governance = await Governance.deploy(
      bqtokenAddress,
      poolAddress,
      5,
      OWNER
    );
    const govAddress = await governance.getAddress();

    console.log(`Gov Address: ${govAddress}`);

    const InsuraceCover = await ethers.getContractFactory("InsuranceCover");
    const coverContract = await InsuraceCover.deploy(
      poolAddress,
      OWNER,
      govAddress,
      bqBTCAddress
    );

    const coverAddress = await coverContract.getAddress();
    console.log(`Cover Address: ${coverAddress}`);

    console.log("Setting contracts...");

    await governance.setCoverContract(coverAddress);
    await insurancePool.setCover(coverAddress);
    await insurancePool.setGovernance(govAddress);
    await bqBTC.setPoolandCover(poolAddress, coverAddress, govAddress);

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
