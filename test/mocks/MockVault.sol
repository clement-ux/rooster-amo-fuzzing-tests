// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Interface
import {IVault} from "./IVault.sol";

// AMO
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";

// Mocks
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract MockVault is IVault {
    MockERC20 public immutable weth;
    MockERC20 public immutable oeth;
    RoosterAMOStrategy public immutable strategy;

    constructor(MockERC20 _weth, MockERC20 _oeth, RoosterAMOStrategy _strategy) {
        weth = _weth;
        oeth = _oeth;
        strategy = _strategy;
    }

    function mintForStrategy(uint256 amount) external override {
        oeth.mint(msg.sender, amount);
    }

    function burnForStrategy(uint256 amount) external override {
        oeth.burn(msg.sender, amount);
    }

    function totalValue() external view override returns (uint256) {
        require(oeth.balanceOf(address(this)) == 0, "Vault should be empty");
        return strategy.checkBalance(address(weth));
    }
}
