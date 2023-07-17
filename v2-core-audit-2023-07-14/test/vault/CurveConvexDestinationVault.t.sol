// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity >=0.8.17;

// solhint-disable func-name-mixedcase
// solhint-disable max-states-count

import { ISystemComponent } from "src/interfaces/ISystemComponent.sol";
import { Errors } from "src/utils/Errors.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { Roles } from "src/libs/Roles.sol";
import { DestinationVaultFactory } from "src/vault/DestinationVaultFactory.sol";
import { DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";
import { DestinationRegistry } from "src/destinations/DestinationRegistry.sol";
import { CurveConvexDestinationVault } from "src/vault/CurveConvexDestinationVault.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { LMPVaultRegistry } from "src/vault/LMPVaultRegistry.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { SwapRouter } from "src/swapper/SwapRouter.sol";
import { CurveV1StableSwap } from "src/swapper/adapters/CurveV1StableSwap.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import {
    CURVE_META_REGISTRY_MAINNET,
    WETH_MAINNET,
    ST_ETH_CURVE_LP_TOKEN_MAINNET,
    STETH_ETH_CURVE_POOL,
    CONVEX_BOOSTER,
    CVX_MAINNET,
    CRV_MAINNET,
    STETH_MAINNET,
    LDO_MAINNET,
    CURVE_STETH_ETH_WHALE
} from "test/utils/Addresses.sol";
import { CurveResolverMainnet } from "src/utils/CurveResolverMainnet.sol";
import { ICurveMetaRegistry } from "src/interfaces/external/curve/ICurveMetaRegistry.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";

