const { getNamedAccounts, deployments, network } = require("hardhat");
const { ethers } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({deployments, getNamedAccounts}) => {
    const {deploy} = deployments;
    const {firstAccount} = await getNamedAccounts();
    console.log(`====== Deploying AuctionMaster on network: ${network.name}`);

    const nft = await deployments.get("MyErc721Nft");
    const nftAddr = nft.address;
    let routerAddr;
    let linkTokenAddr;
    if(developmentChains.includes(network.name)) {
        const localCCIPTx = await deployments.get("CCIPLocalSimulator");
        const localCCIP = await ethers.getContractAt("CCIPLocalSimulator", localCCIPTx.address);
        const ccipConfig = await localCCIP.configuration();
        routerAddr = ccipConfig.sourceRouter_;
        linkTokenAddr = ccipConfig.linkToken_;
        console.log(`    local environment: sourcechain router: ${routerAddr}, link token: ${linkTokenAddr}`);
    } else {
        routerAddr = networkConfig[network.config.chainId].router; // Sepolia
        linkTokenAddr = networkConfig[network.config.chainId].linkToken; // Sepolia
        console.log(`    none local environment: sourcechain router: ${routerAddr}, link token: ${linkTokenAddr}`);
    }
    console.log(`    NFT address: ${nftAddr}`);

    const auctionMaster = await deploy("AuctionMaster", {
        contract: "AuctionMaster",
        from: firstAccount,
        args: [nftAddr, routerAddr, linkTokenAddr],
        log: true
        //waitConfirmations: 6
    });

    const auctionMasterAddr = auctionMaster.address;

    console.log(`    AuctionMaster deployed successfully, address: ${auctionMasterAddr}, deployer: ${firstAccount}`);
}

module.exports.tags = ["AuctionMaster", "master", "all"];