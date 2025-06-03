import { MarketData, PerpetualDataHandler } from '@d8x/perpetuals-sdk';
import { floatToABK64x64 } from '@d8x/perpetuals-sdk';

// specify address for dirac vault 
const DIRAC_VAULT="0xdef43CF2Dd024abc5447C1Dcdc2fE3FE58547b84";
// specify amount of honey in decimals (not decimal 18) to be invested in the strategy
const HONEY_DEC = 10_000;

const GOLD_PERP="XAU-USD-BUSD";
const BTC_PERP="BTC-USD-BUSD";

//determineBaseAmount returns the quantity and approximate entry price
async function determineBaseAmount(mktData:MarketData, spendAmountHoney: number, perpName: string, isLong: boolean) : Promise<[number, number]> {
    const perpId = mktData.getPerpIdFromSymbol(perpName);
    const currPos = await mktData.positionRisk(DIRAC_VAULT, perpName);
    const [maxShort, maxLong] = await mktData.getMaxShortLongTrade(perpId, floatToABK64x64(currPos[0].positionNotionalBaseCCY));
    let p = await mktData.getPerpetualMidPrice(perpName);
    let q1 = spendAmountHoney/p*0.99;
    let p2 = 1+spendAmountHoney/q1;//dummy value
    const sg = isLong ? 1 : -1;
    while (true) {
        p2 = await mktData.getPerpetualPrice(perpName, sg*q1);
        if (p2*q1<=spendAmountHoney) {
            break;
        }
        //shrink
        q1 = q1*0.9999;
    }
    let q = isLong ? Math.min(q1, maxLong) : Math.min(q1, Math.abs(maxShort));
    if (q!=q1) {
        console.log("shrinking quantity due to max trade size limit");
    }
    return [sg*q, p2*q]
}

async function main() {
  const config = PerpetualDataHandler.readSDKConfig("bera");
  let mktData = new MarketData(config);
  // Create a proxy instance to access the blockchain
  await mktData.createProxyInstance();

  // amount honey in decimal (not decimal 18) to spend
  const honey = HONEY_DEC; 
  // short Schiff (long BTC, short gold)
  let [q1,p1] = await determineBaseAmount(mktData, honey/2, BTC_PERP, true);
  let [q2,p2] = await determineBaseAmount(mktData, honey/2, GOLD_PERP, false);
  console.log("trade amount BTC:", q1, " price*quantity:", Math.round(q1*p1*100)/100);
  console.log("trade amount Gold:", q2, " price*quantity:", Math.round(q1*p2*100)/100);
  console.log("------- arguments for BTC:")
  console.log("iPerpetualId", mktData.getPerpIdFromSymbol(BTC_PERP));
  console.log("amountInt128", floatToABK64x64(q1));
  console.log("leverageTDR", 100);
  console.log("flags", 0);
  console.log("------- arguments for GOLD:")
  console.log("iPerpetualId", mktData.getPerpIdFromSymbol(GOLD_PERP));
  console.log("amountInt128", floatToABK64x64(q2)); 
  console.log("leverageTDR", 100);
  console.log("flags", 0);
}
main();