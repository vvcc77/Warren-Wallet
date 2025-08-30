// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "./MockERC20.sol";

contract MockPool {
    mapping(address => uint256) public supplied;
    function supply(address asset, uint256 amount, address, uint16) external {
        require(MockERC20(asset).transferFrom(msg.sender, address(this), amount));
        supplied[asset] += amount;
    }
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        uint256 avail = supplied[asset];
        uint256 out = amount > avail ? avail : amount;
        if (out > 0) {
            supplied[asset] -= out;
            require(MockERC20(asset).transfer(to, out));
        }
        return out;
    }
}
