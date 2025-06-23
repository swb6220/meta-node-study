const { deployments, ethers } = require("hardhat")
const { expect } = require("chai")
const { calculateTxFee, printLogs } = require("../scripts/utils/util.js");

    let firstAccount, secondAccount, thirdAccount, fourthAccount
    let nftTx, nft
    let auctionMaster
    let auctionSlave
    let localCCIP, routerAddr
    let ethPriceFeed, daiPriceFeed
    let daiToken
    let chainSelector = 16015286601757825753n

before(async function(){
    this.timeout(300000);

    console.log("----Test nft auction before")

    // await ethers.getSigners().then((signers) => {
    //     firstAccount= signers[0]
    //     secondAccount = signers[1]
    //     thirdAccount = signers[2]
    //     fourthAccount = signers[3]
    // })

    const signers = await ethers.getSigners()
    firstAccount = signers[0]
    secondAccount = signers[1]
    thirdAccount = signers[2]
    fourthAccount = signers[3]
    
    // console.log(`firstAccount: ${firstAccount.address}`)
    // console.log(`secondAccount: ${secondAccount.address}`)
    // console.log(`thirdAccount: ${thirdAccount.address}`)

    await deployments.fixture(["all"])
    nftTx = await deployments.get("MyErc721Nft")
    nft = await ethers.getContractAt("MyErc721Nft", nftTx.address)
    
    const auctionMasterTx = await deployments.get("AuctionMaster")
    auctionMaster = await ethers.getContractAt("AuctionMaster", auctionMasterTx.address)

    const auctionSlaveTx = await deployments.get("AuctionSlave")
    auctionSlave = await ethers.getContractAt("AuctionSlave", auctionSlaveTx.address)

    const localCCIPTx = await deployments.get("CCIPLocalSimulator")
    localCCIP = await ethers.getContractAt("CCIPLocalSimulator", localCCIPTx.address)

    const ccipConfig = await localCCIP.configuration();
    routerAddr = ccipConfig.sourceRouter_;

    await localCCIP.requestLinkFromFaucet(auctionMaster.target, ethers.parseEther("10"))
    await localCCIP.requestLinkFromFaucet(auctionSlave.target, ethers.parseEther("10"))
    

    // 创建ETH price feed, 并注册
    const AggregatorFactory = await ethers.getContractFactory("AggregatorV3")
    ethPriceFeed = await AggregatorFactory.deploy(2000)
    await ethPriceFeed.waitForDeployment()
    console.log(`    ETH price feed address: ${ethPriceFeed.target}`)
    await auctionMaster.connect(firstAccount).registerTokenAndPriceFeed("ETH", ethPriceFeed.target, ethers.getCreateAddress({from: "0x8ba1f109551bD432803012645Ac136ddd64DBA72", nonce: 19}))
    //创建测试DAI代币
    const DaiFactory = await ethers.getContractFactory("TestERC20Token")
    daiToken = await DaiFactory.deploy("This is DAI", "DAI")
    await daiToken.waitForDeployment()
    console.log(`    DAI token address: ${daiToken.target}`)
    // 注册DAI代币和价格预言机
    daiPriceFeed = await AggregatorFactory.deploy(1500)
    await daiPriceFeed.waitForDeployment()

    console.log(`    DAI price feed address: ${daiPriceFeed.target}`)
    // 注册DAI代币和价格预言机
    await auctionMaster.connect(firstAccount).registerTokenAndPriceFeed("DAI", daiPriceFeed.target, daiToken.target)

    // 给thirdAccount分配1000 DAI
    await daiToken.connect(firstAccount).transfer(thirdAccount.address, ethers.parseUnits("1000", "ether"))

    // 给secondAccount分配2000 DAI
    await daiToken.connect(firstAccount).transfer(secondAccount.address, ethers.parseUnits("2000", "ether"))
    
    // 给secondAccount分配2000 DAI
    await daiToken.connect(firstAccount).transfer(fourthAccount.address, ethers.parseUnits("2000", "ether"))

    // 给router分配DAI
    await daiToken.connect(firstAccount).transfer(routerAddr, ethers.parseUnits("2000", "ether"))

    // 给auctionMaster和auctionSlave分配1000 DAI
    await daiToken.connect(firstAccount).transfer(auctionMaster.target, ethers.parseUnits("1000", "ether"))
    await daiToken.connect(firstAccount).transfer(auctionSlave.target, ethers.parseUnits("1000", "ether"))

    // 设置从链chainSelector和地址信息
    await auctionMaster.connect(firstAccount).setAuctionSlaves(chainSelector, auctionSlave.target)
})

