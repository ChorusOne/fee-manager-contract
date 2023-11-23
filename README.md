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
