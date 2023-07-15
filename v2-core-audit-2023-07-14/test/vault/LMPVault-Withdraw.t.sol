// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity >=0.8.7;

// solhint-disable func-name-mixedcase,max-states-count

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { LMPVault } from "src/vault/LMPVault.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { Pausable } from "src/security/Pausable.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { IStrategy } from "src/interfaces/strategy/IStrategy.sol";
import { LMPVaultRegistry } from "src/vault/LMPVaultRegistry.sol";
import { LMPVaultFactory } from "src/vault/LMPVaultFactory.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { ISystemComponent } from "src/interfaces/ISystemComponent.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { DestinationVaultFactory } from "src/vault/DestinationVaultFactory.sol";
import { DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";
import { DestinationRegistry } from "src/destinations/DestinationRegistry.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { IERC3156FlashBorrower } from "openzeppelin-contracts/interfaces/IERC3156FlashBorrower.sol";
import { SystemSecurity } from "src/security/SystemSecurity.sol";

contract LMPVaultTests is Test {
    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    SystemSecurity private _systemSecurity;

    TestERC20 private _asset;
    LMPVaultMinting private _lmpVault;

    function setUp() public {
        vm.label(address(this), "testContract");

        _systemRegistry = new SystemRegistry(vm.addr(100), vm.addr(101));

        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));

        _systemSecurity = new SystemSecurity(_systemRegistry);
        _systemRegistry.setSystemSecurity(address(_systemSecurity));

        _asset = new TestERC20("asset", "asset");
        _asset.setDecimals(9);
        vm.label(address(_asset), "asset");

        _lmpVault = new LMPVaultMinting(_systemRegistry, address(_asset));
        vm.label(address(_lmpVault), "lmpVault");
    }

    function test_constructor_UsesBaseAssetDecimals() public {
        assertEq(9, _lmpVault.decimals());
    }

    function test_setFeeSink_RequiresOwnerPermissions() public {
        address notAdmin = vm.addr(34_234);

        vm.startPrank(notAdmin);
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.setFeeSink(notAdmin);
        vm.stopPrank();

        _lmpVault.setFeeSink(notAdmin);
    }

    function test_setPerformanceFeeBps_RequiresFeeSetterRole() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.setPerformanceFeeBps(6);

        address feeSetter = vm.addr(234_234);
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, feeSetter);
        vm.prank(feeSetter);
        _lmpVault.setPerformanceFeeBps(6);
    }
}

