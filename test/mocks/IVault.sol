// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IVault {
    function mintForStrategy(uint256 amount) external;
    function burnForStrategy(uint256 amount) external;
    function totalValue() external view returns (uint256);
}
