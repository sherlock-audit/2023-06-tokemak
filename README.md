
# Tokemak contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Mainnet
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
TOKE: 0x2e9d63788249371f1DFC918a52f8d799F4a38C94
WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
CRV: 0xD533a949740bb3306d119CC777fa900bA034cd52
CVX: 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
LDO: 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32
BAL: 0xba100000625a3754423978a60c9317c58a424e3D
AURA: 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF

Liquid Staking Tokens
stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
rETH: 0xae78736Cd615f374D3085123A210448E74Fc6393
cbETH: 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704
frxETH: 0x5E8422345238F34275888049021821E8E08CAa1f
sfrxETH: 0xac3E018457B222d93114458476f3E3416Abbe38F
swETH: 0xf951E335afb289353dc249e82926178EaC7DEd78

Curve Pools
Curve stETH/ETH: 0x06325440D014e39736583c165C2963BA99fAf14E
Curve stETH/ETH ng: 0x21E27a5E5513D6e65C4f830167390997aA84843a
Curve stETH/ETH concentrated: 0x828b154032950C8ff7CF8085D841723Db2696056
Curve stETH/frxETH: 0x4d9f9D15101EEC665F77210cB999639f760F831E
Curve rETH/ETH: 0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C
Curve rETH/wstETH: 0x447Ddd4960d9fdBF6af9a790560d0AF76795CB08
Curve rETH/frxETH: 0xbA6c373992AD8ec1f7520E5878E5540Eb36DeBf1
Curve cbETH/ETH: 0x5b6C539b224014A09B3388e51CaAA8e354c959C8
Curve cbETH/frxETH: 0x548E063CE6F3BaC31457E4f5b4e2345286274257
Curve frxETH/ETH: 0xf43211935C781D5ca1a41d2041F397B8A7366C7A
Curve swETH/frxETH: 0xe49AdDc2D1A131c6b8145F0EBa1C946B7198e0BA

Balancer Pools
Balancer wstETH/WETH: 0x32296969Ef14EB0c6d29669C550D4a0449130230
Balancer wstETH/sfrxETH/rETH: 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe
Balancer wstETH/cbETH: 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2
Balancer rETH/WETH: 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276

Maverick Pools
Maverick ETH/swETH boosted: 0xF917FE742C530Bd66BcEbf64B42c777B13aac92c

Note: for LP positions that are staked at Convex/Aura there is an associated Convex/Aura ERC20 token that wraps the Curve LP token and is staked. If Tokemak stakes at Convex/Aura, we do not directly hold the ERC20, but rather wrap and stake in a single function. 
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



