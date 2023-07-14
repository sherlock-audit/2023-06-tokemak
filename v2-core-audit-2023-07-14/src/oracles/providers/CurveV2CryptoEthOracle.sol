// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { SecurityBase } from "src/security/SecurityBase.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { SystemComponent } from "src/SystemComponent.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveResolver } from "src/interfaces/utils/ICurveResolver.sol";
import { Errors } from "src/utils/Errors.sol";
import { ICryptoSwapPool } from "src/interfaces/external/curve/ICryptoSwapPool.sol";

contract CurveV2CryptoEthOracle is SystemComponent, SecurityBase, IPriceOracle {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ICurveResolver public immutable curveResolver;

    /**
     * @notice Struct for neccessary information for single Curve pool.
     * @param pool The address of the curve pool.
     * @param checkReentrancy uint8 representing a boolean.  0 for false, 1 for true.
     * @param tokentoPrice Address of the token being priced in the Curve pool.
     */
    struct PoolData {
        address pool;
        uint8 checkReentrancy;
        address tokenToPrice;
    }

    /**
     * @notice Emitted when token Curve pool is registered.
     * @param lpToken Lp token that has been registered.
     */
    event TokenRegistered(address lpToken);

    /**
     * @notice Emitted when a Curve pool registration is removed.
     * @param lpToken Lp token that has been unregistered.
     */
    event TokenUnregistered(address lpToken);

    /**
     * @notice Thrown when pool returned is not a v2 curve pool.
     * @param curvePool Address of the pool that was attempted to be registered.
     */
    error NotCryptoPool(address curvePool);

    /**
     * @notice Thrown when wrong lp token is returned from CurveResolver.sol.
     * @param providedLP Address of lp token provided in function call.
     * @param queriedLP Address of lp tokens returned from resolver.
     */
    error ResolverMismatch(address providedLP, address queriedLP);

    /**
     * @notice Thrown when a Curve V2 Lp token is already registered.
     * @param curveLpToken The address of the token attempted to be deployed.
     */
    error AlreadyRegistered(address curveLpToken);

    /**
     * @notice Thrown when lp token is not registered.
     * @param curveLpToken Address of token expected to be registered.
     */
    error NotRegistered(address curveLpToken);

    /**
     * @notice Thrown when a pool with an invalid number of tokens is attempted to be registered.
     * @param numTokens The number of tokens in the pool attempted to be registered.
     */
    error InvalidNumTokens(uint256 numTokens);

    /**
     * @notice Thrown when a pool that does not have native Eth as a token in the pair is registered
     *      for a read only reentrancy check.
     */
    error MustHaveEthForReentrancy();

    /**
     * @notice Thrown when y and z values do not converge during square root calculation.
     */
    error SqrtError();

    /// @notice Reverse mapping of LP token to pool info.
    mapping(address => PoolData) public lpTokenToPool;

    /**
     * @param _systemRegistry Instance of system registry for this version of the system.
     * @param _curveResolver Instance of Curve Resolver.
     */
    constructor(
        ISystemRegistry _systemRegistry,
        ICurveResolver _curveResolver
    ) SystemComponent(_systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");
        Errors.verifyNotZero(address(_curveResolver), "_curveResolver");

        curveResolver = _curveResolver;
    }

    /**
     * @notice Allows owner of system to register a pool.
     * @param curvePool Address of CurveV2 pool.
     * @param curveLpToken Address of LP token associated with v2 pool.
     * @param checkReentrancy Whether to check read-only reentrancy on pool.
     */
    function registerPool(address curvePool, address curveLpToken, bool checkReentrancy) external onlyOwner {
        Errors.verifyNotZero(curvePool, "curvePool");
        Errors.verifyNotZero(curveLpToken, "curveLpToken");
        if (lpTokenToPool[curveLpToken].pool != address(0)) revert AlreadyRegistered(curveLpToken);

        (address[8] memory tokens, uint256 numTokens, address lpToken, bool isStableSwap) =
            curveResolver.resolveWithLpToken(curvePool);

        // Only two token pools compatible with this contract.
        if (numTokens != 2) revert InvalidNumTokens(numTokens);
        if (isStableSwap) revert NotCryptoPool(curvePool);
        if (lpToken != curveLpToken) revert ResolverMismatch(curveLpToken, lpToken);

        // Only need ability to check for read-only reentrancy for pools containing native Eth.
        if (checkReentrancy) {
            if (tokens[0] != ETH && tokens[1] != ETH) revert MustHaveEthForReentrancy();
        }

        /**
         * Curve V2 pools always price second token in `coins` array in first token in `coins` array.  This means that
         *    if `coins[0]` is Weth, and `coins[1]` is rEth, the price will be rEth as base and weth as quote.  Hence
         *    to get lp price we will always want to use the second token in the array, priced in eth.
         */
        lpTokenToPool[lpToken] =
            PoolData({ pool: curvePool, checkReentrancy: checkReentrancy ? 1 : 0, tokenToPrice: tokens[1] });

        emit TokenRegistered(lpToken);
    }

    /**
     * @notice Allows owner of system to unregister curve pool.
     * @param curveLpToken Address of CurveV2 lp token to unregister.
     */
    function unregister(address curveLpToken) external onlyOwner {
        Errors.verifyNotZero(curveLpToken, "curveLpToken");

        if (lpTokenToPool[curveLpToken].pool == address(0)) revert NotRegistered(curveLpToken);

        delete lpTokenToPool[curveLpToken];

        emit TokenUnregistered(curveLpToken);
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        Errors.verifyNotZero(token, "token");

        PoolData memory poolInfo = lpTokenToPool[token];
        if (poolInfo.pool == address(0)) revert NotRegistered(token);

        ICryptoSwapPool cryptoPool = ICryptoSwapPool(poolInfo.pool);

        // Checking for read only reentrancy scenario.
        if (poolInfo.checkReentrancy == 1) {
            // This will fail in a reentrancy situation.
            cryptoPool.claim_admin_fees();
        }

        uint256 virtualPrice = cryptoPool.get_virtual_price();
        uint256 assetPrice = systemRegistry.rootPriceOracle().getPriceInEth(poolInfo.tokenToPrice);

        return (2 * virtualPrice * sqrt(assetPrice)) / 10 ** 18;
    }

    // solhint-disable max-line-length
    // Adapted from CurveV2 pools, see here:
    // https://github.com/curvefi/curve-crypto-contract/blob/d7d04cd9ae038970e40be850df99de8c1ff7241b/contracts/two/CurveCryptoSwap2.vy#L1330
    function sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 10 ** 18) / 2;
        uint256 y = x;

        for (uint256 i = 0; i < 256;) {
            if (z == y) {
                return y;
            }
            y = z;
            z = (x * 10 ** 18 / z + z) / 2;

            unchecked {
                ++i;
            }
        }
        revert SqrtError();
    }
}
