//SPDX-License-Identifier: none
pragma solidity ^0.8.18;

import {WETH9} from "src/WETH9.sol";
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {CommonBase} from "forge-std/Base.sol";
import {LibAddressSet, AddressSet} from "test/helpers/AddressSet.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;

    AddressSet internal _actors;

    WETH9 public weth;
    uint256 public constant ETH_SUPPLY = 120_500_000 ether;
    uint256 public ghost_depositSum;
    uint256 public ghost_withdrawSum;
    uint256 public ghost_zeroWithdrawals;

    address internal currentActor;

    mapping(bytes32 => uint256) public calls;

    constructor(WETH9 _weth) {
        weth = _weth;
        deal(address(this), ETH_SUPPLY);
    }

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function actors() external returns (address[] memory) {
        return _actors.addrs;
    }

    function deposit(uint256 amount) public createActor countCall("deposit") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        weth.deposit{value: amount}();

        ghost_depositSum += amount;
    }

    function withdraw(uint256 amount) public countCall("withdraw") {
        amount = bound(amount, 0, weth.balanceOf(msg.sender));
        if (amount == 0) ghost_zeroWithdrawals++;

        vm.startPrank(msg.sender);
        weth.withdraw(amount);
        _pay(address(this), amount);
        vm.stopPrank();

        ghost_withdrawSum += amount;
    }

    function sendFallback(uint256 amount) public createActor countCall("sendFallback") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        (bool success,) = address(weth).call{value: amount}("");

        require(success, "sendFallback failed");
        ghost_depositSum += amount;
    }

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function reduceActors(uint256 acc, function(uint256,address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _actors.reduce(acc, func);
    }

    function _pay(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
        console.log("withdraw", calls["withdraw"]);
        console.log("sendFallback", calls["sendFallback"]);
        console.log("-------------------");

        console.log("Zero withdrawals:", ghost_zeroWithdrawals);
    }

    receive() external payable {}
}
