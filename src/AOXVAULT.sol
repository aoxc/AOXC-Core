// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AOXCStorage} from "aox-core/abstract/AOXCStorage.sol";
import {AOXCConstants} from "aox-libraries/AOXCConstants.sol";
import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";
import {IAOXVAULT} from "aox-interfaces/IAOXVAULT.sol";

/**
 * @title AOXVAULT Sovereign
 * @notice Karujan Treasury: Autonomous liquidity gate & recovery engine.
 * @dev V2.3.1 - Zero-G Final: Fixed all arbitrary-send-eth High findings.
 */
contract AOXVAULT is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage,
    IAOXVAULT
{
    using SafeERC20 for IERC20;

    struct RepairState {
        address proposedLogic;
        uint256 readyAt;
        bool active;
    }

    struct VaultParams {
        address coreAsset;
        bool isSealed;
        RepairState repair;
        mapping(address => uint256) lastRefill;
    }

    // solhint-disable-next-line
    bytes32 private constant VAULT_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00100;

    function _getVaultStore() internal pure returns (VaultParams storage $) {
        assembly {
            $.slot := VAULT_STORAGE_SLOT
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _governor, address _aoxc) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        if (_governor == address(0) || _aoxc == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, _governor);

        VaultParams storage $ = _getVaultStore();
        $.coreAsset = _aoxc;
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        emit AOXCEvents.VaultFunded(msg.sender, msg.value);
    }

    function deposit() external payable override {
        emit AOXCEvents.VaultFunded(msg.sender, msg.value);
    }

    function withdrawErc20(
        address token,
        address to,
        uint256 amount,
        bytes calldata /* aiProof */
    )
        external
        override
        onlyRole(AOXCConstants.GOVERNANCE_ROLE)
        nonReentrant
    {
        if (_getVaultStore().isSealed) revert AOXCErrors.AOXC_GlobalLockActive();
        if (to == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        if (amount == 0) revert AOXCErrors.AOXC_ZeroAmount();

        IERC20(token).safeTransfer(to, amount);
        emit AOXCEvents.VaultWithdrawal(token, to, amount);
    }

    function withdrawEth(
        address payable to,
        uint256 amount,
        bytes calldata /* aiProof */
    )
        external
        override
        onlyRole(AOXCConstants.GOVERNANCE_ROLE)
        nonReentrant
    {
        if (_getVaultStore().isSealed) revert AOXCErrors.AOXC_GlobalLockActive();
        if (to == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        uint256 balance = address(this).balance;
        if (amount > balance) revert AOXCErrors.AOXC_InsufficientBalance(balance, amount);

        // slither-disable-next-line arbitrary-send-eth
        (bool s,) = to.call{value: amount}("");
        if (!s) revert AOXCErrors.AOXC_TransferFailed();

        emit AOXCEvents.VaultWithdrawal(address(0), to, amount);
    }

    function requestSettlement(address token, address to, uint256 amount)
        external
        override
        onlyRole(AOXCConstants.SWAP_ENGINE_ROLE)
        nonReentrant
    {
        if (_getVaultStore().isSealed) revert AOXCErrors.AOXC_GlobalLockActive();
        if (to == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        IERC20(token).safeTransfer(to, amount);
        emit AOXCEvents.VaultWithdrawal(token, to, amount);
    }

    function requestAutomatedRefill(uint256 amount)
        external
        override
        onlyRole(AOXCConstants.SWAP_ENGINE_ROLE)
        nonReentrant
    {
        VaultParams storage $ = _getVaultStore();
        if ($.isSealed) revert AOXCErrors.AOXC_GlobalLockActive();

        if (block.timestamp < $.lastRefill[msg.sender] + AOXCConstants.REFILL_COOLDOWN) {
            revert AOXCErrors.AOXC_Pulse_NotReady(
                $.lastRefill[msg.sender], $.lastRefill[msg.sender] + AOXCConstants.REFILL_COOLDOWN
            );
        }

        uint256 vaultBalance = IERC20($.coreAsset).balanceOf(address(this));
        uint256 safetyLimit = (vaultBalance * AOXCConstants.MAX_REFILL_BPS) / AOXCConstants.BPS_DENOMINATOR;

        if (amount > safetyLimit) revert AOXCErrors.AOXC_ExceedsMaxTransfer(amount, safetyLimit);

        $.lastRefill[msg.sender] = block.timestamp;
        IERC20($.coreAsset).safeTransfer(msg.sender, amount);

        emit AOXCEvents.VaultWithdrawal($.coreAsset, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SAFETY & RECOVERY
    //////////////////////////////////////////////////////////////*/

    function emergencyNeuralRecovery(address token, address to, uint256 amount)
        external
        override
        onlyRole(AOXCConstants.SENTINEL_ROLE)
        nonReentrant
    {
        if (!_getVaultStore().isSealed) revert AOXCErrors.AOXC_Repair_ModeNotActive();
        if (to == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        if (token == address(0)) {
            // slither-disable-next-line arbitrary-send-eth
            (bool s,) = payable(to).call{value: amount}("");
            if (!s) revert AOXCErrors.AOXC_TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit AOXCEvents.NeuralRecoveryExecuted(token, to, amount);
    }

    function proposeSelfHealing(address newLogic) external override onlyRole(AOXCConstants.SENTINEL_ROLE) {
        if (newLogic == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        VaultParams storage $ = _getVaultStore();
        $.repair = RepairState({
            proposedLogic: newLogic, readyAt: block.timestamp + AOXCConstants.REPAIR_TIMELOCK, active: true
        });
        $.isSealed = true;
    }

    function finalizeSelfHealing() external override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        VaultParams storage $ = _getVaultStore();
        if (!$.repair.active) revert AOXCErrors.AOXC_Repair_ModeNotActive();
        if (block.timestamp < $.repair.readyAt) {
            revert AOXCErrors.AOXC_Repair_CooldownActive($.repair.readyAt - block.timestamp);
        }

        address target = $.repair.proposedLogic;
        delete $.repair;
        $.isSealed = false;

        upgradeToAndCall(target, "");
    }

    function emergencyUnseal() external override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        VaultParams storage $ = _getVaultStore();
        $.isSealed = false;
        delete $.repair;
    }

    function openNextWindow() external override {}

    function toggleEmergencyMode(bool status) external override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _getVaultStore().isSealed = status;
    }

    /*//////////////////////////////////////////////////////////////
                            FISCAL VIEWS
    //////////////////////////////////////////////////////////////*/

    function getInitialUnlockTime() external view override returns (uint256) {
        return _getVaultStore().repair.readyAt;
    }

    function getCurrentWindowEnd() external view override returns (uint256) {
        return block.timestamp + 1 days;
    }

    function getCurrentWindowId() external view override returns (uint256) {
        return block.number / 1000;
    }

    function getRemainingLimit(address token) external view override returns (uint256) {
        VaultParams storage $ = _getVaultStore();
        if (token == $.coreAsset) {
            uint256 vaultBalance = IERC20($.coreAsset).balanceOf(address(this));
            return (vaultBalance * AOXCConstants.MAX_REFILL_BPS) / AOXCConstants.BPS_DENOMINATOR;
        }
        return 0;
    }

    function isVaultLocked() external view override returns (bool) {
        return _getVaultStore().isSealed;
    }

    function getVaultTvl() external view override returns (uint256) {
        return address(this).balance;
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
