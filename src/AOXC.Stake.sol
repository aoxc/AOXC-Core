// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AOXCStorage } from "./abstract/AOXCStorage.sol";
import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

/**
 * @title AOXC Sovereign Staking V2.0.1
 * @notice Neural-Validated Staking with Algorithmic Reputation and Temporal Safeguards.
 * @dev [V2-FIX]: Fixed error naming conventions and storage alignment.
 */
contract AOXCStaking is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    AOXCStorage
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    event SovereignStakeInitiated(address indexed actor, uint256 amount, uint256 duration, uint256 index);
    event SovereignWithdrawalExecuted(address indexed actor, uint256 amount);
    event NeuralVerificationConfirmed(address indexed actor, uint256 userNonce);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address governor, address aiNode, address token) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        // [V2-FIX]: __UUPSUpgradeable_init() removed for OZ v5 compatibility

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, governor);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, governor);

        MainStorage storage main = _getMainStorage();
        StakingStorage storage stake = _getStakingStorage();

        if (main.lastNeuralPulse != 0) revert AOXCErrors.AOXC_CustomRevert("ALREADY_INIT");

        main.aiSentinelNode = aiNode;
        main.aoxcToken = token; // Storage V2.0.1 alignment
        main.lastNeuralPulse = block.timestamp;
        main.neuralPulseTimeout = AOXCConstants.AI_MAX_FREEZE_DURATION;

        stake.minimumStakeDuration = AOXCConstants.MIN_TIMELOCK_DELAY;
    }

    /*//////////////////////////////////////////////////////////////
                            STAKING LOGIC
    //////////////////////////////////////////////////////////////*/

    function stakeSovereign(uint256 amount, uint256 duration, bytes calldata proof)
        external
        nonReentrant
    {
        MainStorage storage main = _getMainStorage();
        StakingStorage storage stake = _getStakingStorage();

        // [V2-FIX]: Error naming aligned with AOXCErrors library convention
        if (main.isSovereignSealed) revert AOXCErrors.AOXC_GlobalLockActive();
        
        if (stake.lastActionBlock[msg.sender] == block.number) {
            revert AOXCErrors.AOXC_TemporalCollision();
        }

        if (duration < AOXCConstants.MIN_TIMELOCK_DELAY || duration > AOXCConstants.MAX_TIMELOCK_DELAY) {
            revert AOXCErrors.AOXC_InvalidLockTier(duration);
        }

        // Layer 17: Neural Verification
        _verifyNeuralPulse(main, amount, duration, proof);

        uint256 index = stake.userStakes[msg.sender].length;
        
        // Reputation Gain Calculation
        uint256 reputationGain = (amount * duration) / 1 days;
        main.userReputation[msg.sender] += reputationGain;

        stake.totalValueLocked += amount;
        stake.lastActionBlock[msg.sender] = block.number;

        stake.userStakes[msg.sender].push(
            StakePosition({
                amount: amount,
                startTime: block.timestamp,
                lockDuration: duration,
                active: true
            })
        );

        IERC20(main.aoxcToken).safeTransferFrom(msg.sender, address(this), amount);

        emit SovereignStakeInitiated(msg.sender, amount, duration, index);
    }

    function withdrawSovereign(uint256 index) external nonReentrant {
        StakingStorage storage stake = _getStakingStorage();
        MainStorage storage main = _getMainStorage();

        if (index >= stake.userStakes[msg.sender].length) {
            revert AOXCErrors.AOXC_CustomRevert("STAKE: INVALID_INDEX");
        }

        StakePosition storage pos = stake.userStakes[msg.sender][index];
        if (!pos.active) revert AOXCErrors.AOXC_StakeNotActive();

        if (block.timestamp < pos.startTime + pos.lockDuration) {
            revert AOXCErrors.AOXC_StakeStillLocked(block.timestamp, pos.startTime + pos.lockDuration);
        }

        uint256 amount = pos.amount;
        
        pos.active = false;
        pos.amount = 0;
        stake.totalValueLocked -= amount;

        IERC20(main.aoxcToken).safeTransfer(msg.sender, amount);

        emit SovereignWithdrawalExecuted(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL SECURITY
    //////////////////////////////////////////////////////////////*/

    function _verifyNeuralPulse(
        MainStorage storage main,
        uint256 amt,
        uint256 dur,
        bytes calldata sig
    ) internal {
        // [V2-FIX]: Aligned error name with library
        if (sig.length != 65) revert AOXCErrors.AOXC_Neural_IdentityForgery();
        
        uint256 nonce = main.neuralNonce;
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, amt, dur, nonce, address(this), block.chainid)
        ).toEthSignedMessageHash();

        if (msgHash.recover(sig) != main.aiSentinelNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        main.neuralNonce++;
        main.lastNeuralPulse = block.timestamp;
        
        emit NeuralVerificationConfirmed(msg.sender, main.neuralNonce);
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(AOXCConstants.GOVERNANCE_ROLE)
    {}
}
