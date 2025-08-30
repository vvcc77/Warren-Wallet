// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
interface IPoolAddressesProvider { function getPool() external view returns (address); }

/// @title WarrenWalletMulti
/// @notice Billetera de ahorro disciplinado multi-asset con lock de 10 años,
///         AUM 0.5% (exención primeros 1000 usuarios), 3% fee al retirar,
///         rebalance semestral 50% a Aave, beneficiario ENS y rollover +10y.
contract WarrenWalletMulti is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");

    address public daoTreasury; // EVM Treasury (recibe fees)

    // Fees
    uint16 public withdrawFeeBps = 300; // 3%
    uint16 public mgmtFeeYearBps = 50;  // 0.5% anual (pro-rata)
    uint32 public constant MIN_LOCK = 315360000; // 10 años en segundos

    // Aave
    IPoolAddressesProvider public aaveProvider;
    IPool public aavePool;

    // Registro de assets
    mapping(address => bool)    public isAssetAllowed;
    mapping(address => uint256) public minDepositByAsset; // por token (ej. USDC: 3e6)

    event AssetListed(address indexed asset, uint256 minDeposit, bool allowed);
    event DaoTreasuryChanged(address dao);
    event AaveProviderChanged(address provider);

    // Exención AUM: primeros 1000 usuarios
    uint256 public uniqueUserCount;
    mapping(address => bool) public isFeeExemptUser;
    function setFeeExempt(address user, bool exempt) external onlyRole(RISK_ADMIN_ROLE) {
        isFeeExemptUser[user] = exempt;
    }

    struct Position {
        address asset;            // ERC-20 (USDC/WETH/WBTC/...)
        address owner;
        uint128 principalVault;   // saldo local (no Aave)
        uint128 principalAave;    // saldo depositado en Aave
        uint32  start;
        uint32  unlockAt;         // sin early withdraw
        uint32  lastFeeAccruedAt; // para AUM
        bool    withdrawn;
    }

    mapping(address => uint32) public firstDepositAt;
    uint256 public nextId;
    mapping(uint256 => Position) public positions;

    // Beneficiarios por posición
    mapping(uint256 => address) public beneficiaryOf;
    mapping(uint256 => bytes32) public beneficiaryEnsHash;

    // Eventos
    event Deposited(uint256 indexed id, address indexed owner, address indexed asset, uint256 amount, uint32 unlockAt);
    event AumAccrued(uint256 indexed id, uint256 amount);
    event WithdrawalFeeCharged(uint256 indexed id, uint256 amount);
    event RebalancedToAave(address indexed user, uint256[] ids, uint256 moved);
    event BeneficiarySet(uint256 indexed id, address indexed beneficiary, bytes32 ensNamehash);
    event RolloverExecuted(uint256 indexed id, uint32 newUnlockAt);

    constructor(address admin, address _daoTreasury) {
        require(admin != address(0) && _daoTreasury != address(0), "bad init");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RISK_ADMIN_ROLE, admin);
        daoTreasury = _daoTreasury;
    }

    // --- Admin ---
    function setDaoTreasury(address a) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(a != address(0), "zero");
        daoTreasury = a;
        emit DaoTreasuryChanged(a);
    }

    function setAaveProvider(IPoolAddressesProvider p) external onlyRole(RISK_ADMIN_ROLE) {
        aaveProvider = p;
        aavePool = IPool(p.getPool());
        emit AaveProviderChanged(address(p));
    }

    function listAsset(address asset, uint256 minDeposit, bool allowed) external onlyRole(RISK_ADMIN_ROLE) {
        require(asset != address(0), "asset=0");
        minDepositByAsset[asset] = minDeposit;
        isAssetAllowed[asset] = allowed;
        emit AssetListed(asset, minDeposit, allowed);
    }

    function pause() external onlyRole(RISK_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(RISK_ADMIN_ROLE) { _unpause(); }

    // --- Core ---
    function deposit(address asset, uint256 amount, uint32 unlockAt) external nonReentrant whenNotPaused {
        require(isAssetAllowed[asset], "asset not allowed");
        require(amount >= minDepositByAsset[asset], "min deposit");
        require(unlockAt >= block.timestamp + MIN_LOCK, "lock >=10y");

        uint256 id = ++nextId;

        positions[id] = Position({
            asset: asset,
            owner: msg.sender,
            principalVault: uint128(amount),
            principalAave: 0,
            start: uint32(block.timestamp),
            unlockAt: unlockAt,
            lastFeeAccruedAt: uint32(block.timestamp),
            withdrawn: false
        });

        if (firstDepositAt[msg.sender] == 0) {
            firstDepositAt[msg.sender] = uint32(block.timestamp);
            if (!isFeeExemptUser[msg.sender] && uniqueUserCount < 1000) {
                isFeeExemptUser[msg.sender] = true; // exención permanente
                uniqueUserCount++;
            }
        }

        require(IERC20(asset).transferFrom(msg.sender, address(this), amount), "transferFrom");
        emit Deposited(id, msg.sender, asset, amount, unlockAt);
    }

    function _accrueAum(uint256 id) internal returns (uint256 fee) {
        Position storage p = positions[id];
        if (p.withdrawn) return 0;

        if (isFeeExemptUser[p.owner] || mgmtFeeYearBps == 0) {
            p.lastFeeAccruedAt = uint32(block.timestamp);
            return 0;
        }

        uint32 last = p.lastFeeAccruedAt;
        if (last == 0 || last >= block.timestamp) return 0;

        uint256 dt = uint256(block.timestamp - last); // seg
        uint256 baseAmt = uint256(p.principalVault);
        fee = baseAmt * mgmtFeeYearBps * dt / 10_000 / 365 days;

        if (fee > 0 && fee <= p.principalVault) {
            unchecked { p.principalVault -= uint128(fee); }
            require(IERC20(p.asset).transfer(daoTreasury, fee), "aum xfer");
            emit AumAccrued(id, fee);
        }
        p.lastFeeAccruedAt = uint32(block.timestamp);
    }

    function rebalanceToAave(uint256[] calldata ids) external nonReentrant whenNotPaused {
        require(address(aavePool) != address(0), "no aave");
        require(firstDepositAt[msg.sender] != 0, "no first deposit");
        require(block.timestamp - firstDepositAt[msg.sender] >= 180 days, "not due");

        uint256 totalToMove;
        address asset0;
        for (uint i = 0; i < ids.length; i++) {
            Position storage p = positions[ids[i]];
            require(p.owner == msg.sender && !p.withdrawn, "bad pos");
            _accrueAum(ids[i]);

            if (i == 0) { asset0 = p.asset; } 
            else { require(p.asset == asset0, "mixed assets"); }

            uint256 half = uint256(p.principalVault) / 2;
            if (half == 0) continue;
            p.principalVault -= uint128(half);
            p.principalAave  += uint128(half);
            totalToMove += half;
        }
        if (totalToMove > 0) {
            IERC20(asset0).approve(address(aavePool), totalToMove);
            aavePool.supply(asset0, totalToMove, address(this), 0);
        }
        emit RebalancedToAave(msg.sender, ids, totalToMove);
    }

    /// @notice Retiro al vencimiento (3% fee). No hay retiros anticipados.
    function withdraw(uint256 id) external nonReentrant whenNotPaused {
        Position storage p = positions[id];
        require(p.owner == msg.sender && !p.withdrawn, "bad pos");
        require(block.timestamp >= p.unlockAt, "locked");

        _accrueAum(id);
        p.withdrawn = true;

        // Recupera de Aave si corresponde
        uint256 fromAave = uint256(p.principalAave);
        if (fromAave > 0) {
            uint256 got = aavePool.withdraw(p.asset, fromAave, address(this));
            p.principalVault += uint128(got);
            p.principalAave = 0;
        }

        uint256 amt = uint256(p.principalVault);
        p.principalVault = 0;

        uint256 wFee = amt * withdrawFeeBps / 10_000;
        uint256 net  = amt - wFee;

        if (wFee > 0) require(IERC20(p.asset).transfer(daoTreasury, wFee), "wfee xfer");
        require(IERC20(p.asset).transfer(msg.sender, net), "net xfer");

        emit WithdrawalFeeCharged(id, wFee);
    }

    /// ---------------------
    /// NUEVAS FEATURES
    /// ---------------------

    /// @notice Define beneficiario (y ENS namehash opcional) para una posición.
    function setBeneficiary(uint256 id, address who, bytes32 ensNamehash) external {
        Position storage p = positions[id];
        require(p.owner == msg.sender, "not owner");
        require(!p.withdrawn, "withdrawn");
        beneficiaryOf[id] = who;
        beneficiaryEnsHash[id] = ensNamehash;
        emit BeneficiarySet(id, who, ensNamehash);
    }

    /// @notice Extiende el lock de una posición por +10 años (rollover total).
    function rolloverPosition(uint256 id) external {
        Position storage p = positions[id];
        require(p.owner == msg.sender, "not owner");
        require(!p.withdrawn, "withdrawn");
        require(block.timestamp >= p.unlockAt, "not matured");
        _accrueAum(id);
        unchecked { p.unlockAt = p.unlockAt + MIN_LOCK; }
        emit RolloverExecuted(id, p.unlockAt);
    }
}
