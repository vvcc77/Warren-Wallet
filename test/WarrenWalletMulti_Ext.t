// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../contracts/WarrenWalletMulti.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockPool.sol";
import "../contracts/mocks/MockPoolAddressesProvider.sol";

contract WarrenWalletMultiExtTest is Test {
    WarrenWalletMulti ww;
    MockERC20 usdc; MockERC20 weth;
    MockPool pool; MockPoolAddressesProvider provider;

    address ADMIN = address(0xA11CE);
    address DAO   = address(0xc2bb63Dc8f0e456F3bD13C3ce1D2F730CA1bE8Fc);
    address ALICE = address(0xBEEF);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc.mint(ALICE, 10_000e6);
        weth.mint(ALICE, 10 ether);

        ww = new WarrenWalletMulti(ADMIN, DAO);
        vm.startPrank(ADMIN);
        ww.listAsset(address(usdc), 3e6, true);
        ww.listAsset(address(weth), 1e15, true);
        pool = new MockPool(); provider = new MockPoolAddressesProvider(address(pool));
        ww.setAaveProvider(IPoolAddressesProvider(address(provider)));
        vm.stopPrank();
    }

    function test_SetBeneficiary_And_Rollover() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 10_000e6);
        ww.deposit(address(usdc), 10_000e6, unlockAt);
        ww.setBeneficiary(1, address(0x1234), bytes32(uint256(0xDEADBEEF)));
        vm.stopPrank();

        // Avanza hasta el vencimiento y ejecuta rollover
        vm.warp(unlockAt + 1);
        vm.prank(ALICE);
        ww.rolloverPosition(1);

        (, , , , , uint32 unlock2, , ) = ww.positions(1);
        assertGt(unlock2, unlockAt, "Debe extender +10y");
    }
}
