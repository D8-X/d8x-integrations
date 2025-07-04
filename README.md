# D8XIntegrations

> The D8X community requested solidity calls for opening/closing trades and reading the size of the positions from another contract

## OnChainTrader

We therefore built "OnChainTrader". The contract `OnChainTrader.sol` provides an example for trading D8X perpetual futures from another contract.
The deployment scripts rely on [node SDK](https://d8x.gitbook.io/d8x/node-sdk/getting-started) the most up to date SDK contains the most up-to date contract
addresses.

Your smart contract can integrate into D8X Perpetuals similar to `OnChainTrader.sol`, most relevant features are:

- the contract posts orders to the order book (the contract address is the trader, hence funds for collateral need to be at the contract address)
- callback function that is invoked after order execution. Keep the callback light because of gas costs (there is a maximal amount of gas for callbacks)
- query margin account of the trader (=contract)

## Deployment Of The "OnChainTrader" Example

See [here](scripts/deployment/Deployment.md)

## Trading From The Example Contract

The deployment script sets the data for all current perpetual ids using D8X node SDK.
Before the contract can start trading,

- Spending has to be approved from the deployer address. This can be done via the block explorer using one of the following functions:
  - `approveCompositeToken(uint256 _amount, address _compositeToken, address _spendToken)`: for pools that use a composite token (e.g. Berachain perps)
  - `approveAmountForPerpetualMgnTkn(uint256 _amount, uint24 _iPerpetualId)`: for pools that do not use a composite token
- the relevant margin-tokens have to be sent to the contract. The contract has the margin token address stored after running the deployment script,
  and hence the address can be read for example via block-explorer: Read Contract > mgnTknAddrOfPool, enter pool id (first digit before the 00 of the perpetual id or get the pool id from the output of the deployment script, or SDK).
- now an order can be posted. On the block-explorer, navigate to 'write contract' > 'post order', enter the perpetual id you choose to trade in,
  the amount in the perpetual base currency (e.g. 1 for a contract amount of 1 ETH in a ETH-USD perpetual) multiplied by 10^18 (enter the number
  in quotation marks on the block-explorer, e.g., "500000000000000000000" for 500),
  enter the leverage multiplied by 100 (500 for 5x), you can set the flags to 0 for a market order
- If the contract emits an event whether the order was submitted succesfully to the order book or not. If the submission is successful,
  the execution also has to be successful, which you can observe on the order book contract.
  - for on-chain trading there is a callback function that is executed when the order was either successfully executed or the execution failed
  - the callback function is implemented in an arbitrary contract that implements the interface `ID8XExecutionCallbackReceiver` and for which its
    address is set in the order
- After trading, check your margin account, or, alternatively the callback function can update the margin account.
  - For example, navigate on the block-explorer to "read contract" > "getMarginAccount" and
    enter the perpetual id that you traded. The function returns data in the following format:
  ```
  struct D18MarginAccount {
    int256 lockedInValueQCD18; // unrealized value locked-in when trade occurs: notional amount * price in decimal 18 format
    int256 cashCCD18; // cash in collateral currency (base, quote, or quanto) in decimal 18 format
    int256 positionSizeBCD18; // position in base currency (e.g., 1 BTC for BTCUSD) in decimal 18 format
    }
  ```
- to close a position, trade the opposite size (e.g., "-500000000000000000000")

# Node SDK

Get help on the Node SDK used in `contractAddresses.ts` and the deployment scripts [here](https://d8x.gitbook.io/d8x/node-sdk/getting-started).

**Happy Integration!**
