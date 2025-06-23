//const { getNamedAccounts, deployments } = require("hardhat");

module.exports = async ({deployments, getNamedAccounts}) => {
    console.log(`====== Deploying NFT on network: ${network.name}`);
    const {deploy, log} = deployments;
    const {firstAccount} = await getNamedAccounts();

    const myTokenNFT = await deploy("MyErc721Nft", {
        contract: "MyErc721Nft",
        from: firstAccount,
        args: [],
        log: true
        //waitConfirmations: 6
    });
    
    //const nftTx = await deployments.get("MyErc721Nft")
    nftAddr = myTokenNFT.address

    console.log(`    NFT deployed successfully, address: ${nftAddr}, deployer: ${firstAccount}`);
}

module.exports.tags = ["NFT", "master", "all"];