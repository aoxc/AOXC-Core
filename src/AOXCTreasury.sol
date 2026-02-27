// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IAOXCTreasury} from "./interfaces/IAOXCTreasury.sol";
import {AOXCStorage} from "./abstract/AOXCStorage.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

contract AOXCTreasury is
    IAOXCTreasury,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public constant ANNUAL_WITHDRAWAL_CAP_BPS = 600;
    uint256 public constant SIX_YEAR_CLIFF = 6 * 365 days;

    mapping(address => mapping(uint256 => uint256)) public windowWithdrawals;
    mapping(address => mapping(uint256 => uint256)) public windowStartBalance;

    uint256 public deploymentTimestamp;
    uint256 public override currentWindowId;
    uint256 public override currentWindowEnd;
    bool public override isEmergencyLocked;

    event DepositReceived(address indexed sender, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor, address upgrader, address aiNode, address aoxcTokenAddr)
        external
        initializer
    {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, upgrader);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, governor);

        MainStorage storage $ = _getMainStorage();
        $.aiSentinelNode = aiNode;
        $.aoxcToken = aoxcTokenAddr;
        $.lastNeuralPulse = block.timestamp;
        $.neuralPulseTimeout = AOXCConstants.AI_MAX_FREEZE_DURATION;

        deploymentTimestamp = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSITS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    function deposit() public payable override {
        emit DepositReceived(msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function withdrawErc20(address token, address to, uint256 amount, bytes calldata aiSignature)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        _checkLivenessAndLimits(token, amount, aiSignature);

        windowWithdrawals[token][currentWindowId] += amount;
        IERC20(token).safeTransfer(to, amount);

        emit FundsWithdrawn(token, to, amount);
    }

    function withdrawEth(address payable to, uint256 amount, bytes calldata aiSignature)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        _checkLivenessAndLimits(address(0), amount, aiSignature);

        windowWithdrawals[address(0)][currentWindowId] += amount;

        (bool success,) = to.call{value: amount}("");
        if (!success) revert AOXCErrors.AOXC_CustomRevert("Treasury: ETH_FAIL");

        emit FundsWithdrawn(address(0), to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          WINDOW MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function openNextWindow() external override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        if (block.timestamp < initialUnlockTimestamp()) {
            revert AOXCErrors.AOXC_CustomRevert("Treasury: CLIFF_ACTIVE");
        }

        if (block.timestamp < currentWindowEnd) {
            revert AOXCErrors.AOXC_CustomRevert("Treasury: WINDOW_OPEN");
        }

        currentWindowId++;
        currentWindowEnd = block.timestamp + 365 days;

        MainStorage storage $ = _getMainStorage();

        if ($.aoxcToken != address(0)) {
            windowStartBalance[$.aoxcToken][currentWindowId] = IERC20($.aoxcToken).balanceOf(address(this));
        }

        windowStartBalance[address(0)][currentWindowId] = address(this).balance;

        emit WindowOpened(currentWindowId, currentWindowEnd);
    }

    function toggleEmergencyMode(bool status) external override onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        isEmergencyLocked = status;
        emit EmergencyModeToggled(status);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL GUARDS
    //////////////////////////////////////////////////////////////*/

    function _checkLivenessAndLimits(address token, uint256 amount, bytes calldata sig) internal {
        if (isEmergencyLocked) {
            revert AOXCErrors.AOXC_CustomRevert("Treasury: EMERGENCY_LOCK");
        }

        if (block.timestamp > currentWindowEnd) {
            revert AOXCErrors.AOXC_CustomRevert("Treasury: WINDOW_EXPIRED");
        }

        uint256 limit = getRemainingLimit(token);

        if (amount > limit) {
            revert AOXCErrors.AOXC_MagnitudeLimitExceeded(ANNUAL_WITHDRAWAL_CAP_BPS, 10000);
        }

        uint256 referenceBalance = windowStartBalance[token][currentWindowId];

        if (referenceBalance > 0 && amount > (referenceBalance / 100)) {
            _verifyAiSignature(token, amount, sig);
            MainStorage storage $ = _getMainStorage();
            $.neuralNonce++;
        }
    }

    function _verifyAiSignature(address token, uint256 amount, bytes calldata sig) internal view {
        MainStorage storage $ = _getMainStorage();

        bytes32 msgHash =
            keccak256(abi.encode(token, amount, $.neuralNonce, address(this), block.chainid)).toEthSignedMessageHash();

        if (msgHash.recover(sig) != $.aiSentinelNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function initialUnlockTimestamp() public view override returns (uint256) {
        return deploymentTimestamp + SIX_YEAR_CLIFF;
    }

    function getRemainingLimit(address token) public view override returns (uint256) {
        uint256 startBalance = windowStartBalance[token][currentWindowId];

        if (startBalance == 0) return 0;

        uint256 totalAllowance = (startBalance * ANNUAL_WITHDRAWAL_CAP_BPS) / 10000;

        uint256 spent = windowWithdrawals[token][currentWindowId];

        return spent >= totalAllowance ? 0 : totalAllowance - spent;
    }

    function getSovereignTvl() external view override returns (uint256) {
        return address(this).balance;
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
