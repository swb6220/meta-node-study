//const { getNamedAccounts, deployments, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ deployments, getNamedAccounts }) => {

    console.log(`====== Deploying CCIP on network: ${network.name}`);
    if(!developmentChains.includes(network.name)) {
        console.log("    Skipping CCIP deployment on local network");
        return;
    }

    const { deploy, log } = deployments;
    const { firstAccount } = await getNamedAccounts();

    console.log(`    Deploying CCIP contract, deploy account: ${firstAccount}...`);

    const ccip = await deploy("CCIPLocalSimulator", {
        contract: "CCIPLocalSimulator",
        from: firstAccount,
        args: [],
        log: true
        //waitConfirmations: 6
    });

    const ccipAddr = ccip.address;

    console.log(`    CCIP deployed successfully, address: ${ccipAddr}`);
}

module.exports.tags = ["localccip", "test", "all"];