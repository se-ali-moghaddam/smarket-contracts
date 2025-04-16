//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error NothingToWithdraw();
error FailedToWithdrawEth(address msgSender, address beneficiary, uint256 amountEth);

contract Withdraw {
    using SafeERC20 for IERC20;

    function withdraw(address beneficiary, address token) public virtual {
        if (token == address(this)) {
            uint256 amountEth = address(this).balance;

            if (amountEth == 0) revert NothingToWithdraw();

            (bool sent, ) = beneficiary.call{value: amountEth}("");

            if (!sent)
                revert FailedToWithdrawEth(msg.sender, beneficiary, amountEth);
        }

        uint256 amount = IERC20(token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(token).safeTransfer(beneficiary, amount);
    }
}
