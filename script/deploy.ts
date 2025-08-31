import { ethers } from "hardhat";

async function main() {
  const admin = process.env.ADMIN_ADDRESS!;
  const dao   = process.env.DAO_TREASURY!;
  if (!admin || !dao) throw new Error("ADMIN_ADDRESS / DAO_TREASURY faltan en .env");

  const Warren = await ethers.getContractFactory("WarrenWalletMulti");
  const vault  = await Warren.deploy(admin, dao);
  await vault.waitForDeployment();

  const addr = await vault.getAddress();
  console.log("WarrenWalletMulti deployed at:", addr);

  // Opcional: set Aave provider si está definido
  const aave = process.env.AAVE_PROVIDER;
  if (aave && aave !== "" && aave !== "0x0000000000000000000000000000000000000000") {
    const tx = await vault.setAaveProvider(aave);
    await tx.wait();
    console.log("Aave provider set:", aave);
  }

  // Opcional: listar assets en el deploy
  const assets: { key: string; minKey: string }[] = [
    { key: "USDC", minKey: "MIN_USDC" },
    { key: "WETH", minKey: "MIN_WETH" },
    { key: "DAI", minKey: "MIN_DAI" },
    { key: "USDT", minKey: "MIN_USDT" },
    { key: "WBTC", minKey: "MIN_WBTC" },
  ];

  for (const a of assets) {
    const addrA = process.env[a.key];
    const minA  = process.env[a.minKey];
    if (addrA && addrA !== "") {
      const min = minA ? BigInt(minA) : 0n;
      const tx = await vault.listAsset(addrA, min, true);
      await tx.wait();
      console.log(`Asset listado: ${a.key} @ ${addrA} (min=${min.toString()})`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