contract LMPVaultMintingTests is Test {
    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    DestinationVaultFactory private _destinationVaultFactory;
    DestinationVaultRegistry private _destinationVaultRegistry;
    DestinationRegistry private _destinationTemplateRegistry;
    LMPVaultRegistry private _lmpVaultRegistry;
    LMPVaultFactory private _lmpVaultFactory;
    IRootPriceOracle private _rootPriceOracle;
    SystemSecurity private _systemSecurity;

    TestERC20 private _asset;
    TestERC20 private _toke;
    LMPVaultNavChange private _lmpVault;
    LMPVaultNavChange private _lmpVault2;
    MainRewarder private _rewarder;

    // Destinations
    TestERC20 private _underlyerOne;
    TestERC20 private _underlyerTwo;
    IDestinationVault private _destVaultOne;
    IDestinationVault private _destVaultTwo;

    address[] private _destinations = new address[](2);

    event FeeCollected(uint256 fees, address feeSink, uint256 mintedShares, uint256 profit, uint256 idle, uint256 debt);
    event PerformanceFeeSet(uint256 newFee);
    event FeeSinkSet(address newFeeSink);
    event NewNavHighWatermark(uint256 navPerShare, uint256 timestamp);
    event TotalSupplyLimitSet(uint256 limit);
    event PerWalletLimitSet(uint256 limit);
    event Shutdown();
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public {
        vm.label(address(this), "testContract");

        _toke = new TestERC20("test", "test");
        vm.label(address(_toke), "toke");

        _systemRegistry = new SystemRegistry(address(_toke), address(new TestERC20("weth", "weth")));
        _systemRegistry.addRewardToken(address(_toke));

        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));

        _lmpVaultRegistry = new LMPVaultRegistry(_systemRegistry);
        _systemRegistry.setLMPVaultRegistry(address(_lmpVaultRegistry));

        _systemSecurity = new SystemSecurity(_systemRegistry);
        _systemRegistry.setSystemSecurity(address(_systemSecurity));

        // Setup the LMP Vault

        _asset = new TestERC20("asset", "asset");
        _systemRegistry.addRewardToken(address(_asset));
        vm.label(address(_asset), "asset");

        address template = address(new LMPVaultNavChange(_systemRegistry, address(_asset)));

        _lmpVaultFactory = new LMPVaultFactory(_systemRegistry, template, 800, 100);
        _accessController.grantRole(Roles.REGISTRY_UPDATER, address(_lmpVaultFactory));

        uint256 limit = type(uint256).max;
        _lmpVault = LMPVaultNavChange(_lmpVaultFactory.createVault(limit, limit, "x", "y", keccak256("v1"), ""));
        vm.label(address(_lmpVault), "lmpVault");
        _rewarder = MainRewarder(address(_lmpVault.rewarder()));

        // Setup second LMP Vault
        _lmpVault2 = LMPVaultNavChange(_lmpVaultFactory.createVault(limit, limit, "x", "y", keccak256("v2"), ""));
        vm.label(address(_lmpVault2), "lmpVault2");

        // Setup the Destination system

        _destinationVaultRegistry = new DestinationVaultRegistry(_systemRegistry);
        _destinationTemplateRegistry = new DestinationRegistry(_systemRegistry);
        _systemRegistry.setDestinationTemplateRegistry(address(_destinationTemplateRegistry));
        _systemRegistry.setDestinationVaultRegistry(address(_destinationVaultRegistry));
        _destinationVaultFactory = new DestinationVaultFactory(_systemRegistry, 1, 1000);
        _destinationVaultRegistry.setVaultFactory(address(_destinationVaultFactory));

        _underlyerOne = new TestERC20("underlyerOne", "underlyerOne");
        vm.label(address(_underlyerOne), "underlyerOne");

        _underlyerTwo = new TestERC20("underlyerTwo", "underlyerTwo");
        vm.label(address(_underlyerTwo), "underlyerTwo");

        TestDestinationVault dvTemplate = new TestDestinationVault(_systemRegistry);
        bytes32 dvType = keccak256(abi.encode("template"));
        bytes32[] memory dvTypes = new bytes32[](1);
        dvTypes[0] = dvType;
        _destinationTemplateRegistry.addToWhitelist(dvTypes);
        address[] memory dvAddresses = new address[](1);
        dvAddresses[0] = address(dvTemplate);
        _destinationTemplateRegistry.register(dvTypes, dvAddresses);

        _accessController.grantRole(Roles.CREATE_DESTINATION_VAULT_ROLE, address(this));

        address[] memory additionalTrackedTokens = new address[](0);
        _destVaultOne = IDestinationVault(
            _destinationVaultFactory.create(
                "template",
                address(_asset),
                address(_underlyerOne),
                additionalTrackedTokens,
                keccak256("salt1"),
                abi.encode("")
            )
        );
        vm.label(address(_destVaultOne), "destVaultOne");

        _destVaultTwo = IDestinationVault(
            _destinationVaultFactory.create(
                "template",
                address(_asset),
                address(_underlyerTwo),
                additionalTrackedTokens,
                keccak256("salt2"),
                abi.encode("")
            )
        );
        vm.label(address(_destVaultTwo), "destVaultTwo");

        _destinations[0] = address(_destVaultOne);
        _destinations[1] = address(_destVaultTwo);

        // Add the new destinations to the LMP Vault

        _accessController.grantRole(Roles.DESTINATION_VAULTS_UPDATER, address(this));
        _accessController.grantRole(Roles.SET_WITHDRAWAL_QUEUE_ROLE, address(this));

        address[] memory destinationVaults = new address[](2);
        destinationVaults[0] = address(_destVaultOne);
        destinationVaults[1] = address(_destVaultTwo);
        _lmpVault.addDestinations(destinationVaults);
        _lmpVault.setWithdrawalQueue(destinationVaults);

        // Setup the price oracle

        // Token prices
        // _asset - 1:1 ETH
        // _underlyer1 - 1:2 ETH
        // _underlyer2 - 1:1 ETH

        _rootPriceOracle = IRootPriceOracle(vm.addr(34_399));
        vm.label(address(_rootPriceOracle), "rootPriceOracle");

        _mockSystemBound(address(_systemRegistry), address(_rootPriceOracle));
        _systemRegistry.setRootPriceOracle(address(_rootPriceOracle));
        _mockRootPrice(address(_asset), 1 ether);
        _mockRootPrice(address(_underlyerOne), 2 ether);
        _mockRootPrice(address(_underlyerTwo), 1 ether);
    }

    function test_SetUpState() public {
        assertEq(_lmpVault.asset(), address(_asset));
    }

    function test_Stubs() public {
        _lmpVault.setVerifyRebalance(true);

        (bool success, string memory message) =
            _lmpVault.verifyRebalance(address(0), address(0), 1, address(0), address(0), 1);

        assertEq(success, true);
        assertEq(message, "");

        _lmpVault.setVerifyRebalance(false);

        (success, message) = _lmpVault.verifyRebalance(address(0), address(0), 1, address(0), address(0), 1);

        assertEq(success, false);
        assertEq(message, "");

        _lmpVault.setVerifyRebalance(true, "x");

        (success, message) = _lmpVault.verifyRebalance(address(0), address(0), 1, address(0), address(0), 1);

        assertEq(success, true);
        assertEq(message, "x");

        _lmpVault.setVerifyRebalance(false, "y");

        (success, message) = _lmpVault.verifyRebalance(address(0), address(0), 1, address(0), address(0), 1);

        assertEq(success, false);
        assertEq(message, "y");

        _lmpVault.setVerifyRebalance(true, "");

        (success, message) = _lmpVault.verifyRebalance(address(0), address(0), 1, address(0), address(0), 1);

        assertEq(success, true);
        assertEq(message, "");
    }

    function testFuzz_deposit_NoNavChangeDuringWithdraw(
        uint256 amount,
        uint256 amountWithdraw,
        uint256 amount2,
        uint256 amountWithdraw2,
        uint256 rebalDivisor,
        bool rebalanceAmount1
    ) public {
        vm.assume(amount > 100);
        vm.assume(amount < 100_000_000e18);
        vm.assume(amountWithdraw > 100);
        vm.assume(amount >= amountWithdraw);
        vm.assume(type(uint256).max / _lmpVault.MAX_FEE_BPS() >= amount);
        vm.assume(type(uint256).max / _lmpVault.MAX_FEE_BPS() >= amountWithdraw);
        vm.assume(amount <= type(uint256).max / 2 / _lmpVault.MAX_FEE_BPS());

        vm.assume(amount2 > 100);
        vm.assume(amount2 < 100_000_000e18);
        vm.assume(amountWithdraw2 > 100);
        vm.assume(amount2 >= amountWithdraw2);
        vm.assume(type(uint256).max / _lmpVault.MAX_FEE_BPS() >= amount2);
        vm.assume(type(uint256).max / _lmpVault.MAX_FEE_BPS() >= amountWithdraw2);
        vm.assume(amount2 <= type(uint256).max / 2 / _lmpVault.MAX_FEE_BPS());

        vm.assume(rebalDivisor < (rebalanceAmount1 ? amount : amount2) / 2);
        vm.assume(rebalDivisor > 1);

        address user1 = vm.addr(100);
        vm.label(user1, "user1");
        address user2 = vm.addr(200);
        vm.label(user2, "user2");

        _asset.mint(user1, amount);
        _asset.mint(user2, amount2);

        vm.startPrank(user1);
        _asset.approve(address(_lmpVault), amount);
        _lmpVault.deposit(amount, user1);
        vm.stopPrank();
        vm.startPrank(user2);
        _asset.approve(address(_lmpVault), amount2);
        _lmpVault.deposit(amount2, user2);
        vm.stopPrank();

        address solver = vm.addr(23_423_434);
        vm.label(solver, "solver");
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);

        uint256 rebalanceOut = rebalanceAmount1 ? amount : amount2;

        // At time of writing LMPVault always returned true for verifyRebalance
        _underlyerOne.mint(solver, rebalanceOut);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), rebalanceOut);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            rebalanceOut / 2,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            rebalanceOut
        );
        vm.stopPrank();

        {
            uint256 max = _lmpVault.maxWithdraw(user1);
            vm.startPrank(user1);
            uint256 pull = amountWithdraw > max ? max / 2 > 0 ? max / 2 : max : amountWithdraw;

            if (pull > 0) {
                uint256 shares = _lmpVault.withdraw(pull, user1, user1);
                assertEq(shares > 0, true, "user1WithdrawShares");
            }
            vm.stopPrank();
        }

        {
            uint256 max = _lmpVault.maxWithdraw(user2);
            vm.startPrank(user2);
            uint256 pull = amountWithdraw2 > max ? max / 2 > 0 ? max / 2 : max : amountWithdraw2;

            if (pull > 0) {
                uint256 shares = _lmpVault.withdraw(pull, user2, user2);
                assertEq(shares > 0, true, "user2WithdrawShares");
            }
            vm.stopPrank();
        }
        {
            uint256 remainingShares = _lmpVault.balanceOf(user1);

            if (remainingShares > 0) {
                vm.prank(user1);
                uint256 assets = _lmpVault.redeem(remainingShares, user1, user1);
                assertEq(assets > 0, true, "user1RedeemAssets");
            }
        }
        {
            uint256 remainingShares = _lmpVault.balanceOf(user2);

            if (remainingShares > 0) {
                vm.prank(user2);
                uint256 assets = _lmpVault.redeem(remainingShares, user2, user2);
                assertEq(assets > 0, true, "user2RedeemAssets");
            }
        }

        // We've pulled everything
        assertEq(_lmpVault.totalDebt(), 0, "totalDebtPre");
        assertEq(_lmpVault.totalIdle(), 0, "totalIdlePre");

        _lmpVault.updateDebtReporting(_destinations);

        // Ensure this is still true after reporting
        assertEq(_lmpVault.totalDebt(), 0, "totalDebtPost");
        assertEq(_lmpVault.totalIdle(), 0, "totalIdlePost");
    }

    function test_setTotalSupplyLimit_AllowsZeroValue() public {
        _lmpVault.setTotalSupplyLimit(1);
        _lmpVault.setTotalSupplyLimit(0);
    }

    function test_setTotalSupplyLimit_SavesValue() public {
        _lmpVault.setTotalSupplyLimit(999);
        assertEq(_lmpVault.totalSupplyLimit(), 999);
    }

    function test_setTotalSupplyLimit_RevertIf_NotCalledByOwner() public {
        _lmpVault.setTotalSupplyLimit(0);

        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.setTotalSupplyLimit(999);
        vm.stopPrank();

        assertEq(_lmpVault.totalSupplyLimit(), 0);
        _lmpVault.setTotalSupplyLimit(999);
        assertEq(_lmpVault.totalSupplyLimit(), 999);
    }

    function test_setTotalSupplyLimit_EmitsTotalSupplyLimitSetEvent() public {
        vm.expectEmit(true, true, true, true);
        emit TotalSupplyLimitSet(999);
        _lmpVault.setTotalSupplyLimit(999);
    }

    function test_setPerWalletLimit_RevertIf_ZeroIsSet() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidParam.selector, "newWalletLimit"));
        _lmpVault.setPerWalletLimit(0);
    }

    function test_setPerWalletLimit_SavesValue() public {
        _lmpVault.setPerWalletLimit(999);
        assertEq(_lmpVault.perWalletLimit(), 999);
    }

    function test_setPerWalletLimit_RevertIf_NotCalledByOwner() public {
        _lmpVault.setPerWalletLimit(1);

        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.setPerWalletLimit(999);
        vm.stopPrank();

        assertEq(_lmpVault.perWalletLimit(), 1);
        _lmpVault.setPerWalletLimit(999);
        assertEq(_lmpVault.perWalletLimit(), 999);
    }

    function test_setPerWalletLimit_EmitsPerWalletLimitSetEvent() public {
        vm.expectEmit(true, true, true, true);
        emit PerWalletLimitSet(999);
        _lmpVault.setPerWalletLimit(999);
    }

    function test_shutdown_ProperlyReports() public {
        assertEq(_lmpVault.isShutdown(), false);
        _lmpVault.shutdown();
        assertEq(_lmpVault.isShutdown(), true);
    }

    function test_shutdown_EmitsShutdownEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Shutdown();
        _lmpVault.shutdown();
    }

    function test_shutdown_OnlyCallableByOwner() public {
        vm.startPrank(address(5));
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.shutdown();
        vm.stopPrank();

        _lmpVault.shutdown();
    }

    function test_deposit_RevertIf_Shutdown() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.shutdown();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1000, 0));
        _lmpVault.deposit(1000, address(this));
    }

    function test_deposit_InitialSharesMintedOneToOneIntoIdle() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        uint256 beforeShares = _lmpVault.balanceOf(address(this));
        uint256 beforeAsset = _asset.balanceOf(address(this));
        uint256 shares = _lmpVault.deposit(1000, address(this));
        uint256 afterShares = _lmpVault.balanceOf(address(this));
        uint256 afterAsset = _asset.balanceOf(address(this));

        assertEq(shares, 1000);
        assertEq(beforeAsset - afterAsset, 1000);
        assertEq(afterShares - beforeShares, 1000);
        assertEq(_lmpVault.totalIdle(), 1000);
    }

    function test_deposit_StartsEarningWhileStillReceivingToken() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        assertEq(_lmpVault.balanceOf(address(this)), 0);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 0);

        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _lmpVault.rewarder().addToWhitelist(address(this));
        _toke.mint(address(this), 1000e18);
        _toke.approve(address(_lmpVault.rewarder()), 1000e18);
        _lmpVault.rewarder().queueNewRewards(1000e18);

        uint256 shares = _lmpVault.deposit(1000, address(this));

        vm.roll(block.number + 10_000);

        assertEq(shares, 1000);
        assertEq(_lmpVault.balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().earned(address(this)), 1000e18, "earned");

        assertEq(_toke.balanceOf(address(this)), 0);
        _lmpVault.rewarder().getReward();
        assertEq(_toke.balanceOf(address(this)), 1000e18);
        assertEq(_lmpVault.rewarder().earned(address(this)), 0, "earnedAfter");
    }

    function test_deposit_RevertIf_NavChangesUnexpectedly() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(50, address(this));

        _lmpVault.doTweak(true);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavChanged.selector, 10_000, 5000));
        _lmpVault.deposit(50, address(this));
    }

    function test_deposit_RevertIf_SystemIsMidNavChange() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancerReentrant rebalancer = new FlashRebalancerReentrant(_lmpVault2, true, false, false, false);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavOpsInProgress.selector));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_deposit_RevertIf_Paused() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1000, 0));
        _lmpVault.deposit(1000, address(this));

        _lmpVault.unpause();
        _lmpVault.deposit(1000, address(this));
    }

    function test_deposit_RevertIf_PerWalletLimitIsHit() public {
        _lmpVault.setPerWalletLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1000, 50));
        _lmpVault.deposit(1000, address(this));

        _lmpVault.deposit(40, address(this));

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 11, 10));
        _lmpVault.deposit(11, address(this));
    }

    function test_deposit_RevertIf_TotalSupplyLimitIsHit() public {
        _lmpVault.setTotalSupplyLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1000, 50));
        _lmpVault.deposit(1000, address(this));

        _lmpVault.deposit(40, address(this));

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 11, 10));
        _lmpVault.deposit(11, address(this));
    }

    function test_deposit_RevertIf_TotalSupplyLimitIsSubsequentlyLowered() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.deposit(500, address(this));

        _lmpVault.setTotalSupplyLimit(50);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1, 0));
        _lmpVault.deposit(1, address(this));
    }

    function test_deposit_RevertIf_WalletLimitIsSubsequentlyLowered() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.deposit(500, address(this));

        _lmpVault.setPerWalletLimit(50);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 1, 0));
        _lmpVault.deposit(1, address(this));
    }

    function test_deposit_LowerPerWalletLimitIsRespected() public {
        _lmpVault.setPerWalletLimit(25);
        _lmpVault.setTotalSupplyLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626DepositExceedsMax.selector, 40, 25));
        _lmpVault.deposit(40, address(this));
    }

    function test_mint_RevertIf_Shutdown() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.shutdown();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1000, 0));
        _lmpVault.mint(1000, address(this));
    }

    function test_mint_RevertIf_Paused() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1000, 0));
        _lmpVault.mint(1000, address(this));

        _lmpVault.unpause();
        _lmpVault.mint(1000, address(this));
    }

    function test_mint_StartsEarningWhileStillReceivingToken() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        assertEq(_lmpVault.balanceOf(address(this)), 0);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 0);

        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _lmpVault.rewarder().addToWhitelist(address(this));
        _toke.mint(address(this), 1000e18);
        _toke.approve(address(_lmpVault.rewarder()), 1000e18);
        _lmpVault.rewarder().queueNewRewards(1000e18);

        uint256 assets = _lmpVault.mint(1000, address(this));

        vm.roll(block.number + 10_000);

        assertEq(assets, 1000);
        assertEq(_lmpVault.balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().earned(address(this)), 1000e18, "earned");

        assertEq(_toke.balanceOf(address(this)), 0);
        _lmpVault.rewarder().getReward();
        assertEq(_toke.balanceOf(address(this)), 1000e18);
        assertEq(_lmpVault.rewarder().earned(address(this)), 0, "earnedAfter");
    }

    function test_mint_RevertIf_NavChangesUnexpectedly() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.mint(50, address(this));

        _lmpVault.doTweak(true);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavChanged.selector, 10_000, 5000));
        _lmpVault.mint(50, address(this));
    }

    function test_mint_RevertIf_SystemIsMidNavChange() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancerReentrant rebalancer = new FlashRebalancerReentrant(_lmpVault2, false, true, false, false);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavOpsInProgress.selector));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_mint_RevertIf_PerWalletLimitIsHit() public {
        _lmpVault.setPerWalletLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1000, 50));
        _lmpVault.mint(1000, address(this));

        _lmpVault.mint(40, address(this));

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 11, 10));
        _lmpVault.mint(11, address(this));
    }

    function test_mint_RevertIf_TotalSupplyLimitIsHit() public {
        _lmpVault.setTotalSupplyLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1000, 50));
        _lmpVault.mint(1000, address(this));

        _lmpVault.mint(40, address(this));

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 11, 10));
        _lmpVault.mint(11, address(this));
    }

    function test_mint_RevertIf_TotalSupplyLimitIsSubsequentlyLowered() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(500, address(this));

        _lmpVault.setTotalSupplyLimit(50);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1, 0));
        _lmpVault.mint(1, address(this));
    }

    function test_mint_RevertIf_WalletLimitIsSubsequentlyLowered() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(500, address(this));

        _lmpVault.setPerWalletLimit(50);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 1, 0));
        _lmpVault.mint(1, address(this));
    }

    function test_mint_LowerPerWalletLimitIsRespected() public {
        _lmpVault.setPerWalletLimit(25);
        _lmpVault.setTotalSupplyLimit(50);
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626MintExceedsMax.selector, 40, 25));
        _lmpVault.mint(40, address(this));
    }

    function test_withdraw_RevertIf_Paused() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(1000, address(this));

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626ExceededMaxWithdraw.selector, address(this), 10, 0));
        _lmpVault.withdraw(10, address(this), address(this));

        _lmpVault.unpause();
        _lmpVault.withdraw(10, address(this), address(this));
    }

    function test_withdraw_AssetsComeFromIdleOneToOne() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        uint256 beforeShares = _lmpVault.balanceOf(address(this));
        uint256 beforeAsset = _asset.balanceOf(address(this));
        uint256 sharesBurned = _lmpVault.withdraw(1000, address(this), address(this));
        uint256 afterShares = _lmpVault.balanceOf(address(this));
        uint256 afterAsset = _asset.balanceOf(address(this));

        assertEq(1000, sharesBurned);
        assertEq(1000, beforeShares - afterShares);
        assertEq(1000, afterAsset - beforeAsset);
        assertEq(_lmpVault.totalIdle(), 0);
    }

    function test_withdraw_RevertIf_NavChangesUnexpectedly() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.mint(1000, address(this));

        _lmpVault.withdraw(100, address(this), address(this));

        _lmpVault.doTweak(true);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavChanged.selector, 10_000, 5000));
        _lmpVault.withdraw(100, address(this), address(this));
    }

    function test_withdraw_ClaimsRewardedTokens() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        assertEq(_lmpVault.balanceOf(address(this)), 0);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 0);

        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _lmpVault.rewarder().addToWhitelist(address(this));
        _toke.mint(address(this), 1000e18);
        _toke.approve(address(_lmpVault.rewarder()), 1000e18);
        _lmpVault.rewarder().queueNewRewards(1000e18);

        uint256 shares = _lmpVault.deposit(1000, address(this));

        vm.roll(block.number + 10_000);

        assertEq(shares, 1000);
        assertEq(_lmpVault.balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().earned(address(this)), 1000e18, "earned");

        assertEq(_toke.balanceOf(address(this)), 0);
        _lmpVault.withdraw(1000, address(this), address(this));
        assertEq(_toke.balanceOf(address(this)), 1000e18);
        assertEq(_lmpVault.rewarder().earned(address(this)), 0, "earnedAfter");
    }

    function test_withdraw_RevertIf_SystemIsMidNavChange() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancerReentrant rebalancer = new FlashRebalancerReentrant(_lmpVault2, false, false, true, false);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavOpsInProgress.selector));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_withdraw_ReceivesLessAssetsIfPriceDrop() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        // User is going to deposit 1000 asset
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // Deployed 200 asset to DV1
        _underlyerOne.mint(address(this), 100);
        _underlyerOne.approve(address(_lmpVault), 100);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            100,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            200
        );

        // Deploy 800 asset to DV2
        _underlyerTwo.mint(address(this), 800);
        _underlyerTwo.approve(address(_lmpVault), 800);
        _lmpVault.rebalance(
            address(_destVaultTwo),
            address(_underlyerTwo), // tokenIn
            800,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            800
        );

        // Drop the price of DV1 to 25% of original, so that 200 we transferred out is not only worth 50
        _mockRootPrice(address(_underlyerOne), 5e17);

        // Cashing in half of our shares
        // That should mean we get half of the 50 that DV1 is worth - 25
        // Then we get the rest from DV2
        // Even though we could recoup the whole thing from DV2, we hit DV1 so we have to take our loss

        uint256 balBefore = _asset.balanceOf(address(this));
        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(this), address(this), address(this), 425, 500);
        uint256 assets = _lmpVault.redeem(500, address(this), address(this));
        uint256 balAfter = _asset.balanceOf(address(this));

        assertEq(assets, 425, "returned");
        assertEq(balAfter - balBefore, 425, "actual");
    }

    function test_redeem_DestinationVaultRewardsGoToIdle() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        // User is going to deposit 1000 asset
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // Queue up some Destination Vault rewards
        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));

        _asset.mint(address(this), 2000);
        _asset.approve(_destVaultOne.rewarder(), 2000);
        IMainRewarder(_destVaultOne.rewarder()).queueNewRewards(2000);

        // Deployed 200 asset to DV1
        _underlyerOne.mint(address(this), 100);
        _underlyerOne.approve(address(_lmpVault), 100);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            100,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            200
        );

        // Roll the block so that the rewards we queued earlier will become available
        vm.roll(block.number + 10_000);

        assertEq(_lmpVault.totalIdle(), 800);

        uint256 assets = _lmpVault.redeem(1000, address(this), address(this));

        assertEq(_lmpVault.totalIdle(), 2000);

        // assertEq(assets, 425, "returned");
        // assertEq(balAfter - balBefore, 425, "actual");
    }

    function test_withdraw_ReceivesNoMoreThanCachedIfPriceIncreases() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        // User is going to deposit 1000 asset
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // Deployed 200 asset to DV1
        _underlyerOne.mint(address(this), 100);
        _underlyerOne.approve(address(_lmpVault), 100);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            100,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            200
        );

        // Deploy 800 asset to DV2
        _underlyerTwo.mint(address(this), 800);
        _underlyerTwo.approve(address(_lmpVault), 800);
        _lmpVault.rebalance(
            address(_destVaultTwo),
            address(_underlyerTwo), // tokenIn
            800,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            800
        );

        // Price of DV1 doubled
        _mockRootPrice(address(_underlyerOne), 4e18);

        // Cashing in 900 shares, which means we're entitled to at most 900 assets
        // We can get 400 from DV1, and we'll get the remaining 500 from DV2
        // Should leave us with no shares of DV1 and 300 of DV2

        uint256 balBefore = _asset.balanceOf(address(this));
        // vm.expectEmit(true, true, true, true);
        // emit Withdraw(address(this), address(this), address(this), 425, 500);
        uint256 assets = _lmpVault.redeem(900, address(this), address(this));
        uint256 balAfter = _asset.balanceOf(address(this));

        assertEq(assets, 900, "returned");
        assertEq(balAfter - balBefore, 900, "actual");
    }

    function test_redeem_RevertIf_Paused() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(1000, address(this));

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626ExceededMaxRedeem.selector, address(this), 10, 0));
        _lmpVault.redeem(10, address(this), address(this));

        _lmpVault.unpause();
        _lmpVault.redeem(10, address(this), address(this));
    }

    function test_redeem_AssetsFromIdleOneToOne() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        uint256 beforeShares = _lmpVault.balanceOf(address(this));
        uint256 beforeAsset = _asset.balanceOf(address(this));
        uint256 assetsReceived = _lmpVault.redeem(1000, address(this), address(this));
        uint256 afterShares = _lmpVault.balanceOf(address(this));
        uint256 afterAsset = _asset.balanceOf(address(this));

        assertEq(1000, assetsReceived);
        assertEq(1000, beforeShares - afterShares);
        assertEq(1000, afterAsset - beforeAsset);
        assertEq(_lmpVault.totalIdle(), 0);
    }

    function test_redeem_RevertIf_NavChangesUnexpectedly() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.mint(1000, address(this));

        _lmpVault.redeem(100, address(this), address(this));

        _lmpVault.doTweak(true);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavChanged.selector, 10_000, 5000));
        _lmpVault.redeem(100, address(this), address(this));
    }

    function test_redeem_ClaimsRewardedTokens() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        assertEq(_lmpVault.balanceOf(address(this)), 0);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 0);

        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _lmpVault.rewarder().addToWhitelist(address(this));
        _toke.mint(address(this), 1000e18);
        _toke.approve(address(_lmpVault.rewarder()), 1000e18);
        _lmpVault.rewarder().queueNewRewards(1000e18);

        uint256 shares = _lmpVault.deposit(1000, address(this));

        vm.roll(block.number + 10_000);

        assertEq(shares, 1000);
        assertEq(_lmpVault.balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().earned(address(this)), 1000e18, "earned");

        assertEq(_toke.balanceOf(address(this)), 0);
        _lmpVault.redeem(1000, address(this), address(this));
        assertEq(_toke.balanceOf(address(this)), 1000e18);
        assertEq(_lmpVault.rewarder().earned(address(this)), 0, "earnedAfter");
    }

    function test_redeem_RevertIf_SystemIsMidNavChange() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancerReentrant rebalancer = new FlashRebalancerReentrant(_lmpVault2, false, false, false, true);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.NavOpsInProgress.selector));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_transfer_RevertIf_DestinationWalletLimitReached() public {
        address user1 = address(4);
        address user2 = address(5);
        address user3 = address(6);

        _asset.mint(address(this), 1500);
        _asset.approve(address(_lmpVault), 1500);

        _lmpVault.mint(500, user1);
        _lmpVault.mint(500, user2);
        _lmpVault.mint(500, user3);

        _lmpVault.setPerWalletLimit(1000);

        // User 2 should have exactly limit
        vm.prank(user1);
        _lmpVault.transfer(user2, 500);

        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSelector(LMPVault.OverWalletLimit.selector, user2));
        _lmpVault.transfer(user2, 1);
        vm.stopPrank();
    }

    function test_transfer_RevertIf_Paused() public {
        address recipient = address(4);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(1000, address(this));

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.IsPaused.selector));
        _lmpVault.transfer(recipient, 10);
    }

    function test_transferFrom_RevertIf_DestinationWalletLimitReached() public {
        address user1 = address(4);
        address user2 = address(5);
        address user3 = address(6);

        _asset.mint(address(this), 1500);
        _asset.approve(address(_lmpVault), 1500);

        _lmpVault.mint(500, user1);
        _lmpVault.mint(500, user2);
        _lmpVault.mint(500, user3);

        _lmpVault.setPerWalletLimit(1000);

        // User 2 should have exactly limit
        vm.prank(user1);
        _lmpVault.approve(address(this), 500);

        vm.prank(user3);
        _lmpVault.approve(address(this), 1);

        _lmpVault.transferFrom(user1, user2, 500);

        vm.expectRevert(abi.encodeWithSelector(LMPVault.OverWalletLimit.selector, user2));
        _lmpVault.transferFrom(user3, user2, 1);
    }

    function test_transferFrom_RevertIf_Paused() public {
        address recipient = address(4);
        address user = address(5);

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        _lmpVault.mint(1000, address(this));

        _lmpVault.approve(user, 500);

        _accessController.grantRole(Roles.EMERGENCY_PAUSER, address(this));
        _lmpVault.pause();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Pausable.IsPaused.selector));
        _lmpVault.transferFrom(address(this), recipient, 10);
        vm.stopPrank();
    }

    function test_transfer_ClaimsRewardedTokensAndRecipientStartsEarning() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);

        assertEq(_lmpVault.balanceOf(address(this)), 0);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 0);

        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _lmpVault.rewarder().addToWhitelist(address(this));
        _toke.mint(address(this), 1000e18);
        _toke.approve(address(_lmpVault.rewarder()), 1000e18);
        _lmpVault.rewarder().queueNewRewards(1000e18);

        uint256 shares = _lmpVault.deposit(1000, address(this));

        vm.roll(block.number + 3);

        address receiver = vm.addr(2_347_845);
        vm.label(receiver, "receiver");

        assertEq(shares, 1000);
        assertEq(_lmpVault.balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().balanceOf(address(this)), 1000);
        assertEq(_lmpVault.rewarder().earned(address(this)), 30e18, "earned");

        assertEq(_toke.balanceOf(address(this)), 0);
        _lmpVault.transfer(receiver, 1000);
        assertEq(_toke.balanceOf(address(this)), 30e18);
        assertEq(_lmpVault.rewarder().earned(address(this)), 0, "earnedAfter");

        vm.roll(block.number + 6);

        assertEq(_lmpVault.rewarder().earned(receiver), 90e18, "recipientEarned");
        vm.prank(receiver);
        _lmpVault.withdraw(1000, receiver, receiver);
        assertEq(_toke.balanceOf(receiver), 90e18);
        assertEq(_lmpVault.rewarder().earned(receiver), 0, "recipientEarnedAfter");
    }

    function test_rebalance_IdleAssetsCanLeaveAndReturn() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne
        uint256 assetBalBefore = _asset.balanceOf(address(this));
        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );
        uint256 assetBalAfter = _asset.balanceOf(address(this));

        // LMP Vault is correctly tracking 500 remaining in idle, 500 out as debt
        uint256 totalIdleAfterFirstRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterFirstRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterFirstRebalance, 500, "totalIdleAfterFirstRebalance");
        assertEq(totalDebtAfterFirstRebalance, 500, "totalDebtAfterFirstRebalance");
        // The destination vault has the 250 underlying
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 250);
        // The lmp vault has the 250 of the destination
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 250);
        // Ensure the solver got their funds
        assertEq(assetBalAfter - assetBalBefore, 500, "solverAssetBal");

        // Rebalance some of the baseAsset back
        // We want 137 of the base asset back from the destination vault
        // For 125 of the destination (bad deal but eh)
        uint256 balanceOfUnderlyerBefore = _underlyerOne.balanceOf(address(this));

        _asset.mint(address(this), 137);
        _asset.approve(address(_lmpVault), 137);
        _lmpVault.rebalance(
            address(0), // none when sending in base asset
            address(_asset), // tokenIn
            137,
            address(_destVaultOne), // destinationOut
            address(_underlyerOne), // tokenOut
            125
        );

        uint256 balanceOfUnderlyerAfter = _underlyerOne.balanceOf(address(this));

        uint256 totalIdleAfterSecondRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterSecondRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterSecondRebalance, 637, "totalIdleAfterSecondRebalance");
        assertEq(totalDebtAfterSecondRebalance, 250, "totalDebtAfterSecondRebalance");
        assertEq(balanceOfUnderlyerAfter - balanceOfUnderlyerBefore, 125);
    }

    function test_rebalance_IdleCantLeaveIfShutdown() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        _lmpVault.shutdown();

        vm.expectRevert(abi.encodeWithSelector(LMPVault.VaultShutdown.selector));
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );
    }

    function test_rebalance_AccountsForClaimedDvRewardsIntoIdle() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // Queue up some Destination Vault rewards
        _accessController.grantRole(Roles.DV_REWARD_MANAGER_ROLE, address(this));
        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));
        _asset.mint(address(this), 2000);
        _asset.approve(_destVaultOne.rewarder(), 2000);
        IMainRewarder(_destVaultOne.rewarder()).queueNewRewards(2000);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne
        uint256 assetBalBefore = _asset.balanceOf(address(this));
        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );
        uint256 assetBalAfter = _asset.balanceOf(address(this));

        // LMP Vault is correctly tracking 500 remaining in idle, 500 out as debt
        uint256 totalIdleAfterFirstRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterFirstRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterFirstRebalance, 500, "totalIdleAfterFirstRebalance");
        assertEq(totalDebtAfterFirstRebalance, 500, "totalDebtAfterFirstRebalance");
        // The destination vault has the 250 underlying
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 250);
        // The lmp vault has the 250 of the destination
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 250);
        // Ensure the solver got their funds
        assertEq(assetBalAfter - assetBalBefore, 500, "solverAssetBal");

        // Rebalance some of the baseAsset back
        // We want 137 of the base asset back from the destination vault
        // For 125 of the destination (bad deal but eh)
        uint256 balanceOfUnderlyerBefore = _underlyerOne.balanceOf(address(this));

        // Roll the block so that the rewards we queued earlier will become available
        vm.roll(block.number + 100);

        _asset.mint(address(this), 137);
        _asset.approve(address(_lmpVault), 137);
        _lmpVault.rebalance(
            address(0), // none when sending in base asset
            address(_asset), // tokenIn
            137,
            address(_destVaultOne), // destinationOut
            address(_underlyerOne), // tokenOut
            125
        );

        uint256 balanceOfUnderlyerAfter = _underlyerOne.balanceOf(address(this));

        uint256 totalIdleAfterSecondRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterSecondRebalance = _lmpVault.totalDebt();

        // Without the DV rewards, we should be at 637. Since we'll claim those rewards
        // as part of the rebalance, they'll get factored into idle
        assertEq(totalIdleAfterSecondRebalance, 837, "totalIdleAfterSecondRebalance");
        assertEq(totalDebtAfterSecondRebalance, 250, "totalDebtAfterSecondRebalance");
        assertEq(balanceOfUnderlyerAfter - balanceOfUnderlyerBefore, 125);
    }

    function test_rebalance_WithdrawsPossibleAfterRebalance() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));
        assertEq(_lmpVault.balanceOf(address(this)), 1000, "initialLMPBalance");

        uint256 startingAssetBalance = _asset.balanceOf(address(this));
        address solver = vm.addr(23_423_434);
        vm.label(solver, "solver");
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 1000 baseAsset for 500 underlyerOne+destVaultOne
        _underlyerOne.mint(solver, 250);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 250);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );
        vm.stopPrank();

        // At this point we've transferred 500 idle out, which means we
        // should have 500 left
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.totalDebt(), 500);

        // We withdraw 400 assets which we can get all from idle
        uint256 sharesBurned = _lmpVault.withdraw(400, address(this), address(this));

        // So we should have 100 left now
        assertEq(_lmpVault.totalIdle(), 100);
        assertEq(sharesBurned, 400);
        assertEq(_lmpVault.balanceOf(address(this)), 600);

        // Just verifying that the destination vault does hold the amount
        // of the underlyer that we rebalanced.in before
        uint256 duOneBal = _underlyerOne.balanceOf(address(_destVaultOne));
        uint256 originalDv1Shares = _destVaultOne.balanceOf(address(_lmpVault));
        assertEq(duOneBal, 250);
        assertEq(originalDv1Shares, 250);

        // Lets then withdraw half of the rest which should get 100
        // from idle, and then need to get 200 from the destination vault
        uint256 sharesBurned2 = _lmpVault.withdraw(300, address(this), address(this));

        assertEq(sharesBurned2, 300);
        assertEq(_lmpVault.balanceOf(address(this)), 300);

        // Underlyer is worth 2:1 WETH so to get 200, we'd need to burn 100
        // shares of the destination vault since dv shares are 1:1 to underlyer
        // We originally had 250 shares - 100 so 150 left

        uint256 remainingDv1Shares = _destVaultOne.balanceOf(address(_lmpVault));
        assertEq(remainingDv1Shares, 150);
        // We've withdrew 400 then 300 assets. Make sure we have them
        uint256 assetBalanceCheck1 = _asset.balanceOf(address(this));
        assertEq(assetBalanceCheck1 - startingAssetBalance, 700);

        // Just as a test, we should only have 300 more to pull, trying to pull
        // more would require more shares which we don't have
        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626ExceededMaxWithdraw.selector, address(this), 400, 300));
        _lmpVault.withdraw(400, address(this), address(this));

        // Pull the amount of assets we have shares for
        uint256 sharesBurned3 = _lmpVault.withdraw(300, address(this), address(this));
        uint256 assetBalanceCheck3 = _asset.balanceOf(address(this));

        assertEq(sharesBurned3, 300);
        assertEq(assetBalanceCheck3, 1000);

        // We've pulled everything
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);

        _lmpVault.updateDebtReporting(_destinations);

        // Ensure this is still true after reporting
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);
    }

    function test_rebalance_CantRebalanceToTheSameDestination() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        address solver = vm.addr(23_423_434);
        vm.label(solver, "solver");
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 1000 baseAsset for 500 underlyerOne+destVaultOne
        _underlyerOne.mint(solver, 250);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 250);
        vm.expectRevert(abi.encodeWithSelector(LMPVault.RebalanceDestinationsMatch.selector, address(_destVaultOne)));
        _lmpVault.rebalance(
            address(_destVaultOne), address(_underlyerOne), 250, address(_destVaultOne), address(_underlyerOne), 500
        );
        vm.stopPrank();
    }

    function test_rebalance_WithdrawsPossibleAfterRebalanceToMultipleDestinations() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));
        assertEq(_lmpVault.balanceOf(address(this)), 1000, "initialLMPBalance");

        address solver = vm.addr(23_423_434);
        vm.label(solver, "solver");
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);

        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne
        _underlyerOne.mint(solver, 250);
        _underlyerTwo.mint(solver, 250);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 250);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );
        _underlyerTwo.approve(address(_lmpVault), 250);
        _lmpVault.rebalance(
            address(_destVaultTwo),
            address(_underlyerTwo), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            250
        );
        vm.stopPrank();

        // At this point we've transferred 750 idle out, which means we
        // should have 250 left
        assertEq(_lmpVault.totalIdle(), 250);
        assertEq(_lmpVault.totalDebt(), 750);

        // We withdraw 400 assets which we can get all from idle
        uint256 sharesBurned = _lmpVault.withdraw(400, address(this), address(this));

        // So we should have 0 idle left now
        assertEq(_lmpVault.totalIdle(), 0);
        assertEq(sharesBurned, 400);
        assertEq(_lmpVault.balanceOf(address(this)), 600);

        // Just verifying that the destination vault does hold the amount
        // of the underlyer they should. We got 250 of our assets from idle
        // leave 150 to pull from D1. That should have taken 75 shares of our
        uint256 duOneBal = _underlyerOne.balanceOf(address(_destVaultOne));
        uint256 originalDv1Shares = _destVaultOne.balanceOf(address(_lmpVault));
        assertEq(duOneBal, 175);
        assertEq(originalDv1Shares, 175);

        // Lets withdraw 400 now. We can get 350 from D1 and the rest from D2
        uint256 sharesBurned2 = _lmpVault.withdraw(400, address(this), address(this));

        assertEq(sharesBurned2, 400);
        assertEq(_lmpVault.balanceOf(address(this)), 200);
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 0);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 0);
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 200);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 200);

        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626ExceededMaxWithdraw.selector, address(this), 400, 200));
        _lmpVault.withdraw(400, address(this), address(this));

        // Pull the amount of assets we have shares for
        uint256 sharesBurned3 = _lmpVault.withdraw(200, address(this), address(this));
        uint256 assetBalanceCheck3 = _asset.balanceOf(address(this));

        assertEq(sharesBurned3, 200);
        assertEq(assetBalanceCheck3, 1000);

        // We've pulled everything
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);

        _lmpVault.updateDebtReporting(_destinations);

        // Ensure this is still true after reporting
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);
    }

    function test_flashRebalance_IdleCantLeaveIfShutdown() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        _lmpVault.shutdown();

        vm.expectRevert(abi.encodeWithSelector(LMPVault.VaultShutdown.selector));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_flashRebalance_IdleAssetsCanLeaveAndReturn() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne
        uint256 assetBalBefore = _asset.balanceOf(address(rebalancer));

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );

        uint256 assetBalAfter = _asset.balanceOf(address(rebalancer));

        // LMP Vault is correctly tracking 500 remaining in idle, 500 out as debt
        uint256 totalIdleAfterFirstRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterFirstRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterFirstRebalance, 500, "totalIdleAfterFirstRebalance");
        assertEq(totalDebtAfterFirstRebalance, 500, "totalDebtAfterFirstRebalance");
        // The destination vault has the 250 underlying
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 250);
        // The lmp vault has the 250 of the destination
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 250);
        // Ensure the solver got their funds
        assertEq(assetBalAfter - assetBalBefore, 500, "solverAssetBal");

        // Rebalance some of the baseAsset back
        // We want 137 of the base asset back from the destination vault
        // For 125 of the destination (bad deal but eh)
        uint256 balanceOfUnderlyerBefore = _underlyerOne.balanceOf(address(rebalancer));

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_underlyerOne), 125);

        _asset.mint(address(this), 137);
        _asset.approve(address(_lmpVault), 137);
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(0), // none when sending in base asset
                tokenIn: address(_asset), // tokenIn
                amountIn: 137,
                destinationOut: address(_destVaultOne), // destinationOut
                tokenOut: address(_underlyerOne), // tokenOut
                amountOut: 125
            }),
            abi.encode("")
        );

        uint256 balanceOfUnderlyerAfter = _underlyerOne.balanceOf(address(rebalancer));

        uint256 totalIdleAfterSecondRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterSecondRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterSecondRebalance, 637, "totalIdleAfterSecondRebalance");
        assertEq(totalDebtAfterSecondRebalance, 250, "totalDebtAfterSecondRebalance");
        assertEq(balanceOfUnderlyerAfter - balanceOfUnderlyerBefore, 125);
    }

    function test_flashRebalance_AccountsForClaimedDvRewardsIntoIdle() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));
        _asset.mint(address(this), 2000);
        _asset.approve(_destVaultOne.rewarder(), 2000);
        IMainRewarder(_destVaultOne.rewarder()).queueNewRewards(2000);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne
        uint256 assetBalBefore = _asset.balanceOf(address(rebalancer));

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );

        uint256 assetBalAfter = _asset.balanceOf(address(rebalancer));

        // LMP Vault is correctly tracking 500 remaining in idle, 500 out as debt
        uint256 totalIdleAfterFirstRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterFirstRebalance = _lmpVault.totalDebt();
        assertEq(totalIdleAfterFirstRebalance, 500, "totalIdleAfterFirstRebalance");
        assertEq(totalDebtAfterFirstRebalance, 500, "totalDebtAfterFirstRebalance");
        // The destination vault has the 250 underlying
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 250);
        // The lmp vault has the 250 of the destination
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 250);
        // Ensure the solver got their funds
        assertEq(assetBalAfter - assetBalBefore, 500, "solverAssetBal");

        // Rebalance some of the baseAsset back
        // We want 137 of the base asset back from the destination vault
        // For 125 of the destination (bad deal but eh)
        uint256 balanceOfUnderlyerBefore = _underlyerOne.balanceOf(address(rebalancer));

        // Roll the block so that the rewards we queued earlier will become available
        vm.roll(block.number + 100);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_underlyerOne), 125);

        _asset.mint(address(this), 137);
        _asset.approve(address(_lmpVault), 137);
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(0), // none when sending in base asset
                tokenIn: address(_asset), // tokenIn
                amountIn: 137,
                destinationOut: address(_destVaultOne), // destinationOut
                tokenOut: address(_underlyerOne), // tokenOut
                amountOut: 125
            }),
            abi.encode("")
        );

        uint256 balanceOfUnderlyerAfter = _underlyerOne.balanceOf(address(rebalancer));

        uint256 totalIdleAfterSecondRebalance = _lmpVault.totalIdle();
        uint256 totalDebtAfterSecondRebalance = _lmpVault.totalDebt();

        // Without the DV rewards, we should be at 637. Since we'll claim those rewards
        // as part of the rebalance, they'll get factored into idle
        assertEq(totalIdleAfterSecondRebalance, 837, "totalIdleAfterSecondRebalance");
        assertEq(totalDebtAfterSecondRebalance, 250, "totalDebtAfterSecondRebalance");
        assertEq(balanceOfUnderlyerAfter - balanceOfUnderlyerBefore, 125);
    }

    function test_flashRebalance_WithdrawsPossibleAfterRebalance() public {
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));
        assertEq(_lmpVault.balanceOf(address(this)), 1000, "initialLMPBalance");

        FlashRebalancer rebalancer = new FlashRebalancer();

        uint256 startingAssetBalance = _asset.balanceOf(address(this));
        address solver = vm.addr(23_423_434);
        vm.label(solver, "solver");
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 1000 baseAsset for 500 underlyerOne+destVaultOne
        _underlyerOne.mint(solver, 250);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 250);
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none for baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );
        vm.stopPrank();

        // At this point we've transferred 500 idle out, which means we
        // should have 500 left
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.totalDebt(), 500);

        // We withdraw 400 assets which we can get all from idle
        uint256 sharesBurned = _lmpVault.withdraw(400, address(this), address(this));

        // So we should have 100 left now
        assertEq(_lmpVault.totalIdle(), 100);
        assertEq(sharesBurned, 400);
        assertEq(_lmpVault.balanceOf(address(this)), 600);

        // Just verifying that the destination vault does hold the amount
        // of the underlyer that we rebalanced.in before
        uint256 duOneBal = _underlyerOne.balanceOf(address(_destVaultOne));
        uint256 originalDv1Shares = _destVaultOne.balanceOf(address(_lmpVault));
        assertEq(duOneBal, 250);
        assertEq(originalDv1Shares, 250);

        // Lets then withdraw half of the rest which should get 100
        // from idle, and then need to get 200 from the destination vault
        uint256 sharesBurned2 = _lmpVault.withdraw(300, address(this), address(this));

        assertEq(sharesBurned2, 300);
        assertEq(_lmpVault.balanceOf(address(this)), 300);

        // Underlyer is worth 2:1 WETH so to get 200, we'd need to burn 100
        // shares of the destination vault since dv shares are 1:1 to underlyer
        // We originally had 250 shares - 100 so 150 left

        uint256 remainingDv1Shares = _destVaultOne.balanceOf(address(_lmpVault));
        assertEq(remainingDv1Shares, 150);
        // We've withdrew 400 then 300 assets. Make sure we have them
        uint256 assetBalanceCheck1 = _asset.balanceOf(address(this));
        assertEq(assetBalanceCheck1 - startingAssetBalance, 700);

        // Just as a test, we should only have 300 more to pull, trying to pull
        // more would require more shares which we don't have
        vm.expectRevert(abi.encodeWithSelector(ILMPVault.ERC4626ExceededMaxWithdraw.selector, address(this), 400, 300));
        _lmpVault.withdraw(400, address(this), address(this));

        // Pull the amount of assets we have shares for
        uint256 sharesBurned3 = _lmpVault.withdraw(300, address(this), address(this));
        uint256 assetBalanceCheck3 = _asset.balanceOf(address(this));

        assertEq(sharesBurned3, 300);
        assertEq(assetBalanceCheck3, 1000);

        // We've pulled everything
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);

        _lmpVault.updateDebtReporting(_destinations);

        // Ensure this is still true after reporting
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);
    }

    function test_flashRebalance_CantRebalanceToTheSameDestination() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        vm.expectRevert(abi.encodeWithSelector(LMPVault.RebalanceDestinationsMatch.selector, address(_destVaultOne)));
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne),
                amountIn: 250,
                destinationOut: address(_destVaultOne),
                tokenOut: address(_underlyerOne),
                amountOut: 500
            }),
            abi.encode("")
        );
    }

    function test_updateDebtReporting_FeesAreTakenWithoutDoubleDipping() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        // User is going to deposit 1000 asset
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 1000 baseAsset for 500 underlyerOne+destVaultOne (price is 2:1)
        _underlyerOne.mint(address(this), 250);
        _underlyerOne.approve(address(_lmpVault), 250);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            250,
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            500
        );

        // Setting a sink but not an actual fee yet
        address feeSink = vm.addr(555);
        _lmpVault.setFeeSink(feeSink);

        // Dropped 1000 asset in and just did a rebalance. There's no slippage or anything
        // atm so assets are just moved around, should still be reporting 1000 available
        uint256 shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 500);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1000);

        // Underlyer1 is currently worth 2 ETH a piece
        // Lets update the price to 1.5 ETH and trigger a debt reporting
        // and verify our totalDebt and asset conversions match the drop in price
        _mockRootPrice(address(_underlyerOne), 15e17);
        _lmpVault.updateDebtReporting(_destinations);

        // No change in idle
        assertEq(_lmpVault.totalIdle(), 500);
        // Debt value per share went from 2 to 1.5 so a 25% drop
        // Was 500 before
        assertEq(_lmpVault.totalDebt(), 375);
        // So overall I can get 500 + 375 back
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.convertToAssets(shareBal), 875);

        // Lets update the price back 2 ETH. This should put the numbers back
        // to where they were, idle+debt+assets. We shouldn't see any fee's
        // taken though as this is just recovering back to where our deployment was
        // We're just even now
        _mockRootPrice(address(_underlyerOne), 2 ether);

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 500);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 500);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1000);

        // Next price update. It'll go from 2 to 2.5 ether. 25%,
        // or a 125 ETH increase. There's technically a profit here but we
        // haven't set a fee yet so that should still be 0
        _mockRootPrice(address(_underlyerOne), 25e17);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 1_250_000, 500, 625);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 625);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1125);

        // Lets set a fee and and force another increase. We should only
        // take fee's on the increase from the original deployment
        // from this point forward. No back taking fee's
        _lmpVault.setPerformanceFeeBps(2000); // 20%

        // From 2.5 to 3 or a 20% increase
        // Debt was at 625, so we have 125 profit
        // 1250 nav @ 1000 shares, 25*1000/1250, 20 new shares to us
        _mockRootPrice(address(_underlyerOne), 3e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(25, feeSink, 20, 1_250_000, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        // Previously 625 but with 125 increase
        assertEq(_lmpVault.totalDebt(), 750);
        // Fees come from extra minted shares, idle shouldn't change
        assertEq(_lmpVault.totalIdle(), 500);
        // 20 Extra shares were minted to cover the fees. That's 1020 shares now
        // for 1250 assets. 1000*1250/1020
        assertEq(_lmpVault.convertToAssets(shareBal), 1225);

        // Debt report again with no changes, make sure we don't double dip fee's
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // Test the double dip again but with a decrease and
        // then increase price back to where we were

        // Decrease in price here so expect no fees
        _mockRootPrice(address(_underlyerOne), 2e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 500);
        _lmpVault.updateDebtReporting(_destinations);
        //And back to 3, should still be 0 since we've been here before
        _mockRootPrice(address(_underlyerOne), 3e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // And finally an increase above our last high value where we should
        // grab more fee's. Debt was at 750 @3 ETH. Going from 3 to 4, worth
        // 1000 now. Our nav is 1500 with 1020 shares. Previous was 1250 @ 1000 shares.
        // So that's 1.25 nav/share -> 1.467 a change of 0.217710372. With totalSupply
        // at 1020 that's a profit of 222.5 (our fee shares we minted docked
        // that from the straight up 250 we'd expect).
        // Our 20% on that profit gives us 44.5. 45*1020/1500, 30.6 shares
        _mockRootPrice(address(_underlyerOne), 4e18);
        // vm.expectEmit(true, true, true, true);
        // emit FeeCollected(45, feeSink, 31, 2_249_100, 500, 50);
        _lmpVault.updateDebtReporting(_destinations);
    }

    function test_updateDebtReporting_FlashRebalanceFeesAreTakenWithoutDoubleDipping() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        FlashRebalancer rebalancer = new FlashRebalancer();

        // User is going to deposit 1000 asset
        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 1000 baseAsset for 500 underlyerOne+destVaultOne (price is 2:1)
        _underlyerOne.mint(address(this), 250);
        _underlyerOne.approve(address(_lmpVault), 250);
        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none for baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );

        // Setting a sink but not an actual fee yet
        address feeSink = vm.addr(555);
        _lmpVault.setFeeSink(feeSink);

        // Dropped 1000 asset in and just did a rebalance. There's no slippage or anything
        // atm so assets are just moved around, should still be reporting 1000 available
        uint256 shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 500);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1000);

        // Underlyer1 is currently worth 2 ETH a piece
        // Lets update the price to 1.5 ETH and trigger a debt reporting
        // and verify our totalDebt and asset conversions match the drop in price
        _mockRootPrice(address(_underlyerOne), 15e17);
        _lmpVault.updateDebtReporting(_destinations);

        // No change in idle
        assertEq(_lmpVault.totalIdle(), 500);
        // Debt value per share went from 2 to 1.5 so a 25% drop
        // Was 500 before
        assertEq(_lmpVault.totalDebt(), 375);
        // So overall I can get 500 + 375 back
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.convertToAssets(shareBal), 875);

        // Lets update the price back 2 ETH. This should put the numbers back
        // to where they were, idle+debt+assets. We shouldn't see any fee's
        // taken though as this is just recovering back to where our deployment was
        // We're just even now
        _mockRootPrice(address(_underlyerOne), 2 ether);

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 500);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 500);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1000);

        // Next price update. It'll go from 2 to 2.5 ether. 25%,
        // or a 125 ETH increase. There's technically a profit here but we
        // haven't set a fee yet so that should still be 0
        _mockRootPrice(address(_underlyerOne), 25e17);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 1_250_000, 500, 625);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        assertEq(_lmpVault.totalDebt(), 625);
        assertEq(_lmpVault.totalIdle(), 500);
        assertEq(_lmpVault.convertToAssets(shareBal), 1125);

        // Lets set a fee and and force another increase. We should only
        // take fee's on the increase from the original deployment
        // from this point forward. No back taking fee's
        _lmpVault.setPerformanceFeeBps(2000); // 20%

        // From 2.5 to 3 or a 20% increase
        // Debt was at 625, so we have 125 profit
        // 1250 nav @ 1000 shares, 25*1000/1250, 20 new shares to us
        _mockRootPrice(address(_underlyerOne), 3e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(25, feeSink, 20, 1_250_000, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);
        shareBal = _lmpVault.balanceOf(address(this));
        // Previously 625 but with 125 increase
        assertEq(_lmpVault.totalDebt(), 750);
        // Fees come from extra minted shares, idle shouldn't change
        assertEq(_lmpVault.totalIdle(), 500);
        // 20 Extra shares were minted to cover the fees. That's 1020 shares now
        // for 1250 assets. 1000*1250/1020
        assertEq(_lmpVault.convertToAssets(shareBal), 1225);

        // Debt report again with no changes, make sure we don't double dip fee's
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // Test the double dip again but with a decrease and
        // then increase price back to where we were

        // Decrease in price here so expect no fees
        _mockRootPrice(address(_underlyerOne), 2e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 500);
        _lmpVault.updateDebtReporting(_destinations);
        //And back to 3, should still be 0 since we've been here before
        _mockRootPrice(address(_underlyerOne), 3e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 500, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // And finally an increase above our last high value where we should
        // grab more fee's. Debt was at 750 @3 ETH. Going from 3 to 4, worth
        // 1000 now. Our nav is 1500 with 1020 shares. Previous was 1250 @ 1000 shares.
        // So that's 1.25 nav/share -> 1.467 a change of 0.217710372. With totalSupply
        // at 1020 that's a profit of 222.5 (our fee shares we minted docked
        // that from the straight up 250 we'd expect).
        // Our 20% on that profit gives us 44.5. 45*1020/1500, 30.6 shares
        _mockRootPrice(address(_underlyerOne), 4e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(45, feeSink, 31, 2_249_100, 500, 1000);
        _lmpVault.updateDebtReporting(_destinations);
    }

    function test_updateDebtReporting_EarnedRewardsAreFactoredIn() public {
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));

        // Going to work with two users for this one to test partial ownership
        // Both users get 1000 asset initially
        address user1 = vm.addr(238_904);
        vm.label(user1, "user1");
        _asset.mint(user1, 1000);

        address user2 = vm.addr(89_576);
        vm.label(user2, "user2");
        _asset.mint(user2, 1000);

        // Configure our fees and where they will go
        address feeSink = vm.addr(1000);
        _lmpVault.setFeeSink(feeSink);
        vm.label(feeSink, "feeSink");
        _lmpVault.setPerformanceFeeBps(2000); // 20%

        // User 1 will deposit 500 and user 2 will deposit 250
        vm.startPrank(user1);
        _asset.approve(address(_lmpVault), 500);
        _lmpVault.deposit(500, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        _asset.approve(address(_lmpVault), 250);
        _lmpVault.deposit(250, user2);
        vm.stopPrank();

        // We only have idle funds, and haven't done a deployment
        // Taking a snapshot should result in no fee's as we haven't
        // done anything

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 750, 0);
        _lmpVault.updateDebtReporting(_destinations);

        // Check our initial state before rebalance
        // Everything should be in idle with no other token balances
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 0);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 0);
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 0);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 0);
        assertEq(_lmpVault.totalIdle(), 750);
        assertEq(_lmpVault.totalDebt(), 0);

        // Going to perform multiple rebalances. 400 asset to DV1 350 to DV2.
        // So that'll be 200 Underlyer 1 (U1) and 250 Underlyer 2 (U2) back (U1 is 2:1 price)
        address solver = vm.addr(34_343);
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);
        vm.label(solver, "solver");
        _underlyerOne.mint(solver, 200);
        _underlyerTwo.mint(solver, 350);

        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 200);
        _underlyerTwo.approve(address(_lmpVault), 350);

        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            200, // Price is 2:1 for DV1 underlyer
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            400
        );
        _lmpVault.rebalance(
            address(_destVaultTwo),
            address(_underlyerTwo), // tokenIn
            350, // Price is 1:1 for DV2 underlyer
            address(0), // destinationOut, none when sending out baseAsset
            address(_asset), // baseAsset, tokenOut
            350
        );
        vm.stopPrank();

        // So at this point, DV1 should have 200 U1, with LMP having 200 DV1
        // DV2 should have 350 U2, with LMP having 350 DV2
        // We also rebalanced all our idle so it's at 0 with everything moved to debt

        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 200);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 200);
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 350);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 350);
        assertEq(_lmpVault.totalIdle(), 0);
        assertEq(_lmpVault.totalDebt(), 750);

        // Rebalance should have performed a minimal debt snapshot and since
        // there's been no change in price or amounts we should still
        // have 0 fee's captured

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 0, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // Now we're going to rebalance from DV2 to DV1 but value of U2
        // has gone down. It was worth 1 ETH and is now only worth .6 ETH
        // We'll assume the rebalancer thinks this is OK and will let it go
        // through. Of our 750 debt, 350 would have been attributed to
        // to DV2. It's now only worth 210, so totalDebt will end up
        // being 750-350+210 = 610. That 210 is worth 105 U1 shares
        // that's what the solver will be transferring in
        _mockRootPrice(address(_underlyerTwo), 6e17);
        _underlyerOne.mint(solver, 105);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 105);
        _lmpVault.rebalance(
            address(_destVaultOne),
            address(_underlyerOne), // tokenIn
            105,
            address(_destVaultTwo), // destinationOut, none when sending out baseAsset
            address(_underlyerTwo), // baseAsset, tokenOut
            350
        );
        vm.stopPrank();

        // Added 105 shares to DV1+U1 setup
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 305);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 305);
        // We burned everything related DV2
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 0);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 0);
        // Still nothing in idle and we lost 140
        assertEq(_lmpVault.totalIdle(), 0);
        assertEq(_lmpVault.totalDebt(), 750 - 140);

        // Another debt reporting, but we've done nothing but lose money
        // so again no fees

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 0, 750 - 140);
        _lmpVault.updateDebtReporting(_destinations);

        // Now the value of U1 is going up. From 2 ETH to 2.2 ETH
        // That makes those 305 shares now worth 671
        // Do another debt reporting but we're still below our debt basis
        // of 750 so still no fee's
        _mockRootPrice(address(_underlyerOne), 22e17);

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 0, 671);
        _lmpVault.updateDebtReporting(_destinations);
        assertEq(_lmpVault.totalDebt(), 671);

        // New user comes along and deposits 1000 more.
        address user3 = vm.addr(239_994);
        vm.label(user3, "user1");
        _asset.mint(user3, 1000);
        vm.startPrank(user3);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, user3);
        vm.stopPrank();

        // LMP has 750 shares, total assets of 671 with 1000 more coming in
        // 1000 * 750 / 671, user gets 1117 shares
        assertEq(_lmpVault.balanceOf(user3), 1117);

        // No change in debt with that operation but now we have some idle
        assertEq(_lmpVault.totalIdle(), 1000);
        assertEq(_lmpVault.totalDebt(), 671);

        // Another debt reporting, but since we don't take fee's on idle
        // it should be 0

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 1000, 671);
        _lmpVault.updateDebtReporting(_destinations);

        // U1 price goes up to 4 ETH, our 305 shares
        // are now worth 1220. With 1000 in idle, total assets are 2220.
        // We have 1117+750 = 1867 shares. 1.18 nav/share up from 1
        // .18 * 1867 is about a profit of 352. With our 20% fee
        // we should get 71. Converted to shares that gets us
        // 71_fee * 1867_lmpSupply / 2220_totalAssets = 60 shares
        _mockRootPrice(address(_underlyerOne), 4e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(71, feeSink, 60, 3_528_630, 1000, 1220);
        _lmpVault.updateDebtReporting(_destinations);

        // Now lets introduce reward value. Deposit rewards, something normally
        // only the liquidator will do, into the DV1's rewarder
        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));
        _asset.mint(address(this), 10_000);
        _asset.approve(address(_destVaultOne.rewarder()), 10_000);
        IMainRewarder(_destVaultOne.rewarder()).queueNewRewards(10_000);

        // Roll blocks forward and verify the LMP has earned something
        vm.roll(block.number + 100);
        uint256 earned = IMainRewarder(_destVaultOne.rewarder()).earned(address(_lmpVault));
        assertEq(earned, 999);

        // So at the next debt reporting our nav should go up by 999
        // Previously we were at 1867 shares with 2220 assets
        // Or an NAV/share of 1.18907338. Now we're at
        // 2220+999 or 3219 assets and factoring in our last set of fee shares
        // total supply is at 1927 - nav/share - 1.670472237
        // That's a NAV increase of roughly 0.481398857. So
        // there was 927.65559674 in profit. At our 20% fee ~186
        // To capture 186 asset we need 186*1927/3219 or ~112 shares
        uint256 feeSinkBeforeBal = _lmpVault.balanceOf(feeSink);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(186, feeSink, 112, 9_276_578, 1999, 1220);
        _lmpVault.updateDebtReporting(_destinations);
        uint256 feeSinkAfterBal = _lmpVault.balanceOf(feeSink);
        assertEq(feeSinkAfterBal - feeSinkBeforeBal, 112);

        // Users come to withdraw everything. User share breakdown looks this:
        // User 1 - 500
        // User 2 - 250
        // User 3 - 1117
        // Fees - 112 + 60 - 172
        // Total Supply - 2039
        // We have a totalAssets() of 3219
        // We assume no slippage
        // User 1 - 500/2039*3219 - 789.3575282
        // User 2 - 250/(2039-500)*(3219-789) - 394.736842105
        // User 3 - 1117/(2039-500-250)*(3219-789-394) - 1764.322730799
        // Fees - 172/(2039-500-250-1117)*(3219-789-394-1764) - 272

        vm.prank(user1);
        uint256 user1Assets = _lmpVault.redeem(500, vm.addr(4847), user1);
        vm.prank(user2);
        uint256 user2Assets = _lmpVault.redeem(250, vm.addr(5847), user2);
        vm.prank(user3);
        uint256 user3Assets = _lmpVault.redeem(1117, vm.addr(6847), user3);

        // Just our fee shares left
        assertEq(_lmpVault.totalSupply(), 172);

        vm.prank(feeSink);
        uint256 feeSinkAssets = _lmpVault.redeem(172, vm.addr(7847), feeSink);

        // Nothing left in the vault
        assertEq(_lmpVault.totalSupply(), 0);
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);

        // Make sure users got what they expected
        assertEq(_asset.balanceOf(vm.addr(4847)), 789);
        assertEq(user1Assets, 789);

        assertEq(_asset.balanceOf(vm.addr(5847)), 394);
        assertEq(user2Assets, 394);

        assertEq(_asset.balanceOf(vm.addr(6847)), 1764);
        assertEq(user3Assets, 1764);

        assertEq(_asset.balanceOf(vm.addr(7847)), 272);
        assertEq(feeSinkAssets, 272);
    }

    function test_updateDebtReporting_FlashRebalanceEarnedRewardsAreFactoredIn() public {
        _accessController.grantRole(Roles.LMP_FEE_SETTER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        // Going to work with two users for this one to test partial ownership
        // Both users get 1000 asset initially
        address user1 = vm.addr(238_904);
        vm.label(user1, "user1");
        _asset.mint(user1, 1000);

        address user2 = vm.addr(89_576);
        vm.label(user2, "user2");
        _asset.mint(user2, 1000);

        // Configure our fees and where they will go
        address feeSink = vm.addr(1000);
        _lmpVault.setFeeSink(feeSink);
        vm.label(feeSink, "feeSink");
        _lmpVault.setPerformanceFeeBps(2000); // 20%

        // User 1 will deposit 500 and user 2 will deposit 250
        vm.startPrank(user1);
        _asset.approve(address(_lmpVault), 500);
        _lmpVault.deposit(500, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        _asset.approve(address(_lmpVault), 250);
        _lmpVault.deposit(250, user2);
        vm.stopPrank();

        // We only have idle funds, and haven't done a deployment
        // Taking a snapshot should result in no fee's as we haven't
        // done anything

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 750, 0);
        _lmpVault.updateDebtReporting(_destinations);

        // Check our initial state before rebalance
        // Everything should be in idle with no other token balances
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 0);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 0);
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 0);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 0);
        assertEq(_lmpVault.totalIdle(), 750);
        assertEq(_lmpVault.totalDebt(), 0);

        // Going to perform multiple rebalances. 400 asset to DV1 350 to DV2.
        // So that'll be 200 Underlyer 1 (U1) and 250 Underlyer 2 (U2) back (U1 is 2:1 price)
        address solver = vm.addr(34_343);
        _accessController.grantRole(Roles.SOLVER_ROLE, solver);
        vm.label(solver, "solver");
        _underlyerOne.mint(solver, 200);
        _underlyerTwo.mint(solver, 350);

        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 200);
        _underlyerTwo.approve(address(_lmpVault), 350);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 400);

        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 200, // Price is 2:1 for DV1 underlyer
                destinationOut: address(0), // destinationOut, none for baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 400
            }),
            abi.encode("")
        );

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 350);

        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultTwo),
                tokenIn: address(_underlyerTwo), // tokenIn
                amountIn: 350, // Price is 1:1 for DV2 underlyer
                destinationOut: address(0), // destinationOut, none for baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 350
            }),
            abi.encode("")
        );
        vm.stopPrank();

        // So at this point, DV1 should have 200 U1, with LMP having 200 DV1
        // DV2 should have 350 U2, with LMP having 350 DV2
        // We also rebalanced all our idle so it's at 0 with everything moved to debt

        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 200);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 200);
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 350);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 350);
        assertEq(_lmpVault.totalIdle(), 0);
        assertEq(_lmpVault.totalDebt(), 750);

        // Rebalance should have performed a minimal debt snapshot and since
        // there's been no change in price or amounts we should still
        // have 0 fee's captured

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 0, 750);
        _lmpVault.updateDebtReporting(_destinations);

        // Now we're going to rebalance from DV2 to DV1 but value of U2
        // has gone down. It was worth 1 ETH and is now only worth .6 ETH
        // We'll assume the rebalancer thinks this is OK and will let it go
        // through. Of our 750 debt, 350 would have been attributed to
        // to DV2. It's now only worth 210, so totalDebt will end up
        // being 750-350+210 = 610. That 210 is worth 105 U1 shares
        // that's what the solver will be transferring in
        _mockRootPrice(address(_underlyerTwo), 6e17);
        _underlyerOne.mint(solver, 105);
        vm.startPrank(solver);
        _underlyerOne.approve(address(_lmpVault), 105);
        _lmpVault.rebalance(
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 105,
                destinationOut: address(_destVaultTwo), // destinationOut, none when sending out baseAsset
                tokenOut: address(_underlyerTwo), // baseAsset, tokenOut
                amountOut: 350
            })
        );
        vm.stopPrank();

        // Added 105 shares to DV1+U1 setup
        assertEq(_underlyerOne.balanceOf(address(_destVaultOne)), 305);
        assertEq(_destVaultOne.balanceOf(address(_lmpVault)), 305);
        // We burned everything related DV2
        assertEq(_underlyerTwo.balanceOf(address(_destVaultTwo)), 0);
        assertEq(_destVaultTwo.balanceOf(address(_lmpVault)), 0);
        // Still nothing in idle and we lost 140
        assertEq(_lmpVault.totalIdle(), 0);
        assertEq(_lmpVault.totalDebt(), 750 - 140);

        // Another debt reporting, but we've done nothing but lose money
        // so again no fees

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 0, 750 - 140);
        _lmpVault.updateDebtReporting(_destinations);

        // Now the value of U1 is going up. From 2 ETH to 2.2 ETH
        // That makes those 305 shares now worth 671
        // Do another debt reporting but we're still below our debt basis
        // of 750 so still no fee's
        _mockRootPrice(address(_underlyerOne), 22e17);

        // vm.expectEmit(true, true, true, true);
        // emit FeeCollected(0, feeSink, 0, 0, 5, 5);
        _lmpVault.updateDebtReporting(_destinations);
        assertEq(_lmpVault.totalDebt(), 671);

        // New user comes along and deposits 1000 more.
        address user3 = vm.addr(239_994);
        vm.label(user3, "user1");
        _asset.mint(user3, 1000);
        vm.startPrank(user3);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, user3);
        vm.stopPrank();

        // LMP has 750 shares, total assets of 671 with 1000 more coming in
        // 1000 * 750 / 671, user gets 1117 shares
        assertEq(_lmpVault.balanceOf(user3), 1117);

        // No change in debt with that operation but now we have some idle
        assertEq(_lmpVault.totalIdle(), 1000);
        assertEq(_lmpVault.totalDebt(), 671);

        // Another debt reporting, but since we don't take fee's on idle
        // it should be 0

        vm.expectEmit(true, true, true, true);
        emit FeeCollected(0, feeSink, 0, 0, 1000, 671);
        _lmpVault.updateDebtReporting(_destinations);

        // U1 price goes up to 4 ETH, our 305 shares
        // are now worth 1220. With 1000 in idle, total assets are 2220.
        // We have 1117+750 = 1867 shares. 1.18 nav/share up from 1
        // .18 * 1867 is about a profit of 352. With our 20% fee
        // we should get 71. Converted to shares that gets us
        // 71_fee * 1867_lmpSupply / 2220_totalAssets = 60 shares
        _mockRootPrice(address(_underlyerOne), 4e18);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(71, feeSink, 60, 3_528_630, 1000, 1220);
        _lmpVault.updateDebtReporting(_destinations);

        // Now lets introduce reward value. Deposit rewards, something normally
        // only the liquidator will do, into the DV1's rewarder
        _accessController.grantRole(Roles.LIQUIDATOR_ROLE, address(this));
        _asset.mint(address(this), 10_000);
        _asset.approve(_destVaultOne.rewarder(), 10_000);
        IMainRewarder(_destVaultOne.rewarder()).queueNewRewards(10_000);

        // Roll blocks forward and verify the LMP has earned something
        vm.roll(block.number + 100);
        uint256 earned = IMainRewarder(_destVaultOne.rewarder()).earned(address(_lmpVault));
        assertEq(earned, 999);

        // So at the next debt reporting our nav should go up by 999
        // Previously we were at 1867 shares with 2220 assets
        // Or an NAV/share of 1.18907338. Now we're at
        // 2220+999 or 3219 assets and factoring in our last set of fee shares
        // total supply is at 1927 - nav/share - 1.670472237
        // That's a NAV increase of roughly 0.481398857. So
        // there was 927.65559674 in profit. At our 20% fee ~186
        // To capture 186 asset we need 186*1927/3219 or ~112 shares
        uint256 feeSinkBeforeBal = _lmpVault.balanceOf(feeSink);
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(186, feeSink, 112, 9_276_578, 1999, 1220);
        _lmpVault.updateDebtReporting(_destinations);
        uint256 feeSinkAfterBal = _lmpVault.balanceOf(feeSink);
        assertEq(feeSinkAfterBal - feeSinkBeforeBal, 112);

        // Users come to withdraw everything. User share breakdown looks this:
        // User 1 - 500
        // User 2 - 250
        // User 3 - 1117
        // Fees - 112 + 60 - 172
        // Total Supply - 2039
        // We have a totalAssets() of 3219
        // We assume no slippage
        // User 1 - 500/2039*3219 - 789.3575282
        // User 2 - 250/(2039-500)*(3219-789) - 394.736842105
        // User 3 - 1117/(2039-500-250)*(3219-789-394) - 1764.322730799
        // Fees - 172/(2039-500-250-1117)*(3219-789-394-1764) - 272

        vm.prank(user1);
        uint256 user1Assets = _lmpVault.redeem(500, vm.addr(4847), user1);
        vm.prank(user2);
        uint256 user2Assets = _lmpVault.redeem(250, vm.addr(5847), user2);
        vm.prank(user3);
        uint256 user3Assets = _lmpVault.redeem(1117, vm.addr(6847), user3);

        // Just our fee shares left
        assertEq(_lmpVault.totalSupply(), 172);

        vm.prank(feeSink);
        uint256 feeSinkAssets = _lmpVault.redeem(172, vm.addr(7847), feeSink);

        // Nothing left in the vault
        assertEq(_lmpVault.totalSupply(), 0);
        assertEq(_lmpVault.totalDebt(), 0);
        assertEq(_lmpVault.totalIdle(), 0);

        // Make sure users got what they expected
        assertEq(_asset.balanceOf(vm.addr(4847)), 789);
        assertEq(user1Assets, 789);

        assertEq(_asset.balanceOf(vm.addr(5847)), 394);
        assertEq(user2Assets, 394);

        assertEq(_asset.balanceOf(vm.addr(6847)), 1764);
        assertEq(user3Assets, 1764);

        assertEq(_asset.balanceOf(vm.addr(7847)), 272);
        assertEq(feeSinkAssets, 272);
    }

    function test_recover_OnlyCallableByRole() public {
        TestERC20 newToken = new TestERC20("c", "c");
        newToken.mint(address(_lmpVault), 5e18);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory destinations = new address[](1);

        tokens[0] = address(newToken);
        amounts[0] = 5e18;
        destinations[0] = address(this);

        vm.expectRevert(abi.encodeWithSelector(Errors.AccessDenied.selector));
        _lmpVault.recover(tokens, amounts, destinations);

        _accessController.grantRole(Roles.TOKEN_RECOVERY_ROLE, address(this));
        _lmpVault.recover(tokens, amounts, destinations);
    }

    function test_recover_RecoversSpecifiedAmountToCorrectDestination() public {
        TestERC20 newToken = new TestERC20("c", "c");
        newToken.mint(address(_lmpVault), 5e18);
        _accessController.grantRole(Roles.TOKEN_RECOVERY_ROLE, address(this));

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory destinations = new address[](1);

        tokens[0] = address(newToken);
        amounts[0] = 5e18;
        destinations[0] = address(this);

        assertEq(newToken.balanceOf(address(_lmpVault)), 5e18);
        assertEq(newToken.balanceOf(address(this)), 0);

        _lmpVault.recover(tokens, amounts, destinations);

        assertEq(newToken.balanceOf(address(_lmpVault)), 0);
        assertEq(newToken.balanceOf(address(this)), 5e18);
    }

    function test_recover_RevertIf_BaseAssetIsAttempted() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        _accessController.grantRole(Roles.TOKEN_RECOVERY_ROLE, address(this));

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory destinations = new address[](1);

        tokens[0] = address(_asset);
        amounts[0] = 500;
        destinations[0] = address(this);

        vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotAllowed.selector, address(_asset)));
        _lmpVault.recover(tokens, amounts, destinations);
    }

    function test_recover_RevertIf_DestinationVaultIsAttempted() public {
        _accessController.grantRole(Roles.SOLVER_ROLE, address(this));
        FlashRebalancer rebalancer = new FlashRebalancer();

        _asset.mint(address(this), 1000);
        _asset.approve(address(_lmpVault), 1000);
        _lmpVault.deposit(1000, address(this));

        // At time of writing LMPVault always returned true for verifyRebalance
        // Rebalance 500 baseAsset for 250 underlyerOne+destVaultOne

        _underlyerOne.mint(address(this), 500);
        _underlyerOne.approve(address(_lmpVault), 500);

        // Tell the test harness how much it should have at mid execution
        rebalancer.snapshotAsset(address(_asset), 500);

        _lmpVault.flashRebalance(
            rebalancer,
            IStrategy.RebalanceParams({
                destinationIn: address(_destVaultOne),
                tokenIn: address(_underlyerOne), // tokenIn
                amountIn: 250,
                destinationOut: address(0), // destinationOut, none when sending out baseAsset
                tokenOut: address(_asset), // baseAsset, tokenOut
                amountOut: 500
            }),
            abi.encode("")
        );

        _accessController.grantRole(Roles.TOKEN_RECOVERY_ROLE, address(this));

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory destinations = new address[](1);

        tokens[0] = address(_destVaultOne);
        amounts[0] = 5;
        destinations[0] = address(this);

        assertTrue(_destVaultOne.balanceOf(address(_lmpVault)) > 5);
        assertTrue(_lmpVault.isDestinationRegistered(address(_destVaultOne)));

        vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotAllowed.selector, address(_destVaultOne)));
        _lmpVault.recover(tokens, amounts, destinations);
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
}

