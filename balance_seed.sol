import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { network } from "hardhat";
import { formatUnits, parseUnits } from "ethers";


const { sign } = require("crypto");

async function impersonateAccount(acctAddress) {
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [acctAddress],
  });
  return await ethers.getSigner(acctAddress);
}

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    const OTB_PRICE = "0.3"; // USD price in USDC 

    // Contracts are deployed using the first signer/account by default
    const accounts = await ethers.getSigners();

    const WOTB = await ethers.getContractFactory("wOTB");
    const otb = await WOTB.deploy();


    const Seed = await ethers.getContractFactory("Presale");
    const seed = await Seed.deploy(ethers.parseUnits(OTB_PRICE, 6 ));

    //await otb.transfer(accounts[1].address, parseUnits("100", 18))

    return { otb, seed, accounts };
  }

  

  describe("All", function () {
    it("Tests", async function () {
      const { otb, seed, accounts} = await loadFixture(deployFixture);

      const USD_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

      // Manipulate balance
  
      const usdc = await ethers.getContractAt("ERC20", USD_ADDRESS);
      
      const a = await impersonateAccount("0xAe2D4617c862309A3d75A0fFB358c7a5009c673F");
      await usdc.connect(a).transfer(accounts[1].address, ethers.parseUnits("100000", 6));
      
      let balance = await usdc.balanceOf(accounts[1].address);
      console.log("USDC Balance  - " + balance.toString());    

      // Add beneficiary
      const OTB_TO_GET = 100;
      await seed.addBeneficiary(accounts[1].address, OTB_TO_GET);

      // Botstrap
      balance = await otb.balanceOf(accounts[0].address);
      console.log("OTB Balance  - " + balance.toString());    

      await otb.approve(seed.getAddress(), parseUnits("1000000000", 9))

      
      let tx = await seed.bootstrap(15768017, otb.getAddress(), USD_ADDRESS);
      await tx.wait();

      

      // Transfer USD to seed
      
      const USD_TO_INVEST = await seed.connect(accounts[1]).investmentAmount(accounts[1].address);
      
      console.log("USD to invest  - " + formatUnits(USD_TO_INVEST, 6));

      await usdc.connect(accounts[1]).approve(seed.getAddress(), USD_TO_INVEST);
      
      await seed.connect(accounts[1]).transferUsd(USD_TO_INVEST);


      balance = await usdc.balanceOf(seed.getAddress());
      console.log("USDC Contract Balance  - " + formatUnits(balance, 6)); 

      let vested = await seed.vestedBeneficiaries(accounts[1].address);
      console.log("To be Vested: " + vested.amount);

      const timestamp = await time.latest() + 100;
      tx = await seed.setStartTime(timestamp);
      await tx.wait();

      for (let i = 0; i < 9; i++) {
        await time.increase(3600*24*30);
        let releasableAmount = await seed.releasableAmount(accounts[1].address);
        console.log("releasableAmount: month " + i + " = " +  releasableAmount);

      }

      

      


      expect(true);
    });
    
  });
});
