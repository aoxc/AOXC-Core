// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/**
 * @title AOXC Sovereign Core V2.0.0
 * @notice Production-hardened 26-Layer Defense Token.
 */
contract AOXC is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        V1 STORAGE PRESERVATION
    //////////////////////////////////////////////////////////////*/

    // Upgradeability güvenliği için eski storage düzeni korunmuştur.
    uint256 private _v1M1;
    uint256 private _v1M2;
    uint256 private _v1M3;
    uint256 private _v1M4;
    uint256 private _v1M5;
    mapping(address => bool) private _v1Map1;
    mapping(address => string) private _v1Map2;
    mapping(address => bool) private _v1Map3;
    mapping(address => uint256) private _v1Map4;
    mapping(address => uint256) private _v1Map5;
    uint256[43] private _gap;

    /*//////////////////////////////////////////////////////////////
                        V2 NAMESPACED STORAGE
    //////////////////////////////////////////////////////////////*/

    struct CoreStorage {
        address xLayerSentinel;
        uint256 yearlyMintLimit;
        uint256 lastMintTimestamp;
        uint256 mintedThisYear;
        uint256 supplyAtStartOfYear;
        mapping(address => uint256) lastActionBlock;
        mapping(address => bool) liquidityPools;
        bool initializationLocked;
    }

    // Keccak256 hash of "aoxc.storage.v2"
    bytes32 private constant CORE_STORAGE_SLOT = 0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;

    function _getCoreStorage() internal pure returns (CoreStorage storage $) {
        assembly {
            $.slot := CORE_STORAGE_SLOT
        }
    }

    event SentinelMigrated(address indexed oldSentinel, address indexed newSentinel);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeV2(address _sentinel, address _admin) external reinitializer(2) {
        if (_admin == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        CoreStorage storage $ = _getCoreStorage();

        if (!$.initializationLocked) {
            __ERC20_init_unchained("AOXC", "AOXC");
            __ERC20Burnable_init_unchained();
            __ERC20Pausable_init_unchained();
            __AccessControl_init_unchained();
            __ERC20Permit_init_unchained("AOXC");
            __ERC20Votes_init_unchained();
            __ReentrancyGuard_init_unchained();
            $.initializationLocked = true;
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, _admin);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, _admin);

        $.xLayerSentinel = _sentinel;
        $.lastMintTimestamp = block.timestamp;

        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) {
            _mint(_admin, AOXCConstants.INITIAL_SUPPLY);
            $.supplyAtStartOfYear = AOXCConstants.INITIAL_SUPPLY;
        } else {
            $.supplyAtStartOfYear = currentSupply;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTIVE DEFENSE ENGINE
    //////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        CoreStorage storage $ = _getCoreStorage();

        if (paused()) revert AOXCErrors.AOXC_GlobalLockActive();

        // Transactional Validation
        if (from != address(0) && to != address(0) && !hasRole(DEFAULT_ADMIN_ROLE, from)) {
            // Layer 9: Anti-Flashloan (Temporal Breach)
            if ($.lastActionBlock[from] == block.number) {
                revert AOXCErrors.AOXC_TemporalBreach(block.number, block.number);
            }
            $.lastActionBlock[from] = block.number;

            // Layer 10-12: Neural Sentinel Validation
            if ($.xLayerSentinel != address(0) && $.xLayerSentinel.code.length > 0) {
                (bool success, bytes memory data) =
                    $.xLayerSentinel.staticcall(abi.encodeWithSignature("isAllowed(address,address)", from, to));

                if (!success || data.length < 32 || !abi.decode(data, (bool))) {
                    revert AOXCErrors.AOXC_Neural_BastionSealed(block.timestamp);
                }
            }

            // Layer 14: Magnitude Guard (Whale Protection - %2 limit)
            uint256 txLimit = (totalSupply() * 200) / 10000;
            if (amount > txLimit) revert AOXCErrors.AOXC_ExceedsMaxTransfer(amount, txLimit);
        }

        super._update(from, to, amount);
    }

    /**
     * @notice Minting function with inflation hardcap.
     */
    function mint(address to, uint256 amount) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) nonReentrant {
        CoreStorage storage $ = _getCoreStorage();

        // Yearly reset for minting limits
        if (block.timestamp >= $.lastMintTimestamp + 365 days) {
            $.lastMintTimestamp = block.timestamp;
            $.mintedThisYear = 0;
            $.supplyAtStartOfYear = totalSupply();
        }

        uint256 baselineSupply = $.supplyAtStartOfYear;
        if (baselineSupply > 0) {
            uint256 annualCap = (baselineSupply * AOXCConstants.MAX_MINT_PER_YEAR_BPS) / AOXCConstants.BPS_DENOMINATOR;
            if ($.mintedThisYear + amount > annualCap) {
                revert AOXCErrors.AOXC_InflationHardcapReached();
            }
        }

        $.mintedThisYear += amount;
        _mint(to, amount);
    }

    function getSentinel() external view returns (address) {
        return _getCoreStorage().xLayerSentinel;
    }

    function _authorizeUpgrade(address) internal view override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function pause() external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _unpause();
    }
}
