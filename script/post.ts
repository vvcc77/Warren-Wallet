import { ethers } from "hardhat";

const VAULT = "0x...direccion_de_tu_contrato";

async function main() {
  const vault = await ethers.getContractAt("WarrenWalletMulti", VAULT);

  // Aave provider:
  // await (await vault.setAaveProvider("0x...")).wait();

  // Listar WETH con mínimo 0.001 WETH:
  // await (await vault.listAsset("0x...WETH", 10n ** 15n, true)).wait();

  // Listar USDC con mínimo 3e6:
  // await (await vault.listAsset("0x...USDC", 3000000n, true)).wait();
}
main().catch((e)=>{console.error(e);process.exit(1);});
