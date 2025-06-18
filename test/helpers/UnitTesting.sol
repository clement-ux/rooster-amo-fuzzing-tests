// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TargetFunction} from "../TargetFunction.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2PoolLens} from "@rooster-pool/v2-supplemental/contracts/interfaces/IMaverickV2PoolLens.sol";

contract UnitTesting is TargetFunction {}
