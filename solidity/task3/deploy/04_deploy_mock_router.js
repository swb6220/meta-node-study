//const { getNamedAccounts, deployments, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ deployments, getNamedAccounts }) => {

    console.log(`====== Deploying Mock router on network: ${network.name}`);
    if(!developmentChains.includes(network.name)) {
        console.log("    Skipping Mock router deployment on local network");
        return;
    }

    const { deploy } = deployments;
    const { firstAccount } = await getNamedAccounts();

    const mockRouter = await deploy("MockRouter", {
        contract: "MockRouter",
        from: firstAccount,
        args: [],
        log: true
        //waitConfirmations: 6
    });

    const mockRouterAddr = mockRouter.address;

    console.log(`    Mock router deployed successfully, address: ${mockRouterAddr}, deployer: ${firstAccount}`);
}

module.exports.tags = ["mockrouter", "test", "all"];