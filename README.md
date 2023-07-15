
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
- [v2-core-audit-2023-07-14/src/interfaces/ISystemComponent.sol](v2-core-audit-2023-07-14/src/interfaces/ISystemComponent.sol)
- [v2-core-audit-2023-07-14/src/interfaces/ISystemRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/ISystemRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/beacon/IBeaconChainBacking.sol](v2-core-audit-2023-07-14/src/interfaces/beacon/IBeaconChainBacking.sol)
- [v2-core-audit-2023-07-14/src/interfaces/destinations/IClaimableRewardsAdapter.sol](v2-core-audit-2023-07-14/src/interfaces/destinations/IClaimableRewardsAdapter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/destinations/IDestinationAdapter.sol](v2-core-audit-2023-07-14/src/interfaces/destinations/IDestinationAdapter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/destinations/IDestinationRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/destinations/IDestinationRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/destinations/IPoolAdapter.sol](v2-core-audit-2023-07-14/src/interfaces/destinations/IPoolAdapter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/destinations/IStakingAdapter.sol](v2-core-audit-2023-07-14/src/interfaces/destinations/IStakingAdapter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IAsset.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IAsset.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerComposableStablePool.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerComposableStablePool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerMetaStablePool.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerMetaStablePool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBalancerPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBasePool.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IBasePool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IProtocolFeesCollector.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IProtocolFeesCollector.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IRateProvider.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IRateProvider.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/balancer/IVault.sol](v2-core-audit-2023-07-14/src/interfaces/external/balancer/IVault.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IChildChainGaugeRewardHelper.sol](v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IChildChainGaugeRewardHelper.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IChildChainStreamer.sol](v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IChildChainStreamer.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IRewardsOnlyGauge.sol](v2-core-audit-2023-07-14/src/interfaces/external/beethoven/IRewardsOnlyGauge.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/camelot/ICamelotPair.sol](v2-core-audit-2023-07-14/src/interfaces/external/camelot/ICamelotPair.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/camelot/INFTHandler.sol](v2-core-audit-2023-07-14/src/interfaces/external/camelot/INFTHandler.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/camelot/INFTPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/camelot/INFTPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/camelot/INitroPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/camelot/INitroPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/chainlink/IAggregatorV3Interface.sol](v2-core-audit-2023-07-14/src/interfaces/external/chainlink/IAggregatorV3Interface.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/coinbase/IStakedTokenV1.sol](v2-core-audit-2023-07-14/src/interfaces/external/coinbase/IStakedTokenV1.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/convex/IBaseRewardPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/convex/IBaseRewardPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexBooster.sol](v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexBooster.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexBoosterArbitrum.sol](v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexBoosterArbitrum.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexRewardPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/convex/IConvexRewardPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICryptoSwapPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICryptoSwapPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveFactoryV2.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveFactoryV2.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaPoolFactory.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaPoolFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaStableFactory.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveMetaStableFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveOwner.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveOwner.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveRegistryV2.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveRegistryV2.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveStableSwapNG.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveStableSwapNG.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveTokenV2.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveTokenV2.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveV1StableSwap.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveV1StableSwap.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveV2Swap.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ICurveV2Swap.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/ILiquidityGaugeV2.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/ILiquidityGaugeV2.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/IPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/IPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/curve/IStakingRewards.sol](v2-core-audit-2023-07-14/src/interfaces/external/curve/IStakingRewards.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/frax/ISfrxEth.sol](v2-core-audit-2023-07-14/src/interfaces/external/frax/ISfrxEth.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/lido/IstEth.sol](v2-core-audit-2023-07-14/src/interfaces/external/lido/IstEth.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/lido/IwstEth.sol](v2-core-audit-2023-07-14/src/interfaces/external/lido/IwstEth.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPool.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPool.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPoolPositionDynamicSlim.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPoolPositionDynamicSlim.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPoolPositionSlim.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPoolPositionSlim.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPosition.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPosition.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPositionMetadata.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IPositionMetadata.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IReward.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IReward.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/maverick/IRouter.sol](v2-core-audit-2023-07-14/src/interfaces/external/maverick/IRouter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/rocket-pool/IRocketOvmPriceOracle.sol](v2-core-audit-2023-07-14/src/interfaces/external/rocket-pool/IRocketOvmPriceOracle.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/rocket-pool/IRocketTokenRETHInterface.sol](v2-core-audit-2023-07-14/src/interfaces/external/rocket-pool/IRocketTokenRETHInterface.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/swell/IswETH.sol](v2-core-audit-2023-07-14/src/interfaces/external/swell/IswETH.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IPairUniV2.sol](v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IPairUniV2.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IUniswapV2Pair.sol](v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IUniswapV2Pair.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IUniswapV3SwapRouter.sol](v2-core-audit-2023-07-14/src/interfaces/external/uniswap/IUniswapV3SwapRouter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IBaseBribe.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IBaseBribe.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IExternalBribe.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IExternalBribe.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IGauge.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IGauge.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IInternalBribe.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IInternalBribe.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IPair.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IPair.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IRewardsDistributor.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IRewardsDistributor.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IRouter.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IRouter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IVoter.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IVoter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IVotingEscrow.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IVotingEscrow.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IWrappedExternalBribe.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IWrappedExternalBribe.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IWrappedExternalBribeFactory.sol](v2-core-audit-2023-07-14/src/interfaces/external/velodrome/IWrappedExternalBribeFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/external/wsteth/IWstEth.sol](v2-core-audit-2023-07-14/src/interfaces/external/wsteth/IWstEth.sol)
- [v2-core-audit-2023-07-14/src/interfaces/liquidation/IAsyncSwapper.sol](v2-core-audit-2023-07-14/src/interfaces/liquidation/IAsyncSwapper.sol)
- [v2-core-audit-2023-07-14/src/interfaces/liquidation/IAsyncSwapperRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/liquidation/IAsyncSwapperRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/liquidation/ILiquidationRow.sol](v2-core-audit-2023-07-14/src/interfaces/liquidation/ILiquidationRow.sol)
- [v2-core-audit-2023-07-14/src/interfaces/oracles/IPriceOracle.sol](v2-core-audit-2023-07-14/src/interfaces/oracles/IPriceOracle.sol)
- [v2-core-audit-2023-07-14/src/interfaces/oracles/IRootPriceOracle.sol](v2-core-audit-2023-07-14/src/interfaces/oracles/IRootPriceOracle.sol)
- [v2-core-audit-2023-07-14/src/interfaces/pricing/IEthValueOracle.sol](v2-core-audit-2023-07-14/src/interfaces/pricing/IEthValueOracle.sol)
- [v2-core-audit-2023-07-14/src/interfaces/rewarders/IBaseRewarder.sol](v2-core-audit-2023-07-14/src/interfaces/rewarders/IBaseRewarder.sol)
- [v2-core-audit-2023-07-14/src/interfaces/rewarders/IExtraRewarder.sol](v2-core-audit-2023-07-14/src/interfaces/rewarders/IExtraRewarder.sol)
- [v2-core-audit-2023-07-14/src/interfaces/rewarders/IMainRewarder.sol](v2-core-audit-2023-07-14/src/interfaces/rewarders/IMainRewarder.sol)
- [v2-core-audit-2023-07-14/src/interfaces/rewarders/IStakeTracking.sol](v2-core-audit-2023-07-14/src/interfaces/rewarders/IStakeTracking.sol)
- [v2-core-audit-2023-07-14/src/interfaces/rewards/IClaimableRewards.sol](v2-core-audit-2023-07-14/src/interfaces/rewards/IClaimableRewards.sol)
- [v2-core-audit-2023-07-14/src/interfaces/security/IAccessController.sol](v2-core-audit-2023-07-14/src/interfaces/security/IAccessController.sol)
- [v2-core-audit-2023-07-14/src/interfaces/security/ISystemSecurity.sol](v2-core-audit-2023-07-14/src/interfaces/security/ISystemSecurity.sol)
- [v2-core-audit-2023-07-14/src/interfaces/staking/IGPToke.sol](v2-core-audit-2023-07-14/src/interfaces/staking/IGPToke.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/IDexLSTStats.sol](v2-core-audit-2023-07-14/src/interfaces/stats/IDexLSTStats.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/IIncentivesPricingStats.sol](v2-core-audit-2023-07-14/src/interfaces/stats/IIncentivesPricingStats.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/ILSTStats.sol](v2-core-audit-2023-07-14/src/interfaces/stats/ILSTStats.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculator.sol](v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculator.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculatorFactory.sol](v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculatorFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculatorRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/stats/IStatsCalculatorRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/strategy/IStrategy.sol](v2-core-audit-2023-07-14/src/interfaces/strategy/IStrategy.sol)
- [v2-core-audit-2023-07-14/src/interfaces/swapper/ISwapRouter.sol](v2-core-audit-2023-07-14/src/interfaces/swapper/ISwapRouter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/swapper/ISyncSwapper.sol](v2-core-audit-2023-07-14/src/interfaces/swapper/ISyncSwapper.sol)
- [v2-core-audit-2023-07-14/src/interfaces/utils/ICurveResolver.sol](v2-core-audit-2023-07-14/src/interfaces/utils/ICurveResolver.sol)
- [v2-core-audit-2023-07-14/src/interfaces/utils/IERC20PermitAllowed.sol](v2-core-audit-2023-07-14/src/interfaces/utils/IERC20PermitAllowed.sol)
- [v2-core-audit-2023-07-14/src/interfaces/utils/IMulticall.sol](v2-core-audit-2023-07-14/src/interfaces/utils/IMulticall.sol)
- [v2-core-audit-2023-07-14/src/interfaces/utils/ISelfPermit.sol](v2-core-audit-2023-07-14/src/interfaces/utils/ISelfPermit.sol)
- [v2-core-audit-2023-07-14/src/interfaces/utils/IWETH9.sol](v2-core-audit-2023-07-14/src/interfaces/utils/IWETH9.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/IBaseAssetVault.sol](v2-core-audit-2023-07-14/src/interfaces/vault/IBaseAssetVault.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVault.sol](v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVault.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVaultFactory.sol](v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVaultFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVaultRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/vault/IDestinationVaultRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVault.sol](v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVault.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultFactory.sol](v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultFactory.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRegistry.sol](v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRegistry.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRouter.sol](v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRouter.sol)
- [v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRouterBase.sol](v2-core-audit-2023-07-14/src/interfaces/vault/ILMPVaultRouterBase.sol)
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
- [v2-core-audit-2023-07-14/src/strategy/LMPStrategy.sol](v2-core-audit-2023-07-14/src/strategy/LMPStrategy.sol)
- [v2-core-audit-2023-07-14/src/strategy/StrategyFactory.sol](v2-core-audit-2023-07-14/src/strategy/StrategyFactory.sol)
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
- [v2-core-audit-2023-07-14/test/BaseTest.t.sol](v2-core-audit-2023-07-14/test/BaseTest.t.sol)
- [v2-core-audit-2023-07-14/test/SystemRegistry.t.sol](v2-core-audit-2023-07-14/test/SystemRegistry.t.sol)
- [v2-core-audit-2023-07-14/test/access/Ownable2Step.t.sol](v2-core-audit-2023-07-14/test/access/Ownable2Step.t.sol)
- [v2-core-audit-2023-07-14/test/base/CamelotBase.sol](v2-core-audit-2023-07-14/test/base/CamelotBase.sol)
- [v2-core-audit-2023-07-14/test/beacon/FrxBeaconChainBacking.t.sol](v2-core-audit-2023-07-14/test/beacon/FrxBeaconChainBacking.t.sol)
- [v2-core-audit-2023-07-14/test/deployments/Deployment.t.sol](v2-core-audit-2023-07-14/test/deployments/Deployment.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/DestinationRegistry.t.sol](v2-core-audit-2023-07-14/test/destinations/DestinationRegistry.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/BalancerAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/BalancerAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/BeethovenAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/BeethovenAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/CurveV2FactoryCryptoAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/CurveV2FactoryCryptoAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/MaverickAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/MaverickAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/VelodromeAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/VelodromeAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/AuraRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/AuraRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/BeethovenRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/BeethovenRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/CamelotRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/CamelotRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/ConvexArbitrumRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/ConvexArbitrumRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/ConvexRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/ConvexRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/CurveRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/CurveRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/MaverickRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/MaverickRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/rewards/VelodromeRewardsAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/rewards/VelodromeRewardsAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/staking/AuraAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/staking/AuraAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/staking/ConvexAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/staking/ConvexAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/staking/MaverickStakingAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/staking/MaverickStakingAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/destinations/adapters/staking/VelodromeStakingAdapter.t.sol](v2-core-audit-2023-07-14/test/destinations/adapters/staking/VelodromeStakingAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/libs/BalancerUtilities.t.sol](v2-core-audit-2023-07-14/test/libs/BalancerUtilities.t.sol)
- [v2-core-audit-2023-07-14/test/libs/ConvexRewards.t.sol](v2-core-audit-2023-07-14/test/libs/ConvexRewards.t.sol)
- [v2-core-audit-2023-07-14/test/libs/LibAdapter.t.sol](v2-core-audit-2023-07-14/test/libs/LibAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/liquidators/AsyncSwapperRegistry.t.sol](v2-core-audit-2023-07-14/test/liquidators/AsyncSwapperRegistry.t.sol)
- [v2-core-audit-2023-07-14/test/liquidators/LiquidationRow.t.sol](v2-core-audit-2023-07-14/test/liquidators/LiquidationRow.t.sol)
- [v2-core-audit-2023-07-14/test/liquidators/OneInchAdapter.t.sol](v2-core-audit-2023-07-14/test/liquidators/OneInchAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/liquidators/ZeroExAdapter.t.sol](v2-core-audit-2023-07-14/test/liquidators/ZeroExAdapter.t.sol)
- [v2-core-audit-2023-07-14/test/mocks/CrvUsdOracle.sol](v2-core-audit-2023-07-14/test/mocks/CrvUsdOracle.sol)
- [v2-core-audit-2023-07-14/test/mocks/MockERC20.sol](v2-core-audit-2023-07-14/test/mocks/MockERC20.sol)
- [v2-core-audit-2023-07-14/test/mocks/StakeTrackingMock.sol](v2-core-audit-2023-07-14/test/mocks/StakeTrackingMock.sol)
- [v2-core-audit-2023-07-14/test/mocks/TestDestinationVault.sol](v2-core-audit-2023-07-14/test/mocks/TestDestinationVault.sol)
- [v2-core-audit-2023-07-14/test/mocks/TestERC20.sol](v2-core-audit-2023-07-14/test/mocks/TestERC20.sol)
- [v2-core-audit-2023-07-14/test/oracles/RootOracleIntegrationTest.t.sol](v2-core-audit-2023-07-14/test/oracles/RootOracleIntegrationTest.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/RootPriceOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/RootPriceOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/BalancerLPComposableStableEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/BalancerLPComposableStableEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/BalancerLPMetaStableEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/BalancerLPMetaStableEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/ChainlinkOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/ChainlinkOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/CurveV1StableEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/CurveV1StableEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/CurveV2CryptoEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/CurveV2CryptoEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/CustomSetOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/CustomSetOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/EthPeggedOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/EthPeggedOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/MavEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/MavEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/SfrxEthEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/SfrxEthEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/SwEthEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/SwEthEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/TellorOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/TellorOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/UniswapV2EthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/UniswapV2EthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/oracles/providers/WstETHEthOracle.t.sol](v2-core-audit-2023-07-14/test/oracles/providers/WstETHEthOracle.t.sol)
- [v2-core-audit-2023-07-14/test/rewarders/AbstractRewarder.t.sol](v2-core-audit-2023-07-14/test/rewarders/AbstractRewarder.t.sol)
- [v2-core-audit-2023-07-14/test/rewarders/RewardVault.t.sol](v2-core-audit-2023-07-14/test/rewarders/RewardVault.t.sol)
- [v2-core-audit-2023-07-14/test/security/AccessControl.t.sol](v2-core-audit-2023-07-14/test/security/AccessControl.t.sol)
- [v2-core-audit-2023-07-14/test/security/Pausable.t.sol](v2-core-audit-2023-07-14/test/security/Pausable.t.sol)
- [v2-core-audit-2023-07-14/test/security/SystemSecurity.t.sol](v2-core-audit-2023-07-14/test/security/SystemSecurity.t.sol)
- [v2-core-audit-2023-07-14/test/staking/Staking.t.sol](v2-core-audit-2023-07-14/test/staking/Staking.t.sol)
- [v2-core-audit-2023-07-14/test/stats/Stats.t.sol](v2-core-audit-2023-07-14/test/stats/Stats.t.sol)
- [v2-core-audit-2023-07-14/test/stats/StatsCalculatorFactory.t.sol](v2-core-audit-2023-07-14/test/stats/StatsCalculatorFactory.t.sol)
- [v2-core-audit-2023-07-14/test/stats/StatsCalculatorRegister.t.sol](v2-core-audit-2023-07-14/test/stats/StatsCalculatorRegister.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/CbethLSTCalculator.t..sol](v2-core-audit-2023-07-14/test/stats/calculators/CbethLSTCalculator.t..sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/CurveV1ConvexStatsCalculator.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/CurveV1ConvexStatsCalculator.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/CurveV1PoolNoRebasingStatsCalculator.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/CurveV1PoolNoRebasingStatsCalculator.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/CurveV1PoolRebasingStatsCalculator.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/CurveV1PoolRebasingStatsCalculator.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/IncentivePricingStats.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/IncentivePricingStats.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/ProxyLSTCalculator.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/ProxyLSTCalculator.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/RethLSTCalculator.t..sol](v2-core-audit-2023-07-14/test/stats/calculators/RethLSTCalculator.t..sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/StethLSTCalculator.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/StethLSTCalculator.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/SwethLSTCalculator.t..sol](v2-core-audit-2023-07-14/test/stats/calculators/SwethLSTCalculator.t..sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/base/BalancerStablePoolCalculatorBase.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/base/BalancerStablePoolCalculatorBase.t.sol)
- [v2-core-audit-2023-07-14/test/stats/calculators/base/LSTCalculatorBase.t.sol](v2-core-audit-2023-07-14/test/stats/calculators/base/LSTCalculatorBase.t.sol)
- [v2-core-audit-2023-07-14/test/stats/utils/CurveUtils.t.sol](v2-core-audit-2023-07-14/test/stats/utils/CurveUtils.t.sol)
- [v2-core-audit-2023-07-14/test/swapper/SwapRouter.t.sol](v2-core-audit-2023-07-14/test/swapper/SwapRouter.t.sol)
- [v2-core-audit-2023-07-14/test/swapper/adapters/BalancerV2Swap.t.sol](v2-core-audit-2023-07-14/test/swapper/adapters/BalancerV2Swap.t.sol)
- [v2-core-audit-2023-07-14/test/swapper/adapters/CurveStableSwap.sol](v2-core-audit-2023-07-14/test/swapper/adapters/CurveStableSwap.sol)
- [v2-core-audit-2023-07-14/test/swapper/adapters/CurveV1StableSwap.sol](v2-core-audit-2023-07-14/test/swapper/adapters/CurveV1StableSwap.sol)
- [v2-core-audit-2023-07-14/test/swapper/adapters/UniV3Swap.t.sol](v2-core-audit-2023-07-14/test/swapper/adapters/UniV3Swap.t.sol)
- [v2-core-audit-2023-07-14/test/utils/Addresses.sol](v2-core-audit-2023-07-14/test/utils/Addresses.sol)
- [v2-core-audit-2023-07-14/test/utils/Arrays.t.sol](v2-core-audit-2023-07-14/test/utils/Arrays.t.sol)
- [v2-core-audit-2023-07-14/test/utils/CurveResolverMainnet.t.sol](v2-core-audit-2023-07-14/test/utils/CurveResolverMainnet.t.sol)
- [v2-core-audit-2023-07-14/test/utils/ReadPlan.sol](v2-core-audit-2023-07-14/test/utils/ReadPlan.sol)
- [v2-core-audit-2023-07-14/test/utils/common.sol](v2-core-audit-2023-07-14/test/utils/common.sol)
- [v2-core-audit-2023-07-14/test/vault/BalancerAuraDestinationVault.t.sol](v2-core-audit-2023-07-14/test/vault/BalancerAuraDestinationVault.t.sol)
- [v2-core-audit-2023-07-14/test/vault/BalancerAuraDestinationVaultComposable.t.sol](v2-core-audit-2023-07-14/test/vault/BalancerAuraDestinationVaultComposable.t.sol)
- [v2-core-audit-2023-07-14/test/vault/CurveConvexDestinationVault.t.sol](v2-core-audit-2023-07-14/test/vault/CurveConvexDestinationVault.t.sol)
- [v2-core-audit-2023-07-14/test/vault/DestinationVault.t.sol](v2-core-audit-2023-07-14/test/vault/DestinationVault.t.sol)
- [v2-core-audit-2023-07-14/test/vault/DestinationVaultFactory.t.sol](v2-core-audit-2023-07-14/test/vault/DestinationVaultFactory.t.sol)
- [v2-core-audit-2023-07-14/test/vault/DestinationVaultRegistry.t.sol](v2-core-audit-2023-07-14/test/vault/DestinationVaultRegistry.t.sol)
- [v2-core-audit-2023-07-14/test/vault/LMPVault-Withdraw.t.sol](v2-core-audit-2023-07-14/test/vault/LMPVault-Withdraw.t.sol)
- [v2-core-audit-2023-07-14/test/vault/LMPVault.t.sol](v2-core-audit-2023-07-14/test/vault/LMPVault.t.sol)
- [v2-core-audit-2023-07-14/test/vault/LMPVaultBaseTest.t.sol](v2-core-audit-2023-07-14/test/vault/LMPVaultBaseTest.t.sol)
- [v2-core-audit-2023-07-14/test/vault/LMPVaultFactory.t.sol](v2-core-audit-2023-07-14/test/vault/LMPVaultFactory.t.sol)
- [v2-core-audit-2023-07-14/test/vault/LMPVaultRouter.t.sol](v2-core-audit-2023-07-14/test/vault/LMPVaultRouter.t.sol)
- [v2-core-audit-2023-07-14/test/vault/MaverickDestinationVault.t.sol](v2-core-audit-2023-07-14/test/vault/MaverickDestinationVault.t.sol)



