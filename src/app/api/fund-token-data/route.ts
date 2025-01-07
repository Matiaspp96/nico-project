import { FundTokenData, FundTokenDataError } from "@/types";
import { ethers } from "ethers";
import { promises as fs } from "fs";
import { NextResponse } from "next/server";
import path from "path";
import { base } from "viem/chains";

import deployerContractABI from "@/constants/deployer-abi.json";
import addresses from "@/constants/address";

const setRandomColorToToken = (colorsHaveBeenUsed?: string[]) => {
  const colors = [
    "#1E88E5",
    "#43A047",
    "#7CB342",
    "#546E7A",
    "#EC407A",
    "#FB8C00",
    "#2EBD85",
    "#35FC95",
    "#2B3139",
    "#546E7A",
    "#EC407A",
    "#FB8C00",
    "#2EBD85",
    "#35FC95",
    "#FFC433",
    "#33FCFF",
    "#4633FF",
    "#7D33FF",
    "#FF3380",
  ];
  const randomIndex = Math.floor(Math.random() * colors.length);
  const color = colors[randomIndex];
  if (colorsHaveBeenUsed && colorsHaveBeenUsed.includes(color)) {
    return setRandomColorToToken(colorsHaveBeenUsed);
  }
  return color;
};

const getTokenInfo = async (tokenAddress: string) => {
  const provider = new ethers.JsonRpcProvider(base.rpcUrls.default.http[0]);
  const deployerContract = new ethers.Contract(
    addresses.deployerAddress,
    deployerContractABI,
    provider
  );
  try {
    const tokenInfo = await deployerContract.getTokenDetails(tokenAddress);
    tokenInfo.addressTreasury = tokenInfo.addressTreasure;
    return tokenInfo;
  } catch (error) {
    console.error("Error fetching token info:", error);
    return { error: "Error fetching token info" };
  } finally {
    provider.destroy();
  }
};

const assetsFromTreasury = async (treasuryAddress: string) => {
  const MORALIS_API_KEY = process.env.MORALIS_API_KEY;
  const MORALIS_API_URL = `https://deep-index.moralis.io/api/v2.2/wallets/${treasuryAddress}/tokens?chain=base`;
  try {
    const response = await fetch(MORALIS_API_URL, {
      headers: {
        "X-API-Key": MORALIS_API_KEY || "",
      },
    });
    const data = await response.json();
    console.log("dataMoralis", data);
    return data.result;
  } catch (error) {
    console.error("Error fetching assets from treasury:", error);
    return { error: "Error fetching assets from treasury" };
  }
};

const getPriceTokenUSD_Liquidity = async (tokenAddress: string) => {
  try {
    const BIRDEYE_API_KEY = process.env.BIRDEYE_API_KEY;
    const BIRDEYE_API_URL = `https://public-api.birdeye.so/defi/price?include_liquidity=true&address=${tokenAddress}`;
    const response = await fetch(BIRDEYE_API_URL, {
      headers: {
        "X-API-Key": BIRDEYE_API_KEY || "",
        "x-chain": "base",
      },
    });
    const data = await response.json();
    const liquidity = data.data.liquidity;
    const price = data.data.value;
    return { liquidity, price };
  } catch (error) {
    console.error("Error fetching price token USD and liquidity:", error);
    return { error: "Error fetching price token USD and liquidity" };
  }
};

const calculateMarketCap = (totalSupply: number, price: number) => {
  return totalSupply * price;
};

const calculateTotalNetWorth = (
  assets: {
    usd_value: number;
  }[]
) => {
  return assets.reduce((acc, asset) => acc + asset.usd_value, 0);
};

