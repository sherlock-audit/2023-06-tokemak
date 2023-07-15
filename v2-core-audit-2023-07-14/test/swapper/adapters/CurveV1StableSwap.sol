// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { CurveV1StableSwap } from "src/swapper/adapters/CurveV1StableSwap.sol";
import { ICurveV1StableSwap } from "src/interfaces/external/curve/ICurveV1StableSwap.sol";

import { STETH_MAINNET, WETH_MAINNET, RANDOM } from "test/utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract CurveV1StableSwapTest is Test {
    CurveV1StableSwap private adapter;

    ISwapRouter.SwapData private route;

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_728_070);
        vm.selectFork(forkId);

        adapter = new CurveV1StableSwap(address(this), WETH_MAINNET);

        // route WETH_MAINNET -> STETH_MAINNET
        route = ISwapRouter.SwapData({
            token: STETH_MAINNET,
            pool: 0x828b154032950C8ff7CF8085D841723Db2696056,
            swapper: adapter,
            data: abi.encode(0, 1, false)
        });
    }

    function test_validate_Revert_IfFromAddressMismatch() public {
        // pretend that the pool doesn't have WETH_MAINNET
        vm.mockCall(route.pool, abi.encodeWithSelector(ICurveV1StableSwap.coins.selector, 0), abi.encode(RANDOM));
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "fromAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Revert_IfToAddressMismatch() public {
        // pretend that the pool doesn't have STETH_MAINNET
        vm.mockCall(route.pool, abi.encodeWithSelector(ICurveV1StableSwap.coins.selector, 1), abi.encode(RANDOM));
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "toAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Works() public view {
        adapter.validate(WETH_MAINNET, route);
    }

    function test_swap_Works() public {
        uint256 sellAmount = 1e18;

        deal(WETH_MAINNET, address(this), 10 * sellAmount);
        IERC20(WETH_MAINNET).approve(address(adapter), 4 * sellAmount);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = address(adapter).delegatecall(
            abi.encodeWithSelector(
                ISyncSwapper.swap.selector, route.pool, WETH_MAINNET, sellAmount, STETH_MAINNET, 1, route.data
            )
        );

        assertTrue(success);

        uint256 val = abi.decode(data, (uint256));

        assertGe(val, 0);
    }
}
