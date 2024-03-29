# fee-manager-contract

Contracts for managing validator's rewards fees

## Overview

- The repo contains 2 contracts: `FeeRewardsManager` and `RewardsCollector` and a library `CalculateAndSendRewards`
- Fee manager contract `FeeRewardsManager` will be deployed once per environment.
- `FeeRewardsManager` creates one `RewardsCollector` contract per withdrawal credentials (some users may have more than 1)
- On creation `FeeRewardsManager` sets a default commission fee and has permission to change that fee.
- `RewardsCollector` address will be derived from `withdrawal credentials`.
- `RewardsCollector` address will be set as `fee_recipient` for customers validators and earn execution rewards.
- `collectRewards` function in `RewardsCollector` contract can be triggered to send rewards minus commission fee to withdrawal .address.

### `RewardsCollector` Contract

- **Ownership**: This contract does not explicitly use an ownership model. Instead, it references a `parentContract`, the contract that deployed it, the `FeeRewardsManager` contract.
- **withdrawalCredential**: A crucial address that is set upon contract deployment, determining where a portion of the fees are sent.
- **feeNumerator**: A value determining the fee percentage, modifiable only by the `parentContract`.

### `FeeRewardsManager` Contract

- **Ownership**: Inherits from `Ownable2Step`, a variant of the OpenZeppelin `Ownable` contract, which provides a secure ownership model with a two-step transfer process to prevent accidental loss of ownership. The part that is receiving
the ownership on the transfer must confirm it with a transaction.
- **defaultFeeNumerator**: Set upon deployment and modifiable by the contract owner.
- **Eth Withdrawal**: Only the owner can withdraw Eth from the contract.

## Deploying

Copy and populate `.env.dist` to `.env` in the root directory
To deploy to Goerli, run:

```
forge script ./script/FeeRewardsManager.s.sol --verify --broadcast --rpc-url goerli --private-key ${PRIVATE_KEY}
```

Switch to `--rpc-url mainnet` making sure the `mainnet` RPC endpoint exists in the `foundry.toml` file.
If deploying with a ledger, instead of `--private-key ${PRIVATE_KEY}`, use `--ledger`.

## Deployments

This contract is currently deployed on:

| Network      | FeeRewardsManager     | CalculateAndSendRewards |
|--------------|-----------------------|-------------------------|
| Mainnet | [0x5Bab02440602302Fb20906B04051e5D6c074D57f](https://etherscan.io/address/0x5Bab02440602302Fb20906B04051e5D6c074D57f) | [0x8D03884EF3F39ec263F3D7c3954A868468ff8497](https://etherscan.io/address/0x8D03884EF3F39ec263F3D7c3954A868468ff8497)|
| Goerli | [0x3ca56c8ba036adb672215dc5ed4577a3f1a239d3](https://goerli.etherscan.io/address/0x3ca56c8ba036adb672215dc5ed4577a3f1a239d3) | [0x7f18c4901b68d6aebac40b2e2f5ec3516d95ee2a](https://goerli.etherscan.io/address/0x7f18c4901b68d6aebac40b2e2f5ec3516d95ee2a) |
| Holesky | [0x8Ef21C0E9d86230cdD73C816cb48987Da3CDaF22](https://holesky.etherscan.io/address/0x8Ef21C0E9d86230cdD73C816cb48987Da3CDaF22) | [0x096874A27f6f9838dCB1422098D389852007244b](https://holesky.etherscan.io/address/0x096874A27f6f9838dCB1422098D389852007244b) |

## Walkthrough a normal execution

Deploy `FeeRewardsManager` as `manager`, then we call
`predictFeeContractAddress(_withdrawalCredential)` passing the validator's
withdrawal credentials, the function can be called offline and produces a
deterministic `collector` address for the withdrawal credential.
We set the `collector` address as the `fee recipient` for the validator. Observe
that the `collector` address can start receiving Ether even if the contract is not deployed,
we can delay the execution of `manager` that creates the `collector` contract to a convenient time.
Let's say the validator accumulated 10 Ether in rewards in the `collector` address.

Anyone can decide to call `createFeeContract` in the `manager` contract, passing the
withdrawal credentials, this will create the `collector` contract where the `collector` address was in place,
note that the contract state will already have 10 Ether.
By default, the `manager` contract gets `collector.balance * x` and the
`withdrawal_credential` contract gets the rest of the Ether (`collector.balance - collector.balance * x`).
the `manager` contract has a default tax, it gets *copied* to the `collector` contract during contract creation,
these tax can be modified by the owner of the `manager` contract.

Let's assume the tax `x` is 28% and
an someone decides to call `collectRewards` in
the `collector` contract, this contract splits the 10 Ether
rewards in 2:
    `10*28%` = 2.8 Ether goes to the `manager` contract.
    `10 - 2.8` = 7.2 Ether goes to the `withdrawal credential` associated with the contract.

Finally, the owner of `manager` can call `getEth` specifying an address to
receive the Ether accumulated in the contract.

## Trust Model

Chorus One operates the Ethereum validators with this smart contract. They provide a
smart contract that should be used as the validator's fee recipient.
Users are required to place a significant amount of trust in Chorus One. This
trust encompasses:

1. **Validator Operation**: Users trust that Chorus One will operate its
validators effectively and in compliance with the network's protocols.
Slashing penalties are imposed on validators for actions deemed harmful to the
network, like double signing or downtime. Users trust that Chorus One
will avoid behaviors that could trigger these penalties, as slashing can lead to
a partial loss of the staked assets.

2. **Management of Validator Fees**: Validator fees are a portion of the rewards
earned by validators for their service to the network. Users trust that
Chorus One will maintain transparency and fairness in setting and distributing
these fees and not alter the recipient of these fees without clear communication
and rationale.

3. **Exit Validators on User's behalf**: Users might request to exit their validators,
in this case, they trust that Chorus One will exit the validators according to user requests.

Users should perform due diligence and continually monitor the validator's
performance and reputation.
