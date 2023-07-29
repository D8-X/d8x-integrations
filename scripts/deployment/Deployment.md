# Deployment

Set the following environment variables

- `export PK=...` (private key with network tokens to deploy)
- `export RPC=...` (your RPC)
- `export APIKEY=...` (key for Etherscan)

Deploy:

- `npx hardhat deploy --network mumbai --tags OnChainTrader`
- Verify by coping the line output from the script starting with `npx hardhat verifiy`
