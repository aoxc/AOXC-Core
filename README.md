# 🏛️ AOXC-Core | The Sovereign Engine (V1)

**AOXC-Core** is the foundational smart contract architecture of the AOXC ecosystem. This repository contains the **V1 Sovereign Token**, a high-integrity, upgradeable asset designed for the **X LAYER** ecosystem. 

It is built with a "Code as Constitution" philosophy, integrating advanced compliance, monetary velocity controls, and decentralized governance.

---

## 🔬 Core Specifications (V1)
The AOXC contract is not just a token; it is a regulated economic unit featuring:

* **Network:** Optimized for **X LAYER**.
* **Protocol:** UUPS Upgradeable (ERC1967).
* **Security:** Multi-Role Access Control (RBAC).
* **Standards:** ERC20, Burnable, Pausable, Permit, and Votes (Governance).

---

## 🛠️ Advanced Laboratory Features

### 1. Monetary Velocity Control
To ensure ecosystem stability, V1 implements transfer limits:
* **Max Transaction:** Hard-coded safety caps for single transfers.
* **Daily Velocity:** Rolling 24-hour limits per wallet to prevent flash-drain events.

### 2. Inflation & Minting Guard
* **Hard Cap:** Controlled inflation via `HARD_CAP_INFLATION_BPS`.
* **Yearly Threshold:** Minting is restricted by a yearly limit to ensure long-term value preservation.

### 3. Compliance & Safety
* **Blacklist Engine:** Integrated `COMPLIANCE_ROLE` to restrict malicious actors.
* **Rescue Mechanism:** Admin ability to rescue accidentally sent tokens (excluding native AOXC).

---

## 🧪 Technical Stack
* **Solidity Version:** `0.8.28`
* **Framework:** OpenZeppelin Upgradeable
* **Optimization:** Shanghai / X LAYER ZK-EVM compatible

---

## 🏗️ Development Status: V1 Lifecycle
This version (V1) serves as the **Genesis Core**. We are currently in the process of auditing and simulating the logic for the upcoming **V2 Evolution**. 

> **Research Note:** AOXC-Core maintains strict forensic logging for all `_update` cycles. Every movement is a recorded state in the sovereign history.

---

**[AOXC-CORE] orcun@ns1:~/AOXC-Core$** _System Status: **V1-STABLE** | Network: **X LAYER**_