contract CurveConvexDestinationVaultTests is Test {
    address private constant LP_TOKEN_WHALE = CURVE_STETH_ETH_WHALE; //~1712

    uint256 private _mainnetFork;

    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    DestinationVaultFactory private _destinationVaultFactory;
    DestinationVaultRegistry private _destinationVaultRegistry;
    DestinationRegistry private _destinationTemplateRegistry;

    ILMPVaultRegistry private _lmpVaultRegistry;
    IRootPriceOracle private _rootPriceOracle;

    IWETH9 private _asset;
    MainRewarder private _rewarder;

    IERC20 private _underlyer;

    CurveResolverMainnet private _curveResolver;
    CurveConvexDestinationVault private _destVault;

    SwapRouter private swapRouter;
    CurveV1StableSwap private curveSwapper;

    address[] private additionalTrackedTokens;

    function setUp() public {
        additionalTrackedTokens = new address[](0);

        _mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 16_728_070);
        vm.selectFork(_mainnetFork);

        vm.label(address(this), "testContract");

        _systemRegistry = new SystemRegistry(vm.addr(100), WETH_MAINNET);

        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));

        _asset = IWETH9(WETH_MAINNET);

        _systemRegistry.addRewardToken(WETH_MAINNET);

        _curveResolver = new CurveResolverMainnet(ICurveMetaRegistry(CURVE_META_REGISTRY_MAINNET));
        _systemRegistry.setCurveResolver(address(_curveResolver));

        // Setup swap router

        swapRouter = new SwapRouter(_systemRegistry);
        curveSwapper = new CurveV1StableSwap(address(swapRouter), address(_systemRegistry.weth()));
        // setup input for Curve STETH -> WETH
        int128 sellIndex = 1;
        int128 buyIndex = 0;
        ISwapRouter.SwapData[] memory stethSwapRoute = new ISwapRouter.SwapData[](1);
        stethSwapRoute[0] = ISwapRouter.SwapData({
            token: address(_systemRegistry.weth()),
            pool: STETH_ETH_CURVE_POOL,
            swapper: curveSwapper,
            data: abi.encode(sellIndex, buyIndex, true)
        });
        swapRouter.setSwapRoute(STETH_MAINNET, stethSwapRoute);
        _systemRegistry.setSwapRouter(address(swapRouter));
        vm.label(address(swapRouter), "swapRouter");
        vm.label(address(curveSwapper), "curveSwapper");

        // Setup the Destination system

        _destinationVaultRegistry = new DestinationVaultRegistry(_systemRegistry);
        _destinationTemplateRegistry = new DestinationRegistry(_systemRegistry);
        _systemRegistry.setDestinationTemplateRegistry(address(_destinationTemplateRegistry));
        _systemRegistry.setDestinationVaultRegistry(address(_destinationVaultRegistry));
        _destinationVaultFactory = new DestinationVaultFactory(_systemRegistry, 1, 1000);
        _destinationVaultRegistry.setVaultFactory(address(_destinationVaultFactory));

        _underlyer = IERC20(ST_ETH_CURVE_LP_TOKEN_MAINNET);
        vm.label(address(_underlyer), "underlyer");

        CurveConvexDestinationVault dvTemplate = new CurveConvexDestinationVault(_systemRegistry, CVX_MAINNET);
        bytes32 dvType = keccak256(abi.encode("template"));
        bytes32[] memory dvTypes = new bytes32[](1);
        dvTypes[0] = dvType;
        _destinationTemplateRegistry.addToWhitelist(dvTypes);
        address[] memory dvAddresses = new address[](1);
        dvAddresses[0] = address(dvTemplate);
        _destinationTemplateRegistry.register(dvTypes, dvAddresses);

        _accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        CurveConvexDestinationVault.InitParams memory initParams = CurveConvexDestinationVault.InitParams({
            curvePool: STETH_ETH_CURVE_POOL,
            convexStaking: 0x0A760466E1B4621579a82a39CB56Dda2F4E70f03,
            convexBooster: CONVEX_BOOSTER,
            convexPoolId: 25,
            baseAssetBurnTokenIndex: 0
        });
        bytes memory initParamBytes = abi.encode(initParams);

        address payable newVault = payable(
            _destinationVaultFactory.create(
                "template",
                address(_asset),
                address(_underlyer),
                additionalTrackedTokens,
                keccak256("salt1"),
                initParamBytes
            )
        );
        vm.label(newVault, "destVault");

        _destVault = CurveConvexDestinationVault(newVault);

        _rootPriceOracle = IRootPriceOracle(vm.addr(34_399));
        vm.label(address(_rootPriceOracle), "rootPriceOracle");

        _mockSystemBound(address(_systemRegistry), address(_rootPriceOracle));
        _systemRegistry.setRootPriceOracle(address(_rootPriceOracle));
        _mockRootPrice(address(_asset), 1 ether);
        _mockRootPrice(address(_underlyer), 2 ether);

        // Set lmp vault registry for permissions
        _lmpVaultRegistry = ILMPVaultRegistry(vm.addr(237_894));
        vm.label(address(_lmpVaultRegistry), "lmpVaultRegistry");
        _mockSystemBound(address(_systemRegistry), address(_lmpVaultRegistry));
        _systemRegistry.setLMPVaultRegistry(address(_lmpVaultRegistry));
    }

    function test_initializer_ConfiguresVault() public {
        CurveConvexDestinationVault.InitParams memory initParams = CurveConvexDestinationVault.InitParams({
            curvePool: STETH_ETH_CURVE_POOL,
            convexStaking: 0x0A760466E1B4621579a82a39CB56Dda2F4E70f03,
            convexBooster: CONVEX_BOOSTER,
            convexPoolId: 25,
            baseAssetBurnTokenIndex: 0
        });
        bytes memory initParamBytes = abi.encode(initParams);

        address payable newVault = payable(
            _destinationVaultFactory.create(
                "template",
                address(_asset),
                address(_underlyer),
                additionalTrackedTokens,
                keccak256("salt2"),
                initParamBytes
            )
        );

        assertTrue(DestinationVault(newVault).underlyingTokens().length > 0);
    }

    function testExchangeName() public {
        assertEq(_destVault.exchangeName(), "curve");
    }

    function testUnderlyingTokens() public {
        address[] memory tokens = _destVault.underlyingTokens();

        assertEq(tokens.length, 2);
        assertEq(IERC20(tokens[0]).symbol(), "WETH");
        assertEq(IERC20(tokens[1]).symbol(), "stETH");
    }

    function testDebtValueWithCurveBalance() public {
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(_destVault), 100e18);

        // We gave the lp token a value of 2 ETH
        assertEq(_destVault.debtValue(), 200e18);
    }

    function testDepositGoesToConvex() public {
        // Get some tokens to play with
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(this), 100e18);

        // Give us deposit rights
        _mockIsVault(address(this), true);

        // Deposit
        _underlyer.approve(address(_destVault), 100e18);
        _destVault.depositUnderlying(100e18);

        // Ensure the funds went to Convex
        assertEq(_destVault.externalBalance(), 100e18);
    }

    function testDebtValueWithCurveAndConvex() public {
        // Get some tokens to play with
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(this), 200e18);

        // Give us deposit rights
        _mockIsVault(address(this), true);

        // Deposit
        _underlyer.approve(address(_destVault), 100e18);
        _destVault.depositUnderlying(100e18);

        // Send some directly to contract to be Curve balance
        _underlyer.transfer(address(_destVault), 100e18);

        // We gave the lp token a value of 2 ETH
        assertEq(_destVault.debtValue(), 400e18);
        assertEq(_destVault.externalBalance(), 100e18);
        assertEq(_destVault.internalBalance(), 100e18);
    }

    function testCollectRewards() public {
        // Get some tokens to play with
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(this), 200e18);

        // Give us deposit rights
        _mockIsVault(address(this), true);

        // Deposit
        _underlyer.approve(address(_destVault), 100e18);
        _destVault.depositUnderlying(100e18);

        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);

        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));

        IERC20 ldo = IERC20(LDO_MAINNET);
        IERC20 crv = IERC20(CRV_MAINNET);
        IERC20 cvx = IERC20(CVX_MAINNET);

        uint256 preBalLDO = ldo.balanceOf(address(this));
        uint256 preBalCRV = crv.balanceOf(address(this));
        uint256 preBalCVX = cvx.balanceOf(address(this));

        (uint256[] memory amounts, address[] memory tokens) = _destVault.collectRewards();

        assertEq(amounts.length, tokens.length);
        assertEq(tokens.length, 3);
        assertEq(address(tokens[0]), LDO_MAINNET);
        assertEq(address(tokens[1]), CRV_MAINNET);
        assertEq(address(tokens[2]), CVX_MAINNET);

        assertTrue(amounts[0] > 0);
        assertTrue(amounts[1] > 0);
        assertTrue(amounts[2] > 0);

        uint256 afterBalLDO = ldo.balanceOf(address(this));
        uint256 afterBalCRV = crv.balanceOf(address(this));
        uint256 afterBalCVX = cvx.balanceOf(address(this));

        assertEq(amounts[0], afterBalLDO - preBalLDO);
        assertEq(amounts[1], afterBalCRV - preBalCRV);
        assertEq(amounts[2], afterBalCVX - preBalCVX);
    }

    function testWithdrawUnderlying() public {
        // Get some tokens to play with
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(this), 100e18);

        // Give us deposit rights
        _mockIsVault(address(this), true);

        // Deposit
        _underlyer.approve(address(_destVault), 100e18);
        _destVault.depositUnderlying(100e18);

        // Ensure the funds went to Convex
        assertEq(_destVault.externalBalance(), 100e18);

        address receiver = vm.addr(555);
        uint256 received = _destVault.withdrawUnderlying(50e18, receiver);

        assertEq(received, 50e18);
        assertEq(_underlyer.balanceOf(receiver), 50e18);
    }

    function testWithdrawBaseAsset() public {
        // Get some tokens to play with
        vm.prank(LP_TOKEN_WHALE);
        _underlyer.transfer(address(this), 100e18);

        // Give us deposit rights
        _mockIsVault(address(this), true);

        // Deposit
        _underlyer.approve(address(_destVault), 100e18);
        _destVault.depositUnderlying(100e18);

        address receiver = vm.addr(555);
        uint256 startingBalance = _asset.balanceOf(receiver);

        uint256 received = _destVault.withdrawBaseAsset(50e18, receiver);

        assertEq(_asset.balanceOf(receiver) - startingBalance, 53_285_100_736_620_025_561);
        assertEq(received, _asset.balanceOf(receiver) - startingBalance);
    }

    function _mockSystemBound(address registry, address addr) internal {
        vm.mockCall(addr, abi.encodeWithSelector(ISystemComponent.getSystemRegistry.selector), abi.encode(registry));
    }

    function _mockRootPrice(address token, uint256 price) internal {
        vm.mockCall(
            address(_rootPriceOracle),
            abi.encodeWithSelector(IRootPriceOracle.getPriceInEth.selector, token),
            abi.encode(price)
        );
    }

    function _mockIsVault(address vault, bool isVault) internal {
        vm.mockCall(
            address(_lmpVaultRegistry),
            abi.encodeWithSelector(ILMPVaultRegistry.isVault.selector, vault),
            abi.encode(isVault)
        );
    }
}
