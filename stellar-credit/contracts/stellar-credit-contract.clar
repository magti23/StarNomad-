;; StarNomad Rewards Program - Version 2 (Enhanced)

;; Base Constants
(define-constant controller-address tx-sender)
(define-constant ERR-PERMISSION-DENIED (err u6001))
(define-constant ERR-DESTINATION-RESTRICTED (err u6002))
(define-constant ERR-TOKEN-AMOUNT-INVALID (err u6003))
(define-constant ERR-BALANCE-TOO-LOW (err u6004))
(define-constant ERR-TIME-RESTRICTION-ACTIVE (err u6005))
(define-constant ERR-USER-NOT-REGISTERED (err u6006))
(define-constant ERR-MINIMUM-REQUIREMENT-UNMET (err u6007))
(define-constant ERR-PLATFORM-SUSPENDED (err u6008))

;; Loyalty Token Implementation
(define-fungible-token STELLAR-CREDITS)

;; Platform Status Variables
(define-data-var platform-suspended bool false)
(define-data-var emergency-mode bool false)

;; System Parameters
(define-data-var credits-pool uint u0)
(define-data-var base-accrual-rate uint u500) ;; 5% base rate (100 = 1%)
(define-data-var loyalty-bonus uint u100) ;; 1% bonus for extended commitment
(define-data-var minimum-participation uint u1000000) ;; Minimum participation threshold

;; User Data Structures
(define-map ExplorerProfile
    principal
    {
        staked-amount: uint,
        accumulated-credits: uint,
        last-interaction: uint,
        status-tier: uint,
        tier-multiplier: uint
    }
)

(define-map StakingContract
    principal
    {
        amount: uint,
        inception-block: uint,
        recent-harvest: uint,
        commitment-period: uint
    }
)

(define-map StatusLevels
    uint  ;; tier level
    {
        tier-requirement: uint,
        reward-multiplier: uint
    }
)

;; System Initialization
(define-public (initialize-platform)
    (begin
        (asserts! (is-eq tx-sender controller-address) ERR-PERMISSION-DENIED)
        
        ;; Configure status tiers
        (map-set StatusLevels u1 
            {
                tier-requirement: u1000000,  ;; 1M micro-units
                reward-multiplier: u100      ;; 1x base
            })
        (map-set StatusLevels u2
            {
                tier-requirement: u5000000,  ;; 5M micro-units
                reward-multiplier: u150      ;; 1.5x base
            })
        (map-set StatusLevels u3
            {
                tier-requirement: u10000000, ;; 10M micro-units
                reward-multiplier: u200      ;; 2x base
            })
        
        (ok true)
    )
)

;; Stake tokens with optional time commitment
(define-public (stake-tokens (amount uint) (duration uint))
    (let
        (
            (explorer-data (default-to 
                {
                    staked-amount: u0,
                    accumulated-credits: u0,
                    last-interaction: u0,
                    status-tier: u0,
                    tier-multiplier: u100
                }
                (map-get? ExplorerProfile tx-sender)))
        )
        (asserts! (not (var-get platform-suspended)) ERR-PLATFORM-SUSPENDED)
        (asserts! (>= amount (var-get minimum-participation)) ERR-MINIMUM-REQUIREMENT-UNMET)
        
        ;; Transfer tokens to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Calculate status tier and applicable bonuses
        (let
            (
                (new-total-staked (+ (get staked-amount explorer-data) amount))
                (tier-level (calculate-status-tier new-total-staked))
                (duration-bonus (determine-duration-bonus duration))
            )
            
            ;; Update staking details
            (map-set StakingContract
                tx-sender
                {
                    amount: amount,
                    inception-block: block-height,
                    recent-harvest: block-height,
                    commitment-period: duration
                }
            )
            
            ;; Update explorer profile with new tier information
            (map-set ExplorerProfile
                tx-sender
                (merge explorer-data
                    {
                        staked-amount: new-total-staked,
                        status-tier: tier-level,
                        tier-multiplier: (* (tier-bonus tier-level) duration-bonus),
                        last-interaction: block-height
                    }
                )
            )
            
            ;; Update program reserves
            (var-set credits-pool (+ (var-get credits-pool) amount))
            (ok true)
        )
    )
)