contract LMPVaultMinting is LMPVault {
    constructor(ISystemRegistry _systemRegistry, address _vaultAsset) LMPVault(_systemRegistry, _vaultAsset) { }

    bool private _rebalanceVerifies;
    string private _rebalanceVerifyError;

    function setVerifyRebalance(bool vr) public {
        _rebalanceVerifies = vr;
    }

    function setVerifyRebalance(bool vr, string memory err) public {
        setVerifyRebalance(vr);
        _rebalanceVerifyError = err;
    }

    function rebalance(
        address destinationIn,
        address tokenIn,
        uint256 amountIn,
        address destinationOut,
        address tokenOut,
        uint256 amountOut
    ) external {
        rebalance(
            IStrategy.RebalanceParams({
                destinationIn: destinationIn,
                tokenIn: tokenIn,
                amountIn: amountIn,
                destinationOut: destinationOut,
                tokenOut: tokenOut,
                amountOut: amountOut
            })
        );
    }

    function verifyRebalance(
        address,
        address,
        uint256,
        address,
        address,
        uint256
    ) public view virtual override returns (bool success, string memory message) {
        success = _rebalanceVerifies;
        message = _rebalanceVerifyError;
    }
}

/// @notice Tester that will tweak NAV on operations where it shouldn't be possible
contract LMPVaultNavChange is LMPVaultMinting {
    bool private _tweak;

    constructor(ISystemRegistry _systemRegistry, address _vaultAsset) LMPVaultMinting(_systemRegistry, _vaultAsset) { }

    function doTweak(bool tweak) external {
        _tweak = tweak;
    }

    function _transferAndMint(uint256 assets, uint256 shares, address receiver) internal virtual override {
        super._transferAndMint(assets, shares, receiver);
        if (_tweak) {
            totalIdle -= totalIdle / 2;
        }
    }

    function _withdraw(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner
    ) internal virtual override returns (uint256 ret) {
        ret = super._withdraw(assets, shares, receiver, owner);
        if (_tweak) {
            totalIdle -= totalIdle / 2;
        }
    }
}

