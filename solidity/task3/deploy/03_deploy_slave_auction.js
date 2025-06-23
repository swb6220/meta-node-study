//const { getNamedAccounts, deployments, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ deployments, getNamedAccounts }) => {
    const { deploy, log } = deployments;
    const { slaveDeployer } = await getNamedAccounts();

    console.log(`====== Deploying AuctionSlave on network: ${network.name}`);

    // const auctionMaster = await deployments.get("AuctionMaster");
    // const auctionMasterAddr = auctionMaster.address;
    let routerAddr;
    let linkTokenAddr;
    if(developmentChains.includes(network.name)) {
        const localCCIPTx = await deployments.get("CCIPLocalSimulator");
        const localCCIP = await ethers.getContractAt("CCIPLocalSimulator", localCCIPTx.address);
        const ccipConfig = await localCCIP.configuration();
        routerAddr = ccipConfig.destinationRouter_
        linkTokenAddr = ccipConfig.linkToken_
        console.log(`    local environment: destination router: ${routerAddr}, link token: ${linkTokenAddr}`);
    } else {
        routerAddr = networkConfig[network.config.chainId].router; 
        linkTokenAddr = networkConfig[network.config.chainId].linkToken;      
        console.log(`    none local environment: destination router: ${routerAddr}, link token: ${linkTokenAddr}`);
    }

    // address _auctionMaster, address _router, address _link
    const auctionSlave = await deploy("AuctionSlave", {
        contract: "AuctionSlave",
        from: slaveDeployer,
        args: [routerAddr, linkTokenAddr],
        log: true
        //waitConfirmations: 6
    });

    const auctionSlaveAddr = auctionSlave.address;
    console.log(`    AuctionSlave deployed successfully, address: ${auctionSlaveAddr}, deployer: ${slaveDeployer}`);
}

module.exports.tags = ["AuctionSlave", "slave", "all"];