export async function GET(req: Request) {
  console.log("[GET][api/fund-token-data]");
  const { searchParams } = new URL(req.url);
  const tokenName = searchParams.get("tokenName")?.toLowerCase();
  const tokenAddress = searchParams.get("tokenAddress")?.toLowerCase();
  if (!tokenName || !tokenAddress) {
    return NextResponse.json(
      { error: FundTokenDataError.TOKEN_ADDRESS_REQUIRED },
      { status: 400 }
    );
  }

  try {
    console.log("[GET][api/fund-token-data] tokenName", tokenName);
    const jsonDirectory = path.join(process.cwd(), "json");
    const fileContents = await fs.readFile(
      jsonDirectory + "/data.json",
      "utf8"
    );
    const allFundTokenData: { [key: string]: FundTokenData } =
      JSON.parse(fileContents);
    const tokenData = Object.values(allFundTokenData).find(
      (token: { name: string }) => token.name.toLowerCase() === tokenName
    );

    if (!tokenData || !tokenAddress) {
      return NextResponse.json(
        { error: FundTokenDataError.FUND_TOKEN_DATA_NOT_FOUND },
        { status: 404 }
      );
    }

    console.log("tokenData", tokenData);
    console.log("tokenAddress", tokenAddress);

    /* Check if the token data is not initialized */
    if (Object.values(tokenData).length <= 4) {
      try {
        // const tokenInfo = await getTokenInfo(tokenAddress);
        const tokenInfo = {
          name: "ChillBull",
          description:
            "Chill Bull is a token that is used to reward the community for their contributions to the project.",
          treasuryAddress: "0x863B8801D8125D2BA10b53268fd6313043843536",
          poolAddress: "0xda40f85288f6d88280975cb89a88cdf4577bda9b",
          totalSupply: 100000000000,
          imageURL:
            "https://www.clanker.world/_next/image?url=https%3A%2F%2Fimagedelivery.net%2FBXluQx4ige9GuW0Ia56BHw%2Fa2b0cd06-942e-45e3-cef5-4c49dc391900%2Foriginal&w=128&q=75",
          symbol: "CHILLBULL",
          decimals: 18,
        };
        const assets = await assetsFromTreasury(tokenInfo.treasuryAddress);
        assets?.forEach((asset: { color: string }) => {
          asset.color = setRandomColorToToken();
        });
        const totalNetWorth = calculateTotalNetWorth(assets);
        const { liquidity, price } = await getPriceTokenUSD_Liquidity(
          tokenAddress
        );
        const marketCap = calculateMarketCap(tokenInfo.totalSupply, price);

        tokenData.metrics = [
          {
            label: "Market Cap",
            value: marketCap.toFixed(2),
          },
          {
            label: "Your Holdings",
            value: "0",
          },
          {
            label: "Your Market Value",
            value: "0",
          },
        ];

        const tokenDataToWriteForFile = {
          name: tokenInfo.name,
          description: tokenData.description,
          stats: [
            { label: "Liquidity", value: liquidity.toFixed(2) },
            { label: "Price Token/USD", value: price.toFixed(9) },
          ], // TODO: get stats from pool
          assets: assets?.map(
            (asset: {
              symbol: string;
              portfolio_percentage: number;
              color: string;
            }) => ({
              name: asset.symbol,
              percentage: asset.portfolio_percentage,
              color: asset.color,
              fill: asset.color,
            })
          ),
          totalNetWorth: totalNetWorth,
          metrics: tokenData.metrics, // TODO: get metrics from pool
          treasuryAddress: tokenInfo.treasuryAddress,
          tokenAddress: tokenAddress,
          tokenImage: tokenInfo.imageURL,
          tokenSymbol: tokenInfo.symbol,
          tokenDecimals: tokenInfo.decimals,
          tokenTotalSupply: tokenInfo.totalSupply,
          poolAddress: tokenData.poolAddress,
          updatedAt: new Date().toISOString(),
          createdAt: tokenData.createdAt,
        };
        allFundTokenData[tokenAddress] = tokenDataToWriteForFile;
        await fs.writeFile(
          jsonDirectory + "/data.json",
          JSON.stringify(allFundTokenData, null, 2)
        );
        return NextResponse.json(tokenDataToWriteForFile, { status: 200 });
      } catch (error) {
        console.error("Error writing token data to file:", error);
        return NextResponse.json(
          { error: "Error writing token data to file" },
          { status: 500 }
        );
      }
    }

    if (tokenData.updatedAt) {
      const lastUpdated = new Date(tokenData.updatedAt);
      const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000); // 12 hours ago

      if (lastUpdated <= twelveHoursAgo) {
        try {
          const tokenInfo = await getTokenInfo(tokenAddress);
          const assets = await assetsFromTreasury(tokenInfo.treasuryAddress);
          const totalNetWorth = calculateTotalNetWorth(assets);
          const { liquidity, price } = await getPriceTokenUSD_Liquidity(
            tokenInfo.tokenAddress
          );
          const colorsHaveBeenUsed = tokenData.assets.map(
            (asset: { color: string }) => asset.color
          );
          const colorPick = setRandomColorToToken(colorsHaveBeenUsed);
          const marketCap = calculateMarketCap(tokenInfo.totalSupply, price);
          const marketCapVector = tokenData.metrics.find(
            (metric: { label: string }) => metric.label === "Market Cap"
          );
          if (marketCapVector) {
            marketCapVector.value = marketCap.toFixed(2);
          } else {
            tokenData.metrics.push({
              label: "Market Cap",
              value: marketCap.toFixed(2),
            });
          }

          const tokenDataToWriteForFile = {
            name: tokenInfo.name,
            description: tokenData.description,
            stats: [
              { label: "Liquidity", value: liquidity.toFixed(2) },
              { label: "Price Token/USD", value: price.toFixed(9) },
            ], // TODO: get stats from pool
            assets: assets.map(
              (asset: { symbol: string; portfolio_percentage: number }) => ({
                name: asset.symbol,
                percentage: asset.portfolio_percentage,
                color: colorPick,
                fill: colorPick,
              })
            ),
            metrics: [...tokenData.metrics], // TODO: get metrics from pool
            totalNetWorth: totalNetWorth,
            treasuryAddress: tokenInfo.treasuryAddress,
            tokenAddress: tokenAddress,
            tokenImage: tokenInfo.imageURL,
            tokenSymbol: tokenInfo.symbol,
            tokenDecimals: tokenInfo.decimals,
            tokenTotalSupply: tokenInfo.totalSupply,
            poolAddress: tokenInfo.poolAddress,
            updatedAt: new Date().toISOString(),
            createdAt: tokenData.createdAt,
          };
          await fs.writeFile(
            jsonDirectory + "/data.json",
            JSON.stringify(tokenDataToWriteForFile, null, 2)
          );
          return NextResponse.json(tokenDataToWriteForFile, { status: 200 });
        } catch (error) {
          console.error("Error in GET /api/fund-token-data", error);
          return NextResponse.json(
            { error: FundTokenDataError.UNKNOWN_ERROR },
            { status: 500 }
          );
        }
      }
    }

    return NextResponse.json(tokenData, { status: 200 });
  } catch (error) {
    console.error("Error in GET /api/fund-token-data", error);
    return NextResponse.json(
      { error: FundTokenDataError.UNKNOWN_ERROR },
      { status: 500 }
    );
  }
}
