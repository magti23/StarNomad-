# 🌌 StarNomad Rewards Program

The **StarNomad Rewards Program** is a Clarity smart contract designed to incentivize long-term participation and engagement in a decentralized platform by rewarding users with loyalty tokens (**STELLAR-CREDITS**) based on their staking activity, commitment period, and status tier.

---

## 📜 Features

* **Staking with Commitment Options**: Stake STX tokens with optional time-based lock-in periods for additional reward bonuses.
* **Tiered Loyalty System**: Users earn multipliers based on total stake and commitment, moving through **Nova**, **Nebula**, and **Cosmic** tiers.
* **Harvesting Rewards**: Users can periodically harvest STELLAR-CREDITS based on their staking activity and tier bonuses.
* **Emergency & Platform Control**: Admin can suspend the platform or enable emergency mode if necessary.

---

## 🛠 Contract Components

### ### 📁 Tokens

* `STELLAR-CREDITS`: A fungible token minted as rewards for users.

### 🧾 Data Maps

* `ExplorerProfile`: Tracks user staking amount, accumulated rewards, tier level, and tier multipliers.
* `StakingContract`: Stores individual user stake details like amount, commitment duration, and harvest history.
* `StatusLevels`: Defines reward multipliers for various staking tiers (Nova, Nebula, Cosmic).

### ⚙️ Global Parameters

* `base-accrual-rate`: Default reward rate (5%).
* `loyalty-bonus`: Extra reward for commitment (1%).
* `minimum-participation`: Minimum amount required to stake.
* `credits-pool`: Tracks total staked in the contract.

---

## 🚀 Staking Tiers

| Tier   | Requirement       | Multiplier |
| ------ | ----------------- | ---------- |
| Nova   | ≥ 1,000,000 µSTX  | 1x         |
| Nebula | ≥ 5,000,000 µSTX  | 1.5x       |
| Cosmic | ≥ 10,000,000 µSTX | 2x         |

---

## ⏱ Commitment Bonuses

| Commitment Period        | Multiplier |
| ------------------------ | ---------- |
| None                     | 1.0x       |
| ≥ 1 month (4320 blocks)  | 1.25x      |
| ≥ 2 months (8640 blocks) | 1.5x       |

---

## 📦 Public Functions

### 🔹 `initialize-platform`

Sets up status tiers. Must be called once by the controller.

### 🔹 `stake-tokens (amount uint, duration uint)`

Stake tokens with an optional commitment period to gain rewards and tier bonuses.

### 🔹 `unstake-tokens (amount uint)`

Withdraw staked tokens after any lock period has passed.

### 🔹 `harvest-rewards`

Claim accumulated STELLAR-CREDITS based on staking history and multipliers.

### 🔹 `set-platform-status (suspended bool)`

Controller function to pause/resume the platform.

### 🔹 `set-emergency-mode (enabled bool)`

Controller function to enable/disable emergency mode for recovery or upgrades.

---

## ⚠️ Error Codes

| Code   | Description                 |
| ------ | --------------------------- |
| `6001` | Permission Denied           |
| `6002` | Destination Restricted      |
| `6003` | Invalid Token Amount        |
| `6004` | Insufficient Balance        |
| `6005` | Time Lock Active            |
| `6006` | User Not Registered         |
| `6007` | Minimum Requirement Not Met |
| `6008` | Platform Suspended          |

---

## 🔐 Access Control

* Only the **controller address** (`tx-sender` when the contract is deployed) can:

  * Initialize the platform
  * Toggle platform suspension
  * Enable emergency mode
