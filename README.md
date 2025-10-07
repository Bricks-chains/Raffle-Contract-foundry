# Raffle Smart Contract
## Description 
 The Raffle contract is a smart contract build on foundry on the Ethereum blockchain that allows participants enter into a lottery and records all players in that lottery. All participants will need to enter with a constant minimum entrance fee which will be stored in the contract address, A winner is then only selected randomly using `chainlink VRF` after some set of custom logic is satisfied, once a winner is selected all the accumulated entrance fee accumulated for the lottery duration is then send to the winner and another lottery round continues

 ## Features
 ### Quickstart
 ```
 git clone https://github.com/Cyfrin/foundry-smart-contract-lottery-cu
 cd foundry-smart-contract-lottery-cu
 forge build
 ```
 ### Below are the key functionalities of the Raffle smart contract
 - Keeps Record of players 
 - Has a minimum fee required for entering the lottery
 - Raffle has two state indicating if raffle is `Open` or `Calculating` a winner randomly
 - stores all lottery winners in an array
 - They is a function that enables players enter raffle with an entrance fee
 - `checkUpkeep` function that makes sure a winner is only selected after a set period of raffle duration is reached
 - an automated `performUpkeep` function that sends a random number request to chainlink VRF
 - `fufillRandomWords` function will only be called by chainlink VRF to deliver a random number which will be used to select a random winner of our lottery and pays the winner address simultaneously 

## Contracts
The raffle project has one main contract in its source folder (`src`) and one major contract in the script folder (`script`) which help set the configurations necessary for the raffle constructor inputs to be used for testing and deployment
### Helper config 
This contract set variables like 
- minimum entrance fee
- subscription id which is necessary for using chainlink VRF to get random number
- vrfcoordinator address which is a contract address that help create subscription, fund subscription, add consumer to subscription, delete consumer from subscription
- Interval which is the duration of time taken for each raffle round
- `callbackgaslimit` is the maximum gas that can be spent for every call chainklink vrf makes back to the raffle contract to give it random number
- `Link` contract address. A token contract address used to pay for the cost of using chainlink VRF
- `Keyhash` the gaslane that serve as a unique identifier for the chainlink VRF node serving the Raffle contract with random number
- `account` the EOA which will be deploying the raffle contract.

# Usage
All commands needed for interacting with the contract are located here. Commands like test command, deploy command and scripting command.
#### All code are implementations of the makefile which i used in automating the contract
## Deployment
### Deploy on Anvil chain
```
make anvil
```
copy your anvil rpc url and put it in the .env file then run:
```
make deploy
```

### Deploy on Sepolia Ethereum testnet chain
copy your sepolia rpc url from the [Alchemy](https://alchemy.com/?a=673c802981) node provider or from your custom node if you can. Then configure it in the .env file and run:
```
make deploy ARGS='--network-sepolia'
```
## Scripting
#### create subscription
```
make createSubscription ARGS='--network-sepolia'
```
#### fund subscription
```
make fundSubscription ARGS='--network-sepolia'
```
#### add subscription
```
make addConsumer ARGS='--network-sepolia'
```
## Testing
to test across all test type like Unit and Integration run:
```
make test
```
#### View Test coverage
to see the degree of all branches and functions been tested run:
```
make coverage
```
## Gas Used
```
make snapshot
```
# License
### MIT License
```
SPDX-License-Identifier: MIT
```
# Author and Contributors
- Core Dev [Bricks On X(formally twitter)](https://x.com/bricks_chains)
- [Bricks On GitHub](https://github.com/Andrewgx)
  
  [![Bricks Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/bricks_chains)
# Aknowledgments
### A very big Thank you To Patrick Collins At
[![Patrick Collins Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/PatrickAlphaC)
[![Patrick Collins YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/channel/UCn-3f8tw_E1jZvhuHatROwA)
[![Patrick Collins Linkedin](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/patrickalphac/)
[![Patrick Collins Medium](https://img.shields.io/badge/Medium-000000?style=for-the-badge&logo=medium&logoColor=white)](https://medium.com/@patrick.collins_58673/)