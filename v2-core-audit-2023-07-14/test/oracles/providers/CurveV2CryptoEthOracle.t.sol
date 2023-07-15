// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase
import { Test } from "forge-std/Test.sol";

import {
    CURVE_META_REGISTRY_MAINNET,
    CRV_ETH_CURVE_V2_LP,
    CRV_ETH_CURVE_V2_POOL,
    THREE_CURVE_MAINNET,
    STETH_WETH_CURVE_POOL,
    CVX_ETH_CURVE_V2_LP,
    STG_USDC_V2_POOL,
    STG_USDC_CURVE_V2_LP,
    CRV_MAINNET
} from "test/utils/Addresses.sol";

import { CurveV2CryptoEthOracle } from "src/oracles/providers/CurveV2CryptoEthOracle.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { RootPriceOracle } from "src/oracles/RootPriceOracle.sol";
import { CurveResolverMainnet } from "src/utils/CurveResolverMainnet.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveResolver } from "src/interfaces/utils/ICurveResolver.sol";
import { ICurveMetaRegistry } from "src/interfaces/external/curve/ICurveMetaRegistry.sol";
import { Errors } from "src/utils/Errors.sol";

contract CurveV2CryptoEthOracleTest is Test {
    SystemRegistry public registry;
    AccessController public accessControl;
    RootPriceOracle public oracle;

    CurveResolverMainnet public curveResolver;
    CurveV2CryptoEthOracle public curveOracle;

    event TokenRegistered(address lpToken);
    event TokenUnregistered(address lpToken);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_671_884);

        registry = new SystemRegistry(address(1), address(2));

        accessControl = new AccessController(address(registry));
        registry.setAccessController(address(accessControl));

        oracle = new RootPriceOracle(registry);
        registry.setRootPriceOracle(address(oracle));

        curveResolver = new CurveResolverMainnet(ICurveMetaRegistry(CURVE_META_REGISTRY_MAINNET));
        curveOracle =
            new CurveV2CryptoEthOracle(ISystemRegistry(address(registry)), ICurveResolver(address(curveResolver)));
    }

    // Constructor
    function test_RevertRootPriceOracleZeroAddress() external {
        SystemRegistry localRegistry = new SystemRegistry(address(1), address(2));
        AccessController localAccessControl = new AccessController(address(localRegistry));
        localRegistry.setAccessController(address(localAccessControl));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "rootPriceOracle"));
        new CurveV2CryptoEthOracle(localRegistry, curveResolver);
    }

    function test_RevertCurveResolverAddressZero() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "_curveResolver"));
        new CurveV2CryptoEthOracle(registry, ICurveResolver(address(0)));
    }

    function test_ProperlySetsState() external {
        assertEq(address(curveOracle.curveResolver()), address(curveResolver));
    }

    // Register
    function test_RevertNonOwnerRegister() external {
        vm.prank(address(1));
        vm.expectRevert(Errors.AccessDenied.selector);
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CRV_ETH_CURVE_V2_LP, false);
    }

    function test_RevertZeroAddressCurvePool() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "curvePool"));
        curveOracle.registerPool(address(0), CRV_ETH_CURVE_V2_LP, false);
    }

    function test_ZeroAddressLpTokenRegistration() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "curveLpToken"));
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, address(0), false);
    }

    function test_LpTokenAlreadyRegistered() external {
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CRV_ETH_CURVE_V2_LP, false);

        vm.expectRevert(abi.encodeWithSelector(CurveV2CryptoEthOracle.AlreadyRegistered.selector, CRV_ETH_CURVE_V2_LP));
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CRV_ETH_CURVE_V2_LP, false);
    }

    function test_InvalidTokenNumber() external {
        vm.expectRevert(abi.encodeWithSelector(CurveV2CryptoEthOracle.InvalidNumTokens.selector, 3));
        curveOracle.registerPool(THREE_CURVE_MAINNET, CRV_ETH_CURVE_V2_LP, false);
    }

    function test_NotCryptoPool() external {
        vm.expectRevert(abi.encodeWithSelector(CurveV2CryptoEthOracle.NotCryptoPool.selector, STETH_WETH_CURVE_POOL));
        curveOracle.registerPool(STETH_WETH_CURVE_POOL, CRV_ETH_CURVE_V2_LP, false);
    }

    function test_LpTokenMistmatch() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                CurveV2CryptoEthOracle.ResolverMismatch.selector, CVX_ETH_CURVE_V2_LP, CRV_ETH_CURVE_V2_LP
            )
        );
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CVX_ETH_CURVE_V2_LP, false);
    }

    function test_ReentrancyRegistration() external {
        vm.expectRevert(CurveV2CryptoEthOracle.MustHaveEthForReentrancy.selector);
        curveOracle.registerPool(STG_USDC_V2_POOL, STG_USDC_CURVE_V2_LP, true);
    }

    function test_ProperRegistration() external {
        vm.expectEmit(false, false, false, true);
        emit TokenRegistered(CRV_ETH_CURVE_V2_LP);

        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CRV_ETH_CURVE_V2_LP, false);

        (address pool, uint8 reentrancy, address priceToken) = curveOracle.lpTokenToPool(CRV_ETH_CURVE_V2_LP);
        assertEq(pool, CRV_ETH_CURVE_V2_POOL);
        assertEq(reentrancy, 0);
        assertEq(priceToken, CRV_MAINNET);
    }

    // Unregister
    function test_RevertNonOwnerUnRegister() external {
        vm.prank(address(1));
        vm.expectRevert(Errors.AccessDenied.selector);
        curveOracle.unregister(CRV_ETH_CURVE_V2_LP);
    }

    function test_RevertZeroAddressUnRegister() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "curveLpToken"));
        curveOracle.unregister(address(0));
    }

    function test_LpNotRegistered() external {
        vm.expectRevert(abi.encodeWithSelector(CurveV2CryptoEthOracle.NotRegistered.selector, CRV_ETH_CURVE_V2_LP));
        curveOracle.unregister(CRV_ETH_CURVE_V2_LP);
    }

    function test_ProperUnRegister() external {
        // Register first
        curveOracle.registerPool(CRV_ETH_CURVE_V2_POOL, CRV_ETH_CURVE_V2_LP, false);

        vm.expectEmit(false, false, false, true);
        emit TokenUnregistered(CRV_ETH_CURVE_V2_LP);

        curveOracle.unregister(CRV_ETH_CURVE_V2_LP);

        (address pool, uint8 reentrancy, address tokenToPrice) = curveOracle.lpTokenToPool(CRV_ETH_CURVE_V2_LP);
        assertEq(pool, address(0));
        assertEq(reentrancy, 0);
        assertEq(tokenToPrice, address(0));
    }

    // getPriceInEth
    // Actual pricing return functionality tested in `RootPriceOracleIntegrationTest.sol`
    function test_RevertTokenZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "token"));
        curveOracle.getPriceInEth(address(0));
    }

    function test_RevertTokenNotRegistered() external {
        vm.expectRevert(abi.encodeWithSelector(CurveV2CryptoEthOracle.NotRegistered.selector, CRV_ETH_CURVE_V2_LP));
        curveOracle.getPriceInEth(CRV_ETH_CURVE_V2_LP);
    }
}