contract LMPVaultWithdrawSharesTests is Test {
    uint256 private _aix = 0;

    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    SystemSecurity private _systemSecurity;

    TestERC20 private _asset;
    TestWithdrawSharesLMPVault private _lmpVault;

    function setUp() public {
        _systemRegistry = new SystemRegistry(vm.addr(100), vm.addr(101));

        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));

        _systemSecurity = new SystemSecurity(_systemRegistry);
        _systemRegistry.setSystemSecurity(address(_systemSecurity));

        _asset = new TestERC20("asset", "asset");
        _lmpVault = new TestWithdrawSharesLMPVault(_systemRegistry, address(_asset));
    }

    function testConstruction() public {
        assertEq(_lmpVault.asset(), address(_asset));
    }

    struct TestInfo {
        uint256 currentDVSharesOwned;
        uint256 currentDebtValue;
        uint256 lastDebtBasis;
        uint256 lastDVSharesOwned;
        uint256 assetsToPull;
        uint256 userShares;
        uint256 totalAssetsPulled;
        uint256 totalSupply;
        uint256 expectedSharesToBurn;
        uint256 totalDebtBurn;
    }

    function testInProfitDebtValueGreaterOneToOnePricing() public {
        // Profit: Yes
        // Can Cover Requested: Yes
        // Owned Shares Match Cache: Yes

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 1000 shares at 1000 value, so shares are 1:1 atm
        // Last debt basis was at 999, 1000 > 999, so we're in profit and
        // can burn what the vault owns, not just the users share

        // Trying to pull 50 asset, with dv shares being 1:1, means
        // we should expect to burn 50 dv shares and pull the entire 50

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 1000,
                currentDebtValue: 1000,
                lastDebtBasis: 999,
                lastDVSharesOwned: 1000,
                assetsToPull: 50,
                totalAssetsPulled: 0,
                userShares: 25,
                totalSupply: 1000,
                expectedSharesToBurn: 50,
                totalDebtBurn: 50
            })
        );
    }

    function testInProfitDebtValueGreaterComplexPricing() public {
        // Profit: Yes
        // Can Cover Requested: Yes
        // Owned Shares Match Cache: Yes

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 1000 shares at 2000 value.
        // Last debt basis was at 1900, 2000 > 1900, so we're in profit and
        // can burn what the vault owns, not just the users share

        // Trying to pull 50 asset, with dv shares being 2:1, means
        // we should expect to burn 25 dv shares and pull the entire 50

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 1000,
                currentDebtValue: 2000,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 50,
                totalAssetsPulled: 0,
                userShares: 25,
                totalSupply: 1000,
                expectedSharesToBurn: 25,
                totalDebtBurn: 50
            })
        );
    }

    function testInProfitDebtValueGreaterComplexPricingLowerCurrentShares() public {
        // Profit: Yes
        // Can Cover Requested: Yes
        // Owned Shares Match Cache: No

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 900 shares at 1800 value.
        // Last debt basis was at 1900, but that was when we owned 1000 shares
        // Since we only own 900 now, we need to drop our debt basis calculation 10%
        // which puts the real debt basis at 1710.
        // But, price went up so current value is at 1800 and we're in profit

        // Of the 1800 cached debt, burning 25 shares of 1000 total
        // We need to remove 1800 * 25 / 1000 or 45 from total debt

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 900,
                currentDebtValue: 1800,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 50,
                totalAssetsPulled: 0,
                userShares: 25,
                totalSupply: 1000,
                expectedSharesToBurn: 25,
                totalDebtBurn: 45
            })
        );
    }

    function testInProfitComplexPricingLowerCurrentSharesNoCover() public {
        // Profit: Yes
        // Can Cover Requested: No
        // Owned Shares Match Cache: No

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 900 shares at 1850 value.
        // Last debt basis was at 1900, but that was when we owned 1000 shares
        // Since we only own 900 now, we need to drop our debt basis calculation 10%
        // which puts the real debt basis at 1710.
        // But, price went up so current value is at 1850 and we're in profit

        // Trying to pull 2000 asset, but our whole pot is only worth 1850.
        // We can use all shares so that's what we'll get for 900 shares.
        // Of the 1850 cached debt, we're burning 900 shares of the total cached 1000
        // Remove 1850*900/1000 or 1665 from total debt

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 900,
                currentDebtValue: 1850,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 2000,
                totalAssetsPulled: 0,
                userShares: 1000,
                totalSupply: 1000,
                expectedSharesToBurn: 900,
                totalDebtBurn: 1665
            })
        );
    }

    function testInProfitComplexPricingSameCurrentSharesNoCover() public {
        // Profit: Yes
        // Can Cover Requested: No
        // Owned Shares Match Cache: Yes

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 1000 shares at 1900 value. No withdrawals or price change
        // since snapshot

        // Trying to pull 2000 asset, but our whole pot is only worth 1850.
        // We can use all shares so that's what we'll get for 1000 shares.

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 1000,
                currentDebtValue: 1900,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 2000,
                totalAssetsPulled: 0,
                userShares: 1000,
                totalSupply: 1000,
                expectedSharesToBurn: 1000,
                totalDebtBurn: 1900
            })
        );
    }

    function testAtLossComplexPricingEqualCurrentShares() public {
        // Profit: No
        // Can Cover Requested: Yes
        // Owned Shares Match Cache: Yes

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 1000 shares at 1700 value.

        // User owns 50% of the LMP vault, so we can only burn 50% of the
        // the DV shares we own. 500 shares can still cover what we want to pull
        // so we expect 50 back.

        // That 1000 shares worth 1700 asset, so each share is worth 1.7 asset
        // We're trying to get 50 asset, 50 / 1.7 shares, so we'll burn
        // 30. We have 1700, burning 30/1000 shares, so we'll
        // remove 51 debt

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 1000,
                currentDebtValue: 1700,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 50,
                totalAssetsPulled: 0,
                userShares: 500,
                totalSupply: 1000,
                expectedSharesToBurn: 30,
                totalDebtBurn: 51
            })
        );
    }

    function testAtLossComplexPricingLowerCurrentShares() public {
        // Profit: No
        // Can Cover Requested: Yes
        // Owned Shares Match Cache: No

        // We own 900 shares at 1700 value.
        // Last debt basis was at 1900, but that was when the vault owned 1000 shares
        // Since we only own 900 now, we need to drop our debt basis calculation 10%
        // which puts the real debt basis at 1710.
        // Current value is lower, so we're in a loss scenario

        // User owns 50% of the LMP vault, so we can only burn 50% of the
        // the DV shares we own. 450 shares are worth 1700/900*450 or 850
        // We are trying to pull 50 or 5.88% of the value of our shares
        // 5.88% of the the shares we own is 27

        // That debt was worth 1700, and we're burning 27 out of the 1000 shares
        // that were there when we took the snapshot
        // 1700 * 27 / 1000 = 46

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 900,
                currentDebtValue: 1700,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 50,
                totalAssetsPulled: 0,
                userShares: 500,
                totalSupply: 1000,
                expectedSharesToBurn: 27,
                totalDebtBurn: 46
            })
        );
    }

    function testAtLossUserPortionWontCover() public {
        // Profit: No
        // Can Cover Requested: No
        // Owned Shares Match Cache: No

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // We own 900 shares at 400 value.
        // Last debt basis was at 1900, but that was when we owned 1000 shares
        // Since we only own 900 now, we need to drop our debt basis calculation 10%
        // which puts the real debt basis at 1710.
        // Current value, 500, is lower, so we're in a loss scenario

        // With a cached debt value of 400, us burning 90 shares of the total
        // cached amount of 1000. We need to remove 400*90/1000 or 36 from total debt

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 900,
                currentDebtValue: 400,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 200,
                totalAssetsPulled: 0,
                userShares: 100,
                totalSupply: 1000,
                expectedSharesToBurn: 90,
                totalDebtBurn: 36
            })
        );
    }

    function testAtLossUserPortionWontCoverSharesMove() public {
        // Profit: No
        // Can Cover Requested: No
        // Owned Shares Match Cache: Yes

        // When the deployment is sitting at overall profit
        // We can burn all shares to obtain the value we seek

        // User owns 10% of the LMP vault, so we can only burn 10% of the
        // the DV shares we own.
        // At 1000 shares worth 400, that puts each share at 2 asset
        // We can only burn 100 shares, 10% of the 400, so max we can expect is 40
        // User is trying to get 200 but we should top out at 40

        _assertResults(
            _lmpVault,
            TestInfo({
                currentDVSharesOwned: 1000,
                currentDebtValue: 400,
                lastDebtBasis: 1900,
                lastDVSharesOwned: 1000,
                assetsToPull: 200,
                totalAssetsPulled: 0,
                userShares: 100,
                totalSupply: 1000,
                expectedSharesToBurn: 100,
                totalDebtBurn: 40
            })
        );
    }

    function testRevertOnBadSnapshot() public {
        TestInfo memory testInfo = TestInfo({
            currentDVSharesOwned: 1000,
            currentDebtValue: 400,
            lastDebtBasis: 1900,
            lastDVSharesOwned: 900, // Less than currentDvSharesOwned
            assetsToPull: 200,
            totalAssetsPulled: 0,
            userShares: 100,
            totalSupply: 1000,
            expectedSharesToBurn: 100,
            totalDebtBurn: 40
        });

        address dv = _mockDestVaultForWithdrawShareCalc(
            _lmpVault,
            testInfo.currentDVSharesOwned,
            testInfo.currentDebtValue,
            testInfo.lastDebtBasis,
            testInfo.lastDVSharesOwned
        );

        vm.expectRevert(abi.encodeWithSelector(LMPVault.WithdrawShareCalcInvalid.selector, 1000, 900));
        _lmpVault.calcUserWithdrawSharesToBurn(
            IDestinationVault(dv),
            testInfo.userShares,
            testInfo.assetsToPull,
            testInfo.totalAssetsPulled,
            testInfo.totalSupply
        );
    }

    function _assertResults(TestWithdrawSharesLMPVault testVault, TestInfo memory testInfo) internal {
        address dv = _mockDestVaultForWithdrawShareCalc(
            testVault,
            testInfo.currentDVSharesOwned,
            testInfo.currentDebtValue,
            testInfo.lastDebtBasis,
            testInfo.lastDVSharesOwned
        );

        (uint256 sharesToBurn, uint256 expectedTotalBurn) = _lmpVault.calcUserWithdrawSharesToBurn(
            IDestinationVault(dv),
            testInfo.userShares,
            testInfo.assetsToPull,
            testInfo.totalAssetsPulled,
            testInfo.totalSupply
        );

        assertEq(sharesToBurn, testInfo.expectedSharesToBurn, "sharesToBurn");
        assertEq(expectedTotalBurn, testInfo.totalDebtBurn, "expectedTotalBurn");
    }

    function _mockDestVaultForWithdrawShareCalc(
        TestWithdrawSharesLMPVault testVault,
        uint256 lmpVaultBalance,
        uint256 currentSharesValue,
        uint256 lastDebtBasis,
        uint256 lastOwnedShares
    ) internal returns (address ret) {
        _aix++;
        ret = vm.addr(10_000 + _aix);

        vm.mockCall(
            ret, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testVault)), abi.encode(lmpVaultBalance)
        );

        vm.mockCall(
            ret,
            abi.encodeWithSelector(bytes4(keccak256("debtValue(uint256)")), lmpVaultBalance),
            abi.encode(currentSharesValue)
        );

        testVault.setDestInfoDebtBasis(ret, lastDebtBasis);
        testVault.setDestInfoOwnedShares(ret, lastOwnedShares);
        testVault.setDestInfoCurrentDebt(ret, currentSharesValue);
    }
}

