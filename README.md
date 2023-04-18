# D8XIntegrations

`yarn`

## MockLego

The contract `MockLego.sol` provides an example on how D8X perpetual futures trades can be performed from another smart contract.
You can get the parameters used in the constructor with the help of `ts-node src/scripts/contractAddresses.ts`
Example output of contractAddresses:

```
D8X Perpetual Proxy Address 0xDEDf0dd46757cE93E0D9439F78382c0c68cF76C2
Pool 1: MATIC, margin token address: 0x215975839684a365df2387b1f0FcEaBf4F0B77eb
        perpetual id 100000 : MATIC-USD-MATIC with order book @ 0xAE7bA6903e7B6DDf68b2b3B08A4b92c1e325EC87
        perpetual id 100001 : ETH-USD-MATIC with order book @ 0xC2faeaec27F4e1b456e3670c0fE5dCd639f1A6E4
        perpetual id 100002 : BTC-USD-MATIC with order book @ 0x7dAd5016c06d56929EC260682091443D1A025fA6
Pool 2: USDC, margin token address: 0xeB4E22B2AD4D9d07C25A32f57d85a4F41ca6b8FF
        perpetual id 200000 : MATIC-USDC-USDC with order book @ 0x55Ff74E202e7332b9217F09c6da2a08bd5577EBB
        perpetual id 200001 : ETH-USDC-USDC with order book @ 0xF9d88b2530c8A76c95778b594Ec7C5ea96903b03
        perpetual id 200002 : BTC-USDC-USDC with order book @ 0xf30b1F2BC443DaAD1925D781C145d70FFC2f2784
        perpetual id 200003 : CHF-USDC-USDC with order book @ 0x15677A9458878224e362d81f581C58225e1d4899
        perpetual id 200004 : GBP-USDC-USDC with order book @ 0x01230C38BFB3Daf3eFf7300974f666b41846A938
        perpetual id 200005 : XAU-USDC-USDC with order book @ 0xE02E39B7f4aF82966D481bB084458aE9334a9EcE
```

Get help on the Node SDK used in this script from https://d8x.gitbook.io/d8x/node-sdk/getting-started
