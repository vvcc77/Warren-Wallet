// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../contracts/WarrenWalletMulti.sol";
import "../contracts/mocks/MockPoolAddressesProvider.sol";

/// @dev Parametrizado por variables de entorno .env
/// DAO_TREASURY: tesorería EVM (recibe fees)
/// AAVE_PROVIDER: dirección del PoolAddressesProvider (o mock si vacío)
/// USDC, WETH, WBTC: direcciones de tokens (si se setean, se listan)
/// MIN_USDC, MIN_WETH, MIN_WBTC: mínimos por token
contract Deploy is Script {
    function run() external {
        address admin = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 pk    = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address dao   = vm.envAddress("DAO_TREASURY");

        address aaveProv = vm.envOr("AAVE_PROVIDER", address(0));

        address usdc = vm.envOr("USDC", address(0));
        address weth = vm.envOr("WETH", address(0));
        address wbtc = vm.envOr("WBTC", address(0));

        uint256 minUsdc = vm.envOr("MIN_USDC", uint256(3e6));
        uint256 minWeth = vm.envOr("MIN_WETH", uint256(1e15)); // 0.001 WETH
        uint256 minWbtc = vm.envOr("MIN_WBTC", uint256(1e6));  // 0.01 WBTC

        vm.startBroadcast(pk);
        WarrenWalletMulti vault = new WarrenWalletMulti(admin, dao);

        if (aaveProv == address(0)) {
            // Despliega mock si no se pasa provider
            MockPoolAddressesProvider mock = new MockPoolAddressesProvider(address(0));
            vault.setAaveProvider(IPoolAddressesProvider(address(mock)));
        } else {
            vault.setAaveProvider(IPoolAddressesProvider(aaveProv));
        }

        if (usdc != address(0)) { vault.listAsset(usdc, minUsdc, true); }
        if (weth != address(0)) { vault.listAsset(weth, minWeth, true); }
        if (wbtc != address(0)) { vault.listAsset(wbtc, minWbtc, true); }

        vm.stopBroadcast();

        console2.log("WarrenWalletMulti deployed at:", address(vault));
    }
}
