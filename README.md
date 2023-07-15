
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
- Off-chain mechanisms listed in subsequent section are expected to be online and execute within their expected frequency
- The LMPStrategy.verifyRebalance() referenced in the LMPVault, and in the LMPDebt lib used by the vault, is expected to only return true when the rebalance is favorable for the vault/users.
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
___



# Audit scope


[v2-core-audit-2023-07-14 @ 62445b8ee3365611534c96aef189642b721693bf](https://github.com/Tokemak/v2-core-audit-2023-07-14/tree/62445b8ee3365611534c96aef189642b721693bf)
- [v2-core-audit-2023-07-14/src/SystemComponent.sol](v2-core-audit-2023-07-14/src/SystemComponent.sol)
- [v2-core-audit-2023-07-14/src/SystemRegistry.sol](v2-core-audit-2023-07-14/src/SystemRegistry.sol)
- [v2-core-audit-2023-07-14/src/access/Ownable2Step.sol](v2-core-audit-2023-07-14/src/access/Ownable2Step.sol)
- [v2-core-audit-2023-07-14/src/beacon/FrxBeaconChainBacking.sol](v2-core-audit-2023-07-14/src/beacon/FrxBeaconChainBacking.sol)
- [v2-core-audit-2023-07-14/src/destinations/DestinationRegistry.sol](v2-core-audit-2023-07-14/src/destinations/DestinationRegistry.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/BalancerBeethovenAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/BalancerBeethovenAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/CurveV2FactoryCryptoAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/CurveV2FactoryCryptoAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/MaverickAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/MaverickAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/rewards/AuraRewardsAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/rewards/AuraRewardsAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/rewards/ConvexRewardsAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/rewards/ConvexRewardsAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/rewards/MaverickRewardsAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/rewards/MaverickRewardsAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/rewards/RewardAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/rewards/RewardAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/staking/AuraAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/staking/AuraAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/staking/ConvexAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/staking/ConvexAdapter.sol)
- [v2-core-audit-2023-07-14/src/destinations/adapters/staking/MaverickStakingAdapter.sol](v2-core-audit-2023-07-14/src/destinations/adapters/staking/MaverickStakingAdapter.sol)
- [v2-core-audit-2023-07-14/src/libs/BalancerUtilities.sol](v2-core-audit-2023-07-14/src/libs/BalancerUtilities.sol)
- [v2-core-audit-2023-07-14/src/libs/ConvexRewards.sol](v2-core-audit-2023-07-14/src/libs/ConvexRewards.sol)
- [v2-core-audit-2023-07-14/src/libs/LibAdapter.sol](v2-core-audit-2023-07-14/src/libs/LibAdapter.sol)
- [v2-core-audit-2023-07-14/src/libs/Roles.sol](v2-core-audit-2023-07-14/src/libs/Roles.sol)
- [v2-core-audit-2023-07-14/src/liquidation/AsyncSwapperRegistry.sol](v2-core-audit-2023-07-14/src/liquidation/AsyncSwapperRegistry.sol)
- [v2-core-audit-2023-07-14/src/liquidation/BaseAsyncSwapper.sol](v2-core-audit-2023-07-14/src/liquidation/BaseAsyncSwapper.sol)
- [v2-core-audit-2023-07-14/src/liquidation/LiquidationRow.sol](v2-core-audit-2023-07-14/src/liquidation/LiquidationRow.sol)
- [v2-core-audit-2023-07-14/src/oracles/RootPriceOracle.sol](v2-core-audit-2023-07-14/src/oracles/RootPriceOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/BalancerLPComposableStableEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/BalancerLPComposableStableEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/BalancerLPMetaStableEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/BalancerLPMetaStableEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/ChainlinkOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/ChainlinkOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/CurveV1StableEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/CurveV1StableEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/CurveV2CryptoEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/CurveV2CryptoEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/CustomSetOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/CustomSetOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/EthPeggedOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/EthPeggedOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/MavEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/MavEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/SfrxEthEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/SfrxEthEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/SwEthEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/SwEthEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/TellorOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/TellorOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/UniswapV2EthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/UniswapV2EthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/WstETHEthOracle.sol](v2-core-audit-2023-07-14/src/oracles/providers/WstETHEthOracle.sol)
- [v2-core-audit-2023-07-14/src/oracles/providers/base/BaseOracleDenominations.sol](v2-core-audit-2023-07-14/src/oracles/providers/base/BaseOracleDenominations.sol)
- [v2-core-audit-2023-07-14/src/rewarders/AbstractRewarder.sol](v2-core-audit-2023-07-14/src/rewarders/AbstractRewarder.sol)
- [v2-core-audit-2023-07-14/src/rewarders/ExtraRewarder.sol](v2-core-audit-2023-07-14/src/rewarders/ExtraRewarder.sol)
- [v2-core-audit-2023-07-14/src/rewarders/MainRewarder.sol](v2-core-audit-2023-07-14/src/rewarders/MainRewarder.sol)
- [v2-core-audit-2023-07-14/src/security/AccessController.sol](v2-core-audit-2023-07-14/src/security/AccessController.sol)
- [v2-core-audit-2023-07-14/src/security/Pausable.sol](v2-core-audit-2023-07-14/src/security/Pausable.sol)
- [v2-core-audit-2023-07-14/src/security/SecurityBase.sol](v2-core-audit-2023-07-14/src/security/SecurityBase.sol)
- [v2-core-audit-2023-07-14/src/security/SystemSecurity.sol](v2-core-audit-2023-07-14/src/security/SystemSecurity.sol)
- [v2-core-audit-2023-07-14/src/solver/CommandBuilder.sol](v2-core-audit-2023-07-14/src/solver/CommandBuilder.sol)
- [v2-core-audit-2023-07-14/src/solver/VM.sol](v2-core-audit-2023-07-14/src/solver/VM.sol)
- [v2-core-audit-2023-07-14/src/solver/helpers/ArraysConverter.sol](v2-core-audit-2023-07-14/src/solver/helpers/ArraysConverter.sol)
- [v2-core-audit-2023-07-14/src/solver/helpers/BlockchainInfo.sol](v2-core-audit-2023-07-14/src/solver/helpers/BlockchainInfo.sol)
- [v2-core-audit-2023-07-14/src/solver/helpers/Bytes32.sol](v2-core-audit-2023-07-14/src/solver/helpers/Bytes32.sol)
- [v2-core-audit-2023-07-14/src/solver/helpers/Integer.sol](v2-core-audit-2023-07-14/src/solver/helpers/Integer.sol)
- [v2-core-audit-2023-07-14/src/solver/helpers/Tupler.sol](v2-core-audit-2023-07-14/src/solver/helpers/Tupler.sol)
- [v2-core-audit-2023-07-14/src/solver/test/SolverCaller.sol](v2-core-audit-2023-07-14/src/solver/test/SolverCaller.sol)
- [v2-core-audit-2023-07-14/src/staking/GPToke.sol](v2-core-audit-2023-07-14/src/staking/GPToke.sol)
- [v2-core-audit-2023-07-14/src/stats/Stats.sol](v2-core-audit-2023-07-14/src/stats/Stats.sol)
- [v2-core-audit-2023-07-14/src/stats/StatsCalculatorFactory.sol](v2-core-audit-2023-07-14/src/stats/StatsCalculatorFactory.sol)
- [v2-core-audit-2023-07-14/src/stats/StatsCalculatorRegistry.sol](v2-core-audit-2023-07-14/src/stats/StatsCalculatorRegistry.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/CbethLSTCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/CbethLSTCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/CurveV1PoolNoRebasingStatsCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/CurveV1PoolNoRebasingStatsCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/CurveV1PoolRebasingStatsCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/CurveV1PoolRebasingStatsCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/IncentivePricingStats.sol](v2-core-audit-2023-07-14/src/stats/calculators/IncentivePricingStats.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/ProxyLSTCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/ProxyLSTCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/RethLSTCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/RethLSTCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/StethLSTCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/StethLSTCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/SwethLSTCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/SwethLSTCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/base/BalancerStablePoolCalculatorBase.sol](v2-core-audit-2023-07-14/src/stats/calculators/base/BalancerStablePoolCalculatorBase.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/base/BaseStatsCalculator.sol](v2-core-audit-2023-07-14/src/stats/calculators/base/BaseStatsCalculator.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/base/CurvePoolNoRebasingCalculatorBase.sol](v2-core-audit-2023-07-14/src/stats/calculators/base/CurvePoolNoRebasingCalculatorBase.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/base/CurvePoolRebasingCalculatorBase.sol](v2-core-audit-2023-07-14/src/stats/calculators/base/CurvePoolRebasingCalculatorBase.sol)
- [v2-core-audit-2023-07-14/src/stats/calculators/base/LSTCalculatorBase.sol](v2-core-audit-2023-07-14/src/stats/calculators/base/LSTCalculatorBase.sol)
- [v2-core-audit-2023-07-14/src/stats/utils/CurveUtils.sol](v2-core-audit-2023-07-14/src/stats/utils/CurveUtils.sol)
- [v2-core-audit-2023-07-14/src/swapper/SwapRouter.sol](v2-core-audit-2023-07-14/src/swapper/SwapRouter.sol)
- [v2-core-audit-2023-07-14/src/swapper/adapters/BalancerV2Swap.sol](v2-core-audit-2023-07-14/src/swapper/adapters/BalancerV2Swap.sol)
- [v2-core-audit-2023-07-14/src/swapper/adapters/BaseAdapter.sol](v2-core-audit-2023-07-14/src/swapper/adapters/BaseAdapter.sol)
- [v2-core-audit-2023-07-14/src/swapper/adapters/CurveV1StableSwap.sol](v2-core-audit-2023-07-14/src/swapper/adapters/CurveV1StableSwap.sol)
- [v2-core-audit-2023-07-14/src/swapper/adapters/CurveV2Swap.sol](v2-core-audit-2023-07-14/src/swapper/adapters/CurveV2Swap.sol)
- [v2-core-audit-2023-07-14/src/swapper/adapters/UniV3Swap.sol](v2-core-audit-2023-07-14/src/swapper/adapters/UniV3Swap.sol)
- [v2-core-audit-2023-07-14/src/utils/Arrays.sol](v2-core-audit-2023-07-14/src/utils/Arrays.sol)
- [v2-core-audit-2023-07-14/src/utils/CurveResolverMainnet.sol](v2-core-audit-2023-07-14/src/utils/CurveResolverMainnet.sol)
- [v2-core-audit-2023-07-14/src/utils/Errors.sol](v2-core-audit-2023-07-14/src/utils/Errors.sol)
- [v2-core-audit-2023-07-14/src/utils/Multicall.sol](v2-core-audit-2023-07-14/src/utils/Multicall.sol)
- [v2-core-audit-2023-07-14/src/utils/NonReentrant.sol](v2-core-audit-2023-07-14/src/utils/NonReentrant.sol)
- [v2-core-audit-2023-07-14/src/utils/PeripheryPayments.sol](v2-core-audit-2023-07-14/src/utils/PeripheryPayments.sol)
- [v2-core-audit-2023-07-14/src/utils/SelfPermit.sol](v2-core-audit-2023-07-14/src/utils/SelfPermit.sol)
- [v2-core-audit-2023-07-14/src/utils/univ3/BytesLib.sol](v2-core-audit-2023-07-14/src/utils/univ3/BytesLib.sol)
- [v2-core-audit-2023-07-14/src/utils/univ3/Path.sol](v2-core-audit-2023-07-14/src/utils/univ3/Path.sol)
- [v2-core-audit-2023-07-14/src/vault/BalancerAuraDestinationVault.sol](v2-core-audit-2023-07-14/src/vault/BalancerAuraDestinationVault.sol)
- [v2-core-audit-2023-07-14/src/vault/CurveConvexDestinationVault.sol](v2-core-audit-2023-07-14/src/vault/CurveConvexDestinationVault.sol)
- [v2-core-audit-2023-07-14/src/vault/DestinationVault.sol](v2-core-audit-2023-07-14/src/vault/DestinationVault.sol)
- [v2-core-audit-2023-07-14/src/vault/DestinationVaultFactory.sol](v2-core-audit-2023-07-14/src/vault/DestinationVaultFactory.sol)
- [v2-core-audit-2023-07-14/src/vault/DestinationVaultRegistry.sol](v2-core-audit-2023-07-14/src/vault/DestinationVaultRegistry.sol)
- [v2-core-audit-2023-07-14/src/vault/LMPVault.sol](v2-core-audit-2023-07-14/src/vault/LMPVault.sol)
- [v2-core-audit-2023-07-14/src/vault/LMPVaultFactory.sol](v2-core-audit-2023-07-14/src/vault/LMPVaultFactory.sol)
- [v2-core-audit-2023-07-14/src/vault/LMPVaultRegistry.sol](v2-core-audit-2023-07-14/src/vault/LMPVaultRegistry.sol)
- [v2-core-audit-2023-07-14/src/vault/LMPVaultRouter.sol](v2-core-audit-2023-07-14/src/vault/LMPVaultRouter.sol)
- [v2-core-audit-2023-07-14/src/vault/LMPVaultRouterBase.sol](v2-core-audit-2023-07-14/src/vault/LMPVaultRouterBase.sol)
- [v2-core-audit-2023-07-14/src/vault/MaverickDestinationVault.sol](v2-core-audit-2023-07-14/src/vault/MaverickDestinationVault.sol)
- [v2-core-audit-2023-07-14/src/vault/VaultTypes.sol](v2-core-audit-2023-07-14/src/vault/VaultTypes.sol)
- [v2-core-audit-2023-07-14/src/vault/libs/LMPDebt.sol](v2-core-audit-2023-07-14/src/vault/libs/LMPDebt.sol)
- [v2-core-audit-2023-07-14/src/vault/libs/LMPDestinations.sol](v2-core-audit-2023-07-14/src/vault/libs/LMPDestinations.sol)




