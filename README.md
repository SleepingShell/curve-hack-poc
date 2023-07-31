# Curve Reentrancy
On July 30, 2023 serveral exploits on curve occurred, [here is a link](https://openchain.xyz/trace/ethereum/0xb676d789bb8b66a08105c844a49c2bcffb400e5c1cfabd4bc30cca4bff3c9801) to one of them.

After analysis, it turns out that the Vyper compiler versions [0.2.15- 0.3.0] contained a bug regarding the `@nonreentrant` modifier. It turns out that instead of using the same storage slot for the `@nonreentrant` modifier across functions, each function was receiving their own storage slot. Therefore, reentrancy was prevented within the same function, but you could reenter the contract at a different function call.

Curve has pools that interact directly with Ether by using the `raw_call` Vyper function. This call will hand off execution if the destination is a smart contract, and therefore enables reentrancy to occur. When this reentrancy is occuring, state variables in the contract and the pool token supply are not aligned, and enable funds to be stolen.

Researchers found that in Vyper 0.3.1 the issue was [fixed](https://github.com/vyperlang/vyper/pull/2439).

The Llama Risk team of Curve DAO published a post mortem here: https://hackmd.io/@LlamaRisk/BJzSKHNjn

# POC
This repo contains a simple POC demonstrating the alETH attack. `remove_liquidity` will use the `raw_call` function, which enables the reentrancy in the alETH-ETH pool. See the `test/` directory. Note that not all Curve pools are the same, and therefore the attacks carried out are different variations of this POC. See the post mortem for details.

In order to run the POC, you must run it at a block earlier than the attack occured, for example:
`forge test --fork-url $RPC_URL --fork-block-number 17806760`

For the time being, the code is not published in order for whitehats to do their work. Once I get the go ahead the code will be published :) If you are interested in the meantime, I suggest you try to write your own! It's a very simple attack.