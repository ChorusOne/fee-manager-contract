# fee-manager-contract

Contracts for managing validator's rewards fees

## How it works on a high-level

- The repo contains 2 contracts: `FeeRewardsManager` and `RewardsCollector`
- Fee manager contract `FeeRewardsManager` will be deployed once per environment
- `FeeRewardsManager` creates one `RewardsCollector` contract per withdrawal credentials (some users may have more than 1)
- On creation `FeeRewardsManager` sets a default commission fee and has permission to change that fee
- `RewardsCollector` address will be derived from `withdrawal credentials`
- `RewardsCollector` address will be set as `fee_recipient` for customers validators and earn execution rewards
- `collectRewards` function in `RewardsCollector` contract can be triggered to send rewards minus commission fee to withdrawal address

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
the `manager` contract has a default tax, it gets _copied_ to the `collector` contract during contract creation,
these tax can be modified by the owner of the `manager` contract.

Let's assume the tax `x` is 28% and
an someone decides to call `collectRewards` in
the `collector` contract, this contract splits the 10 Ether
rewards in 2:
    `10*28%` = 2.8 Ether goes to the `manager` contract.
    `10 - 2.8` = 7.2 Ether goes to the `withdrawal credential` associated with the contract.

Finally, the owner of `manager` can call `getEth` specifying an address to
receive the Ether accumulated in the contract.