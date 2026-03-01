// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCStorage} from "./abstract/AOXCStorage.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

/**
 * @notice External vault interface for yield settlement
 */
interface IVault {
    function requestSettlement(address token, address to, uint256 amount) external;
}

/**
 * @title AOXCPEX Sovereign
 * @notice Otonom Staking ve Pozisyon Motoru.
 * @dev V2.1.8 - Hardened & Optimized (0 Lint).
 */
contract AOXCPEX is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, AOXCStorage {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionInitiated(address indexed actor, uint256 amount, uint256 duration, uint256 index);
    event PositionClosed(address indexed actor, uint256 principal, uint256 yield);
    event EmergencyExitExecuted(address indexed actor, uint256 returned, uint256 penalty);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev ONARIM: Unwrapped logic uyarısı giderildi.
     * Mantık internal fonksiyona taşınarak byte-code boyutu küçültüldü.
     */
    modifier onlyDao() {
        _checkDao();
        _;
    }

    function _checkDao() internal view {
        if (msg.sender != address(this) && !hasRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender)) {
            revert AOXCErrors.AOXC_Unauthorized(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice AOXCPEX V2 Başlatıcı
     */
    function initialize(address nexus, address aiNode, address token) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, nexus);

        MainStorage storage main = _getMainStorage();
        StakingStorage storage stake = _getStakingStorage();

        main.neuralSentinelNode = aiNode;
        main.coreAssetToken = token;
        main.lastPulseTimestamp = block.timestamp;

        stake.baseYieldRateBps = AOXCConstants.STAKING_REWARD_APR_BPS;
        stake.attritionPenaltyBps = AOXCConstants.ATTRITION_PENALTY_BPS;
        stake.minLockdownDuration = AOXCConstants.MIN_STAKE_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                        STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function openPosition(uint256 amount, uint256 duration, bytes calldata aiProof) external nonReentrant {
        MainStorage storage main = _getMainStorage();
        StakingStorage storage stake = _getStakingStorage();

        if (main.isSovereignVaultSealed) revert AOXCErrors.AOXC_GlobalLockActive();
        if (duration < stake.minLockdownDuration) revert AOXCErrors.AOXC_CustomRevert("STAKE: LOW_DURATION");

        _verifyNeuralIntegrity(amount, duration, aiProof);

        uint256 index = stake.accountPositions[msg.sender].length;
        stake.totalValueLocked += amount;

        stake.accountPositions[msg.sender].push(
            StakePosition({principal: amount, entryTimestamp: block.timestamp, lockPeriod: duration, isActive: true})
        );

        IERC20(main.coreAssetToken).safeTransferFrom(msg.sender, address(this), amount);
        emit PositionInitiated(msg.sender, amount, duration, index);
    }

    function closePosition(uint256 index) external nonReentrant {
        StakingStorage storage stake = _getStakingStorage();
        MainStorage storage main = _getMainStorage();

        _validateIndex(index);
        StakePosition storage pos = stake.accountPositions[msg.sender][index];

        if (block.timestamp < pos.entryTimestamp + pos.lockPeriod) {
            revert AOXCErrors.AOXC_StakeStillLocked(block.timestamp, pos.entryTimestamp + pos.lockPeriod);
        }

        uint256 principal = pos.principal;
        uint256 yield =
            (principal * pos.lockPeriod * stake.baseYieldRateBps) / (365 days * AOXCConstants.BPS_DENOMINATOR);

        pos.isActive = false;
        pos.principal = 0;
        stake.totalValueLocked -= principal;

        IERC20(main.coreAssetToken).safeTransfer(msg.sender, principal);

        if (yield > 0 && main.treasury != address(0)) {
            IVault(main.treasury).requestSettlement(main.coreAssetToken, msg.sender, yield);
        }

        emit PositionClosed(msg.sender, principal, yield);
    }

    function emergencyExit(uint256 index) external nonReentrant {
        StakingStorage storage stake = _getStakingStorage();
        MainStorage storage main = _getMainStorage();

        _validateIndex(index);
        StakePosition storage pos = stake.accountPositions[msg.sender][index];

        uint256 principal = pos.principal;
        uint256 penalty = (principal * stake.attritionPenaltyBps) / AOXCConstants.BPS_DENOMINATOR;
        uint256 returned = principal - penalty;

        pos.isActive = false;
        pos.principal = 0;
        stake.totalValueLocked -= principal;

        IERC20(main.coreAssetToken).safeTransfer(msg.sender, returned);

        emit EmergencyExitExecuted(msg.sender, returned, penalty);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _verifyNeuralIntegrity(uint256 amt, uint256 dur, bytes calldata sig) internal {
        MainStorage storage main = _getMainStorage();
        bytes32 msgHash = keccak256(
                abi.encode(msg.sender, amt, dur, main.operationalNonce, address(this), block.chainid)
            ).toEthSignedMessageHash();

        if (msgHash.recover(sig) != main.neuralSentinelNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        unchecked {
            main.operationalNonce++;
        }
    }

    function _validateIndex(uint256 index) internal view {
        StakingStorage storage stake = _getStakingStorage();
        if (index >= stake.accountPositions[msg.sender].length) revert AOXCErrors.AOXC_CustomRevert("STAKE: OOB");
        if (!stake.accountPositions[msg.sender][index].isActive) revert AOXCErrors.AOXC_StakeNotActive();
    }

    function _authorizeUpgrade(address) internal override onlyDao {}
}
