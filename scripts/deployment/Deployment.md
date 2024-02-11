# Deployment
Here is how to deploy the example contract `OnChainTrader.sol`.
Set the following environment variables in your terminal: PK, RPC, APIKEY. For example using a Linux terminal:

- `$ export PK=...` (private key with network tokens to deploy)
- `$ export RPC=...` (your RPC)
- `$ export APIKEY=...` (key for Etherscan)

Deploy:
- The relevant configured network names are as follows: zkevm (Mainnet 1101), zkevmTestnet (Testnet 1442),  cardona (Testnet 2442), X1 (Testnet 195). Pick one to deploy to. Note that you could check [hardhat.config.ts](../../hardhat.config.ts) to see available network configurations.
- `npx hardhat deploy --network zkevm --tags OnChainTrader`. Use the relevant network in place of `zkevm` if you deploy elsewhere.
- Verify smart contracts by coping the line output from the script starting with `npx hardhat verifiy`
