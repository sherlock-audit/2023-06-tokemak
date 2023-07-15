
# Tokemak contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Mainnet
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
Any, but primarily the following at launch

1. Liquid Staking Tokens, including stETH/wstETH (Lido), rETH (Rocket), cbETH (Coinbase), swETH (Swell), frxETH/sfrxETH (Frax)
2. Other Tokens, including CVX (Convex), CRV (Curve), BAL (Balancer), AURA (Aura Finance), LDO (Lido)
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

None
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

Yes, stETH (Lido Staked Ether)
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
RESTRICTED
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
TRUSTED
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
Yes, Tokemak V2 has a central access controller with specified roles. The roles are listed here:
https://github.com/sherlock-audit/2023-06-tokemak/blob/83fb3c668c2f6caeb5d3e421cf9ad4a41e0a1c98/v2-core-audit-2023-07-14/src/libs/Roles.sol
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
src/vault/LMPVault.sol should be 4626 compatible
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
Off-chain mechanisms listed in subsequent section are expected to be online and execute within their expected frequency
___

### Q: Please provide links to previous audits (if any).
NA
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
Yes, there are several off-chain mechanisms

1. LMPVault
    1. updateDebtReporting - initiated externally, but unprivileged operation
    2. rebalance/flashRebalance - initiated externally and is restricted to an allow list, but LMPStrategy’s fully validate the proposed actions.
2. Stats - all stats contracts must have snapshots initiated by a keeper network at on-chain enforced intervals. With the exception of `IncentivePricingStats` these can be done in an unprivileged manner. `IncentivePricingStats` requires that snapshots are taken at randomized intervals, so is done by a privileged operator. More details can be found in [Stats High Level Docs](https://github.com/sherlock-audit/2023-06-tokemak/blob/83fb3c668c2f6caeb5d3e421cf9ad4a41e0a1c98/v2-core-audit-2023-07-14/src/stats/Stats.md) and [Calculator Docs](https://github.com/sherlock-audit/2023-06-tokemak/blob/83fb3c668c2f6caeb5d3e421cf9ad4a41e0a1c98/v2-core-audit-2023-07-14/src/stats/calculators/Calculators.md).
3. src/beacon/FrxBeaconChainBacking - Will be written to by a protected off-chain component
4. src/liquidation/LiquidationRow - claimVaultRewards() and liquidateVaultsForTokens() will be initiated by protected off-chain components.
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
Pausing or emergency withdrawals are not acceptable for Tokemak.
___

### Q: Do you expect to use any of the following tokens with non-standard behaviour with the smart contracts?
Upgradeable: stETH (wstETH by proxy) and cbETH 
___

### Q: Add links to relevant protocol resources
README’s in the repo should provide further context.

Commit and exclude contracts:
https://tokemak.notion.site/Autopilot-Audit-99f03de2f31f4f52a0e3a11a616ae7ef?pvs=4
___



# Audit scope

