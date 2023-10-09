// SPDX-License-Identifier: none
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {WETH9} from "src/WETH9.sol";
import {Handler} from "test/handlers/Handler.sol";

contract WETH9Invriants is Test {
    WETH9 weth;
    Handler handler;

    function setUp() public {
        weth = new WETH9();
        handler = new Handler(weth);

        targetContract(address(handler));
    }

    // function invariant_wethSupplyIsAlwaysZero() public {
    //     assertEq(0, weth.totalSupply());
    // }

    function test_zeroDeposit() public {
        weth.deposit{value: 0}();
        assertEq(0, weth.balanceOf(address(this)));
        assertEq(0, weth.totalSupply());
    }

    // ETH can only be wrapped into WETH, WETH can only
    // be unwrapped back into ETH. The sum of the Handler's
    // ETH balance plus the WETH totalSupply() should always
    // equal the total ETH_SUPPLY.
    function invariant_conservationOfETH() public {
        assertEq(handler.ETH_SUPPLY(), address(handler).balance + weth.totalSupply());
    }

    // The WETH contract's Ether balance should always be
    // at least as much as the sum of individual balances
    function invariant_solvencyBalances() public {
        uint256 sumOfBalances;
        address[] memory actors = handler.actors();
        for (uint256 i; i < actors.length; ++i) {
            sumOfBalances += weth.balanceOf(actors[i]);
        }
        assertEq(address(weth).balance, sumOfBalances);
    }
    // function invariant_solvencyBalances() public {
    //     uint256 sumOfBalances = 0;
    //     assertEq(address(weth).balance, sumOfBalances);
    // }
}