describe("Test my NFT auction.", async function() {
    this.timeout(300000);

    it("Test mint NFT", async function() {        
        let tokenId = await nft.mintNFT.staticCall();
        await nft.mintNFT();
        expect(tokenId).to.equals(1)
        let nftOwner = await nft.ownerOf(1)
        expect(nftOwner).to.equals(firstAccount.address)

        tokenId = await nft.mintNFT.staticCall();
        await nft.connect(secondAccount).mintNFT();
        expect(tokenId).to.equals(2)
        nftOwner = await nft.ownerOf(2)
        expect(nftOwner).to.equals(secondAccount.address)

        tokenId = await nft.mintNFT.staticCall();
        await nft.connect(thirdAccount).mintNFT();
        expect(tokenId).to.equals(3)
        nftOwner = await nft.ownerOf(3)
        expect(nftOwner).to.equals(thirdAccount.address)
    })

    it("Test transfer NFT", async function () {
        // set NFT 2 to be approved to thirdAccount
        await nft.connect(secondAccount).approve(thirdAccount, 2)
        let approved = await nft.getApproved(2)
        expect(approved).to.equals(thirdAccount.address)

        // transfer NFT 2 from secondAccount to thirdAccount
        await nft.connect(thirdAccount).transferFrom(secondAccount.address, thirdAccount.address, 2)
        let nftOwner = await nft.ownerOf(2)
        expect(nftOwner).to.equals(thirdAccount.address)

        await nft.connect(thirdAccount).transferFrom(thirdAccount.address, secondAccount.address, 2)
        nftOwner = await nft.ownerOf(2)
        expect(nftOwner).to.equals(secondAccount.address)
    })

    it("Test transfer not ownable NFT", async function() {
        await expect(nft.connect(thirdAccount).transferFrom(firstAccount.address, thirdAccount.address, 1)).to.be.reverted
        let nftOwner = await nft.ownerOf(1)
        expect(nftOwner).to.equals(firstAccount.address)

        await expect(nft.connect(thirdAccount).transferFrom(firstAccount.address, thirdAccount.address, 2)).to.be.reverted
        nftOwner = await nft.ownerOf(2)
        expect(nftOwner).to.equals(secondAccount.address)
    })
})

