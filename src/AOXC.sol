// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

/**
 * @title AOXC Token
 * @notice Modern, Secure and Centralized Compliance Token
 */
contract AOXC is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE   = keccak256("UPGRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE"); 

    uint256 public constant INITIAL_SUPPLY         = 100_000_000_000 * 1e18;
    uint256 public constant YEAR_SECONDS           = 365 days;
    uint256 public constant HARD_CAP_INFLATION_BPS = 600;

    uint256 public yearlyMintLimit;
    uint256 public lastMintTimestamp;
    uint256 public mintedThisYear;
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;

    mapping(address => bool) private _blacklisted;
    mapping(address => string) public blacklistReason; 
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastTransferDay;

    event Blacklisted(address indexed account, string reason);
    event Unblacklisted(address indexed account);
    event MonetaryLimitsUpdated(uint256 maxTx, uint256 dailyLimit);
    event FundsRescued(address indexed token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor) external initializer {
        require(governor != address(0), "AOXC: Zero Addr");

        __ERC20_init("AOXC", "AOXC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("AOXC");
        __ERC20Votes_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(PAUSER_ROLE, governor);
        _grantRole(MINTER_ROLE, governor);
        _grantRole(UPGRADER_ROLE, governor);
        _grantRole(COMPLIANCE_ROLE, governor);

        yearlyMintLimit = (INITIAL_SUPPLY * HARD_CAP_INFLATION_BPS) / 10000;
        lastMintTimestamp = block.timestamp;
        
        maxTransferAmount = 500_000_000 * 1e18; 
        dailyTransferLimit = 1_000_000_000 * 1e18;

        isExcludedFromLimits[governor] = true;
        isExcludedFromLimits[address(this)] = true;

        _mint(governor, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(!_blacklisted[to], "AOXC: Blacklisted");

        if (block.timestamp >= lastMintTimestamp + YEAR_SECONDS) {
            uint256 periods = (block.timestamp - lastMintTimestamp) / YEAR_SECONDS;
            lastMintTimestamp += periods * YEAR_SECONDS;
            mintedThisYear = 0;
        }

        require(mintedThisYear + amount <= yearlyMintLimit, "AOXC: Inflation");
        require(totalSupply() + amount <= INITIAL_SUPPLY * 3, "AOXC: Cap");

        mintedThisYear += amount;
        _mint(to, amount);
    }

    function rescueERC20(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(this), "AOXC: Native");
        (bool s, bytes memory d) = token.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, amount));
        require(s && (d.length == 0 || abi.decode(d, (bool))), "AOXC: Failed");
        emit FundsRescued(token, amount);
    }

    function addToBlacklist(address account, string calldata reason) external onlyRole(COMPLIANCE_ROLE) {
        require(!hasRole(DEFAULT_ADMIN_ROLE, account), "AOXC: Admin Immunity");
        _blacklisted[account] = true;
        blacklistReason[account] = reason;
        emit Blacklisted(account, reason);
    }

    function removeFromBlacklist(address account) external onlyRole(COMPLIANCE_ROLE) {
        _blacklisted[account] = false;
        delete blacklistReason[account];
        emit Unblacklisted(account);
    }

    function setExclusionFromLimits(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isExcludedFromLimits[account] = status;
    }

    function setTransferVelocity(uint256 _max, uint256 _daily) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTransferAmount = _max;
        dailyTransferLimit = _daily;
        emit MonetaryLimitsUpdated(_max, _daily);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    function _update(address from, address to, uint256 val)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        if (from != address(0)) require(!_blacklisted[from], "AOXC: BL Sender");
        if (to != address(0)) require(!_blacklisted[to], "AOXC: BL Recipient");

        if (from != address(0) && to != address(0) && !isExcludedFromLimits[from]) {
            require(val <= maxTransferAmount, "AOXC: MaxTX");
            uint256 day = block.timestamp / 1 days;
            if (lastTransferDay[from] != day) {
                dailySpent[from] = 0;
                lastTransferDay[from] = day;
            }
            require(dailySpent[from] + val <= dailyTransferLimit, "AOXC: DailyLimit");
            dailySpent[from] += val;
        }
        super._update(from, to, val);
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    uint256[43] private _gap; 
}
