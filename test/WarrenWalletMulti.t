// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../contracts/WarrenWalletMulti.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockPool.sol";
import "../contracts/mocks/MockPoolAddressesProvider.sol";

contract WarrenWalletMultiTest is Test {
    WarrenWalletMulti ww;
    MockERC20 usdc;
    MockERC20 weth;
    MockERC20 wbtc;
    MockPool pool;
    MockPoolAddressesProvider provider;

    address ADMIN = address(0xA11CE);
    address DAO   = address(0xc2bb63Dc8f0e456F3bD13C3ce1D2F730CA1bE8Fc);
    address ALICE = address(0xBEEF);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);

        usdc.mint(ALICE, 1_000_000e6);
        weth.mint(ALICE, 1000 ether);
        wbtc.mint(ALICE, 1000 * 10**8);

        ww = new WarrenWalletMulti(ADMIN, DAO);

        vm.startPrank(ADMIN);
        ww.listAsset(address(usdc), 3e6, true);
        ww.listAsset(address(weth), 1e15, true);      // 0.001 WETH demo
        ww.listAsset(address(wbtc), 1 * 10**6, true); // 0.01 WBTC demo
        pool = new MockPool();
        provider = new MockPoolAddressesProvider(address(pool));
        ww.setAaveProvider(IPoolAddressesProvider(address(provider)));
        vm.stopPrank();
    }

    function test_DepositBelowMin_Reverts() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 2_999_999);
        vm.expectRevert("min deposit");
        ww.deposit(address(usdc), 2_999_999, unlockAt);
        vm.stopPrank();
    }

    function test_DepositShortLock_Reverts() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK() - 1);
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 10_000_000);
        vm.expectRevert("lock >=10y");
        ww.deposit(address(usdc), 10_000_000, unlockAt);
        vm.stopPrank();
    }

    function test_First1000_ExemptAUM() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 100_000_000);
        ww.deposit(address(usdc), 100_000_000, unlockAt);
        vm.stopPrank();

        // Avanza 1 año + 6 meses para rebalance
        vm.warp(block.timestamp + 365 days + 180 days);

        uint256 daoBefore = usdc.balanceOf(DAO);
        vm.startPrank(ALICE);
        uint256[] memory ids = new uint256[](1); ids[0] = 1;
        ww.rebalanceToAave(ids);
        vm.stopPrank();
        uint256 daoAfter = usdc.balanceOf(DAO);
        assertEq(daoAfter - daoBefore, 0, "AUM debe ser 0 para exentos");
    }

    function test_NoEarlyWithdraw() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 10_000_000);
        ww.deposit(address(usdc), 10_000_000, unlockAt);
        vm.stopPrank();

        vm.prank(ALICE);
        vm.expectRevert("locked");
        ww.withdraw(1);
    }

    function test_WithdrawCharges3Percent() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 100_000_000);
        ww.deposit(address(usdc), 100_000_000, unlockAt);
        vm.stopPrank();

        // Desexentar para permitir AUM en otros tests (no afecta a este)
        vm.prank(ADMIN);
        ww.setFeeExempt(ALICE, false);

        vm.warp(unlockAt + 1);
        uint256 daoBefore = usdc.balanceOf(DAO);
        uint256 aliceBefore = usdc.balanceOf(ALICE);

        vm.prank(ALICE);
        ww.withdraw(1);

        uint256 daoAfter = usdc.balanceOf(DAO);
        uint256 aliceAfter = usdc.balanceOf(ALICE);

        uint256 wFee = 100_000_000 * 300 / 10_000; // 3%
        assertEq(daoAfter - daoBefore, wFee);
        assertEq(aliceAfter - aliceBefore, 100_000_000 - wFee);
    }

    function test_Rebalance50_AfterSixMonths() public {
        uint32 unlockAt = uint32(block.timestamp + ww.MIN_LOCK());
        vm.startPrank(ALICE);
        usdc.approve(address(ww), 10_000_000);
        ww.deposit(address(usdc), 10_000_000, unlockAt);
        vm.stopPrank();

        vm.warp(block.timestamp + 180 days);
        vm.startPrank(ALICE);
        uint256[] memory ids = new uint256[](1); ids[0]=1;
        ww.rebalanceToAave(ids);
        vm.stopPrank();

        // MockPool debe tener fondos
        assertGt(usdc.balanceOf(address(pool)), 0);
    }
}