describe("Test auction master.", async function() {
    this.timeout(300000);
    let auctionId

    it("Test register bid token and price feed", async function() {
        // 创建测试token
        const TokenFactory = await ethers.getContractFactory("TestERC20Token")
        const token1 = await TokenFactory.deploy("This is token1", "token1")
        token1.waitForDeployment()
        const token2 = await TokenFactory.deploy("This is token2", "token2")
        token2.waitForDeployment()

        const token1Name = await token1.symbol()
        expect(token1Name).to.equals("token1")
        const token2Name = await token2.symbol()
        expect(token2Name).to.equals("token2")


        const token1Supply = await token1.totalSupply()
        expect(token1Supply).to.equals(300000000000000000000000000n)
        const token2Supply = await token2.totalSupply()
        expect(token2Supply).to.equals(300000000000000000000000000n)

        // 创建测试price feed
        const AggregatorFactory = await ethers.getContractFactory("AggregatorV3")
        const prieceFeed1 = await AggregatorFactory.deploy(10000)
        await prieceFeed1.waitForDeployment()
        
        const prieceFeed2 = await AggregatorFactory.deploy(200000)
        await prieceFeed2.waitForDeployment()

        // 注册代币和价格预言机
        await auctionMaster.connect(firstAccount).registerTokenAndPriceFeed("token1", prieceFeed1.target, token1.target)
        const priceFeedAddr1 = await auctionMaster.getPriceFeedAddress("token1")
        expect(priceFeedAddr1).to.equals(prieceFeed1.target)
        const tokenAddr1 = await auctionMaster.getTokenAddress("token1")
        expect(tokenAddr1).to.equals(token1.target)

        await auctionMaster.connect(firstAccount).registerTokenAndPriceFeed("token2", prieceFeed2.target, token2.target)
        const priceFeedAddr2 = await auctionMaster.getPriceFeedAddress("token2")
        expect(priceFeedAddr2).to.equals(prieceFeed2.target)
        const tokenAddr2 = await auctionMaster.getTokenAddress("token2")
        expect(tokenAddr2).to.equals(token2.target)
    })

    it("Test firstAccouont add auction for NFT 1", async function() {

        let tms = await auctionMaster.getTimestamp()

        await nft.connect(firstAccount).approve(auctionMaster.target, 1)
        let approved = await nft.getApproved(1)
        expect(approved).to.equals(auctionMaster.target)
        await nft.connect(firstAccount).approve(auctionMaster.target, 1)

        // function addAuction(uint256 _tokenId, uint256 _startPrice, uint256 _startTime, uint256 _duration)
        const startPrice = ethers.parseUnits("0.1", "ether")
        const startTime = tms + BigInt(30)
        let tx = await auctionMaster.connect(firstAccount).addAuction(1, startPrice, startTime, 300)
        const receipt = await tx.wait();
        const event = receipt.logs.map(log => {
            try {
                return auctionMaster.interface.parseLog(log)
            } catch (e) {
                return null
            }
        }).find(parsed => parsed?.name == "AuctionCreated")

        auctionId = event.args.auctionId
        console.log(`----Auction for NFT 1 created successfully, auctionId: ${auctionId}`)

        const nftOwner = await nft.ownerOf(1)
        expect(nftOwner).to.equals(auctionMaster.target)

        await expect(auctionMaster.connect(firstAccount).addAuction(1, startPrice, startTime, 300)).to.be.revertedWith("You should only auction your own token.")
    })

    it("Test get auction", async function() {
        let auctionInfo = await auctionMaster.getAuction(1)
        expect(auctionInfo.tokenId).to.equals(1)

        auctionInfo = await auctionMaster.getAuction(2)
        expect(auctionInfo.tokenId).to.equals(0)
    })

    it("Test approve NFT 2 to auction master", async function() {
        console.log(`----before auction, NFT owner approve NFT 2 to auctionMaster`)

        // 将NFT 2授权给拍卖合约
        const onwer2 = await nft.ownerOf(2)
        await nft.connect(secondAccount).approve(auctionMaster.target, 2)
        let approved = await nft.getApproved(2)
        expect(approved).to.equals(auctionMaster.target)
    })

    it("Test bid auction for NFT 2 on master", async function() {
        // addAuction(uint256 _tokenId, uint256 _startPrice, uint256 _startTime, uint256 _duration)
        console.log(`----Adding auction for NFT 2`)
        const startPrice = ethers.parseUnits("0.1", "ether")
        const startTime = await auctionMaster.getTimestamp() + BigInt(10)
        let auctionTx = await auctionMaster.connect(secondAccount).addAuction(2, startPrice, startTime, 10)
        const auctionTxReceipt = await auctionTx.wait();

        const auctionEvent = auctionTxReceipt.logs.map(log => {
            try {
                return auctionMaster.interface.parseLog(log)
            } catch (e) {
                return null
            }
        }).find(parsed => parsed?.name == "AuctionCreated")
        const auctionId = auctionEvent.args.auctionId
        console.log(`----Auction for NFT 2 created successfully, auctionId: ${auctionId}`)

        // 等待10秒，确保拍卖开始
        // await new Promise(resolve => setTimeout(resolve, 10000))
        await ethers.provider.send("evm_increaseTime", [10]);
        await ethers.provider.send("evm_mine");
        
        // 对NFT 2进行竞拍，firstAccount出价0.2 ETH，thirdAccount出价0.3 DAI
        console.log(`----First account bidding on auction with id: ${auctionId}`)
        let bidPrice = ethers.parseUnits("0.2", "ether")
        let blanceBefore = await ethers.provider.getBalance(firstAccount)
        let tx = await auctionMaster.connect(firstAccount).bid(bidPrice, firstAccount.address, auctionId, "ETH", { value: bidPrice })
        let rs = await calculateTxFee(tx);
        let blanceCurr = await ethers.provider.getBalance(firstAccount)
        expect(blanceBefore).to.equals(blanceCurr + bidPrice + rs.txFee)

        let auctionInfo = await auctionMaster.getAuction(auctionId)
        // console.log(`Highest bidder: ${auctionInfo.highestBidder}`)
        // console.log(`Highest bidder token: ${auctionInfo.highestBidTokenName}`)
        // console.log(`Highest bidder pricess: ${auctionInfo.highestBid}`)
        // console.log(`Highest bidder pricess in USD: ${auctionInfo.highestBidInUSD}`)
        expect(auctionInfo.highestBid).to.equals(bidPrice)
        expect(auctionInfo.highestBidder).to.equals(firstAccount)
        expect(auctionInfo.highestBidTokenName).to.equals("ETH")

        // thirdAccount竞拍
        console.log(`----Third account bidding on auction with id: ${auctionId}`)
        bidPrice = ethers.parseUnits("0.3", "ether")
        blanceBefore = await daiToken.balanceOf(thirdAccount)

        // thirdAccount将0.3 DAI授权给auctionMaster
        await daiToken.connect(thirdAccount).approve(auctionMaster.target, bidPrice)
        // approved = await daiToken.getApproved(thirdAccount.address)
        tx = await auctionMaster.connect(thirdAccount).bid(bidPrice, thirdAccount.address, auctionId, "DAI")
        rs = await calculateTxFee(tx);
        blanceCurr = await daiToken.balanceOf(thirdAccount)
        expect(blanceBefore).to.equals(blanceCurr + bidPrice)

        // let ethBlance2 = await ethers.provider.getBalance(thirdAccount)
        // expect(ethBlance1).to.equals(ethBlance2 + rs.txFee)
      
        auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(auctionInfo.highestBid).to.equals(bidPrice)
        expect(auctionInfo.highestBidder).to.equals(thirdAccount)
        expect(auctionInfo.highestBidTokenName).to.equals("DAI")

        // 等待拍卖时间结束
        // await new Promise(resolve => setTimeout(resolve, 10000))
        await ethers.provider.send("evm_increaseTime", [10]);
        await ethers.provider.send("evm_mine");

        // 结束拍卖
        console.log(`----Ending auction with id: ${auctionId}`)
        const nftOwnerBalanceBefore = await daiToken.balanceOf(secondAccount)

        auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(auctionInfo.creator).to.equals(secondAccount.address)
        await auctionMaster.connect(firstAccount).endAuction(auctionId)

        // 检查拍卖结束后，NFT的所有者
        nftOwner = await nft.ownerOf(auctionInfo.tokenId)
        expect(nftOwner).to.equals(auctionInfo.highestBidder)
        expect(nftOwner).to.equals(thirdAccount.address)

        // 检查拍卖结束后，NFT所有者的DAI余额
        const nftOwnerBalanceCurr = await daiToken.balanceOf(secondAccount)
        expect(nftOwnerBalanceCurr).to.equals(nftOwnerBalanceBefore + auctionInfo.highestBid)
    })
})

