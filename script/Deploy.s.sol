// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { RinSwap } from "../src/Rin.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/guides/scripting-with-solidity
contract Deploy is BaseScript {
    function run(address router, address wrappedETH) public broadcast returns (RinSwap) {
        uint256 feeRate = 100; // 1%
        RinSwap manager = new RinSwap(router, wrappedETH, feeRate);
        return manager;
    }
}