/// @notice Flash Rebalance tester that verifies it receives the amount it should from the LMP Vault
contract FlashRebalancer is IERC3156FlashBorrower {
    address private _asset;
    uint256 private _startingAmount;
    uint256 private _expectedAmount;
    bool private ready;

    function snapshotAsset(address asset, uint256 expectedAmount) external {
        _asset = asset;
        _startingAmount = TestERC20(_asset).balanceOf(address(this));
        _expectedAmount = expectedAmount;
        ready = true;
    }

    function onFlashLoan(address, address token, uint256 amount, uint256, bytes memory) external returns (bytes32) {
        TestERC20(token).mint(msg.sender, amount);
        require(TestERC20(_asset).balanceOf(address(this)) - _startingAmount == _expectedAmount, "wrong asset amount");
        require(ready, "not ready");
        ready = false;
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

/// @notice Flash Rebalance tester that tries to call back into the vault to do a deposit. Testing nav change reentrancy
contract FlashRebalancerReentrant is IERC3156FlashBorrower {
    LMPVault private _lmpVaultForDeposit;
    bool private _doDeposit;
    bool private _doMint;
    bool private _doWithdraw;
    bool private _doRedeem;

    constructor(LMPVault vault, bool doDeposit, bool doMint, bool doWithdraw, bool doRedeem) {
        _lmpVaultForDeposit = vault;
        _doDeposit = doDeposit;
        _doMint = doMint;
        _doWithdraw = doWithdraw;
        _doRedeem = doRedeem;
    }

    function onFlashLoan(address, address token, uint256 amount, uint256, bytes memory) external returns (bytes32) {
        TestERC20(_lmpVaultForDeposit.asset()).mint(address(this), 100_000);
        TestERC20(_lmpVaultForDeposit.asset()).approve(msg.sender, 100_000);

        if (_doDeposit) {
            _lmpVaultForDeposit.deposit(20, address(this));
        }
        if (_doMint) {
            _lmpVaultForDeposit.mint(20, address(this));
        }
        if (_doWithdraw) {
            _lmpVaultForDeposit.withdraw(1, address(this), address(this));
        }
        if (_doRedeem) {
            _lmpVaultForDeposit.redeem(1, address(this), address(this));
        }

        TestERC20(token).mint(msg.sender, amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract TestWithdrawSharesLMPVault is LMPVault {
    constructor(ISystemRegistry _systemRegistry, address _vaultAsset) LMPVault(_systemRegistry, _vaultAsset) { }

    function setDestInfoDebtBasis(address destVault, uint256 debtBasis) public {
        destinationInfo[destVault].debtBasis = debtBasis;
    }

    function setDestInfoOwnedShares(address destVault, uint256 ownedShares) public {
        destinationInfo[destVault].ownedShares = ownedShares;
    }

    function setDestInfoCurrentDebt(address destVault, uint256 debt) public {
        destinationInfo[destVault].currentDebt = debt;
    }

    function calcUserWithdrawSharesToBurn(
        IDestinationVault destVault,
        uint256 userShares,
        uint256 totalAssetsToPull,
        uint256 totalAssetsPulled,
        uint256 totalVaultShares
    ) external returns (uint256 sharesToBurn, uint256 expectedAsset) {
        uint256 assetPull = totalAssetsToPull;
        (sharesToBurn, expectedAsset) =
            _calcUserWithdrawSharesToBurn(destVault, userShares, assetPull - totalAssetsPulled, totalVaultShares);
    }
}

contract TestDestinationVault is DestinationVault {
    constructor(ISystemRegistry systemRegistry) DestinationVault(systemRegistry) { }

    function exchangeName() external pure override returns (string memory) {
        return "test";
    }

    function underlyingTokens() external pure override returns (address[] memory) {
        return new address[](0);
    }

    function _burnUnderlyer(uint256 underlyerAmount)
        internal
        virtual
        override
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        TestERC20(_underlying).burn(address(this), underlyerAmount);

        // Just convert the tokens back based on price
        IRootPriceOracle oracle = _systemRegistry.rootPriceOracle();
        uint256 underlyingPrice = oracle.getPriceInEth(_underlying);
        uint256 assetPrice = oracle.getPriceInEth(_baseAsset);
        uint256 amount = (underlyerAmount * underlyingPrice) / assetPrice;

        TestERC20(_baseAsset).mint(address(this), amount);

        tokens = new address[](1);
        tokens[0] = _baseAsset;

        amounts = new uint256[](1);
        amounts[0] = amount;
    }

    function _ensureLocalUnderlyingBalance(uint256) internal virtual override { }

    function _onDeposit(uint256 amount) internal virtual override { }

    function balanceOfUnderlying() public view override returns (uint256) {
        return TestERC20(_underlying).balanceOf(address(this));
    }

    function externalBalance() public pure override returns (uint256) {
        return 0;
    }

    function _collectRewards() internal virtual override returns (uint256[] memory amounts, address[] memory tokens) { }
}