describe("Test slave auction", async function() {
    this.timeout(300000);

    let auctionId, secondAccountBlance
    it("Test add auction for NFT 3", async function() {

        // thirdAccount通过auctionMaster合约创建NFT 3的拍卖，起拍价0.1 ETH，拍卖时间10秒
        await nft.connect(thirdAccount).approve(auctionMaster.target, 3)
        const auctionTx = await auctionMaster.connect(thirdAccount).addAuction(3, ethers.parseUnits("0.1", "ether"), (await auctionMaster.getTimestamp()) + BigInt(10), 50)
        const auctionTxReceipt = await auctionTx.wait();
        const auctionEvent = auctionTxReceipt.logs.map(log => {
            try {
                return auctionMaster.interface.parseLog(log)
            } catch (e) {
                return null
            }
        }).find(parsed => parsed?.name == "AuctionCreated")
        auctionId = auctionEvent.args.auctionId
        console.log(`----Auction for NFT 3 created successfully, auctionId: ${auctionId}`)
    })

    it("Test firstAccount bid auction on master using 0.3 ETH", async function () {
        // 等待拍卖开始
        //await new Promise(resolve => setTimeout(resolve, 10000))
        await ethers.provider.send("evm_increaseTime", [10]);
        await ethers.provider.send("evm_mine");

        // firstAccount通过auctionMaster合约竞拍NFT 3，出价0.3 ETH
        const bidPrice = ethers.parseUnits("0.3", "ether")
        // 
        await auctionMaster.connect(firstAccount).bid(bidPrice, firstAccount.address, auctionId, "ETH", { value: bidPrice })
        console.log(`----First account bidding on auction with id: ${auctionId}`)
        // 检查拍卖信息，最高出价、最高出价者、最高出价代币名称等信息
        const auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(auctionInfo.highestBid).to.equals(bidPrice)
        expect(auctionInfo.highestBidder).to.equals(firstAccount)
        expect(auctionInfo.highestBidTokenName).to.equals("ETH")     
    })

    it("Test secondAccount bid auction on slave using 0.5 DAI on slave", async function () {
        // secondAccount通过auctionSlave合约竞拍NFT 3，出价0.5 DAI
        console.log(`----Second account bidding on auction with id: ${auctionId}`)

        const bidPrice = ethers.parseUnits("0.5", "ether")
        const daiBalanceBefore = await daiToken.balanceOf(secondAccount)
        // secondAccount将0.5 DAI授权给auctionSlave
        await daiToken.connect(secondAccount).approve(auctionSlave.target, bidPrice)
        // secondAccount通过auctionSlave进行竞拍
        await auctionSlave.connect(secondAccount).bid(auctionMaster.target, auctionId, bidPrice, daiToken, "DAI")

        // 检查竞价者DAI余额
        const daiBalanceCurr = await daiToken.balanceOf(secondAccount)
        expect(daiBalanceBefore).to.equals(daiBalanceCurr + bidPrice)
        // 检查竞价信息
        const auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(auctionInfo.highestBid).to.equals(bidPrice)
        expect(auctionInfo.highestBidder).to.equals(secondAccount)
        expect(auctionInfo.highestBidTokenName).to.equals("DAI")

        secondAccountBlance = daiBalanceBefore
    })

    it("Test firstAccount bid auction on slave using 0.2 DAI on slave", async function () {
        const firstAccountDaiBalanceBefore = ethers.formatEther(await daiToken.balanceOf(firstAccount))
        const auctionSlaveDaiBalanceBefore = ethers.formatEther(await daiToken.balanceOf(auctionSlave.target))
        const auctionMasterDaiBalanceBefore = ethers.formatEther(await daiToken.balanceOf(auctionMaster.target))

        const bidPrice = ethers.parseUnits("0.2", "ether")
        console.log(`----First account bidding on auction with id: ${auctionId}`)
        // firstAccount通过auctionSlave合约竞拍NFT 3，出价0.2 DAI
        await daiToken.connect(firstAccount).approve(auctionSlave.target, bidPrice)
        await auctionSlave.connect(firstAccount).bid(auctionMaster.target, auctionId, bidPrice, daiToken, "DAI")
        // 检查竞价者DAI余额
        const firstAccountDaiBalanceCurr = ethers.formatEther(await daiToken.balanceOf(firstAccount))
        const auctionSlaveDaiBalanceCurr = ethers.formatEther(await daiToken.balanceOf(auctionSlave.target))
        const auctionMasterDaiBalanceCurr = ethers.formatEther(await daiToken.balanceOf(auctionMaster.target))

        printLogs(`    First account DAI balance before: ${firstAccountDaiBalanceBefore}, current: ${firstAccountDaiBalanceCurr}`)
        printLogs(`    Auction slave DAI balance before: ${auctionSlaveDaiBalanceBefore}, current: ${auctionSlaveDaiBalanceCurr}`)
        printLogs(`    Auction master DAI balance before: ${auctionMasterDaiBalanceBefore}, current: ${auctionMasterDaiBalanceCurr}`)

        expect(firstAccountDaiBalanceBefore).to.equals(firstAccountDaiBalanceCurr)
    })

    it("Test fourthAccount bid auction on slave using 0.6 DAI", async function () {
        // fourthAccount通过auctionSlave合约竞拍NFT 3，出价0.6 DAI
        console.log(`----Fourth account bidding on auction with id: ${auctionId}`)
        const daiBalanceBefore = await daiToken.balanceOf(fourthAccount)
        // 竞拍
        const bidPrice = ethers.parseUnits("0.6", "ether")
        await daiToken.connect(fourthAccount).approve(auctionSlave.target, bidPrice)

        const tx = await auctionSlave.connect(fourthAccount).bid(auctionMaster.target, auctionId, bidPrice, daiToken, "DAI")
        await tx.wait()
        // 检查竞价者DAI余额
        const daiBalanceCurr = await daiToken.balanceOf(fourthAccount);
        expect(daiBalanceBefore).to.equals(daiBalanceCurr + bidPrice)
        // 检查竞价信息
        const auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(auctionInfo.highestBid).to.equals(bidPrice)
        expect(auctionInfo.highestBidder).to.equals(fourthAccount)
        expect(auctionInfo.highestBidTokenName).to.equals("DAI")
    })

    it("Test refund for secondAccount", async function () {
        console.log(`----Refunding second account for auction with id: ${auctionId}`)
        const daiBalanceCurr = await daiToken.balanceOf(secondAccount)
        expect(daiBalanceCurr).to.equals(secondAccountBlance)
    })

    it("Test firstAccount bid auction on slave using 0.2 ETH", async function () {
        const firstAccountEthBalanceBefore = ethers.formatEther(await ethers.provider.getBalance(firstAccount))
        const auctionSlaveEthBalanceBefore = ethers.formatEther(await ethers.provider.getBalance(auctionSlave.target))
        const auctionMasterEthBalanceBefore = ethers.formatEther(await ethers.provider.getBalance(auctionMaster.target))
        const bidPrice = ethers.parseUnits("0.2", "ether")
        console.log(`----First account bidding on auction with id: ${auctionId}`)
        await auctionSlave.connect(firstAccount).bid(auctionMaster.target, auctionId, bidPrice, ethers.ZeroAddress, "ETH", { value: bidPrice })
        // 检查竞价者ETH余额
        const firstAccountEthBalanceCurr = ethers.formatEther(await ethers.provider.getBalance(firstAccount))
        const auctionSlaveEthBalanceCurr = ethers.formatEther(await ethers.provider.getBalance(auctionSlave.target))
        const auctionMasterEthBalanceCurr = ethers.formatEther(await ethers.provider.getBalance(auctionMaster.target))

        expect(auctionSlaveEthBalanceBefore).to.equals(auctionSlaveEthBalanceCurr)
        expect(auctionMasterEthBalanceBefore).to.equals(auctionMasterEthBalanceCurr)

        printLogs(`    First account ETH balance before: ${firstAccountEthBalanceBefore}, current: ${firstAccountEthBalanceCurr}`)
        printLogs(`    Auction slave ETH balance before: ${auctionSlaveEthBalanceBefore}, current: ${auctionSlaveEthBalanceCurr}`)
        printLogs(`    Auction master ETH balance before: ${auctionMasterEthBalanceBefore}, current: ${auctionMasterEthBalanceCurr}`)
    })

    it("Test end auction for NFT 3", async function () {
        await ethers.provider.send("evm_increaseTime", [50]);
        await ethers.provider.send("evm_mine");
        console.log(`----Ending auction with id: ${auctionId}`)

        const nftOwnerBalanceBefore = await daiToken.balanceOf(thirdAccount)
        const daiBalanceBefore = await daiToken.balanceOf(auctionMaster)
        await auctionMaster.endAuction(auctionId);
        const daiBalanceCurr = await daiToken.balanceOf(auctionMaster)

        const auctionInfo = await auctionMaster.getAuction(auctionId)
        expect(daiBalanceBefore).to.equals(daiBalanceCurr + auctionInfo.highestBid)

        // 检查拍卖结束后，NFT的所有者
        const nftOwner = await nft.ownerOf(auctionInfo.tokenId)
        expect(nftOwner).to.equals(auctionInfo.highestBidder)
        expect(nftOwner).to.equals(fourthAccount)

        // 检查拍卖结束后，NFT所有者的DAI余额
        const nftOwnerBalanceCurr = await daiToken.balanceOf(thirdAccount)
        expect(nftOwnerBalanceCurr).to.equals(nftOwnerBalanceBefore + auctionInfo.highestBid)
    })
})