;; Unstake tokens
(define-public (unstake-tokens (amount uint))
    (let
        (
            (explorer-data (default-to 
                {
                    staked-amount: u0,
                    accumulated-credits: u0,
                    last-interaction: u0,
                    status-tier: u0,
                    tier-multiplier: u100
                }
                (map-get? ExplorerProfile tx-sender)))
            (staking-info (default-to
                {
                    amount: u0,
                    inception-block: u0,
                    recent-harvest: u0,
                    commitment-period: u0
                }
                (map-get? StakingContract tx-sender)))
            (current-staked (get staked-amount explorer-data))
            (lock-period (get commitment-period staking-info))
        )
        (asserts! (not (var-get platform-suspended)) ERR-PLATFORM-SUSPENDED)
        (asserts! (<= amount current-staked) ERR-BALANCE-TOO-LOW)
        
        ;; Verify commitment period has elapsed
        (asserts! (<= (+ (get inception-block staking-info) lock-period) block-height) ERR-TIME-RESTRICTION-ACTIVE)
        
        ;; Transfer tokens from contract
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        ;; Recalculate tier after withdrawal
        (let
            (
                (new-total-staked (- current-staked amount))
                (tier-level (calculate-status-tier new-total-staked))
            )
            
            ;; Update explorer profile with adjusted tier data
            (map-set ExplorerProfile
                tx-sender
                (merge explorer-data
                    {
                        staked-amount: new-total-staked,
                        status-tier: tier-level,
                        tier-multiplier: (tier-bonus tier-level),
                        last-interaction: block-height
                    }
                )
            )
            
            ;; Update program reserves
            (var-set credits-pool (- (var-get credits-pool) amount))
            (ok true)
        )
    )
)

;; Harvest rewards based on staked amount
(define-public (harvest-rewards)
    (let
        (
            (explorer-data (default-to 
                {
                    staked-amount: u0,
                    accumulated-credits: u0,
                    last-interaction: u0,
                    status-tier: u0,
                    tier-multiplier: u100
                }
                (map-get? ExplorerProfile tx-sender)))
            (staking-info (default-to
                {
                    amount: u0,
                    inception-block: u0,
                    recent-harvest: u0,
                    commitment-period: u0
                }
                (map-get? StakingContract tx-sender)))
            (elapsed-blocks (- block-height (get recent-harvest staking-info)))
            (staked-amount (get staked-amount explorer-data))
            (bonus-rate (get tier-multiplier explorer-data))
        )
        (asserts! (> staked-amount u0) ERR-BALANCE-TOO-LOW)
        
        ;; Calculate earned rewards
        (let
            (
                (base-credits (/ (* staked-amount elapsed-blocks (var-get base-accrual-rate)) u1000000))
                (adjusted-credits (/ (* base-credits bonus-rate) u100))
            )
            
            ;; Mint reward tokens
            (try! (ft-mint? STELLAR-CREDITS adjusted-credits tx-sender))
            
            ;; Update staking record
            (map-set StakingContract
                tx-sender
                (merge staking-info
                    {
                        recent-harvest: block-height
                    }
                )
            )
            
            ;; Update explorer profile
            (map-set ExplorerProfile
                tx-sender
                (merge explorer-data
                    {
                        accumulated-credits: (+ (get accumulated-credits explorer-data) adjusted-credits),
                        last-interaction: block-height
                    }
                )
            )
            
            (ok adjusted-credits)
        )
    )
)

;; Helper Functions

;; Calculate status tier based on staked amount
(define-private (calculate-status-tier (stake-value uint))
    (if (>= stake-value u10000000)
        u3  ;; Cosmic tier
        (if (>= stake-value u5000000)
            u2  ;; Nebula tier
            u1  ;; Nova tier
        )
    )
)

;; Get tier-specific bonus multiplier
(define-private (tier-bonus (tier uint))
    (if (is-eq tier u3)
        u200  ;; Cosmic 2x
        (if (is-eq tier u2)
            u150  ;; Nebula 1.5x
            u100  ;; Nova 1x
        )
    )
)

;; Calculate duration bonus based on commitment period
(define-private (determine-duration-bonus (commitment uint))
    (if (>= commitment u8640)     ;; 2 months
        u150                      ;; 1.5x multiplier
        (if (>= commitment u4320) ;; 1 month
            u125                  ;; 1.25x multiplier
            u100                  ;; 1x multiplier (no commitment)
        )
    )
)

;; Administration Functions

;; Update platform status
(define-public (set-platform-status (suspended bool))
    (begin
        (asserts! (is-eq tx-sender controller-address) ERR-PERMISSION-DENIED)
        (var-set platform-suspended suspended)
        (ok suspended)
    )
)

;; Enable/disable emergency mode
(define-public (set-emergency-mode (enabled bool))
    (begin
        (asserts! (is-eq tx-sender controller-address) ERR-PERMISSION-DENIED)
        (var-set emergency-mode enabled)
        (ok enabled)
    )
)