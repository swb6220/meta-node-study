// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyErc721Nft.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AuctionMaster is CCIPReceiver {
    //using SafeERC20 for IERC20;

    address public owner;
    uint256 private auctionIdNext;
    MyErc721Nft private nft;
    address private linkToken;
    address private router;

    string private constant TOKEN_ETH_NAME = "ETH"; 

    mapping(uint256 auctionId => Auction auctions) private auctions;
    mapping(uint256 tokenId => uint256 auctionId) public nftInAuction;

    mapping(string tokenName => address tokenAddress) public tokenAddresses;
    mapping(string priceFeedName => address priceFeedAddress) public priceFeeds;
    mapping(uint64 chainSelector => address auctionSlaveAddress) public auctionSlaves;

    mapping(uint64 chainSelector => address tokenAddress) private allowedTokens;
    
    // Used to make sure contract has enough balance to cover the fees.
    error NotEnoughBalance(
        uint256 currentBalance, 
        uint256 calculatedFees
    ); 

    modifier onlyOwner() {
        require(owner == msg.sender, "You are not owner of AuctionMaster.");
        _;
    }

    modifier onlyAllowedTokens(uint64 chainSlector) {
        require(allowedTokens[chainSlector] != address(0), "The token is not allowed.");
        _;
    }

    modifier onlyAllowedChain(uint64 chainSelector) {
        require(auctionSlaves[chainSelector] != address(0), "The slave chain is not allowed.");
        _;        
    }

    struct Auction {
        address creator;
        uint256 auctionId;
        uint256 tokenId;
        uint256 startPrice;
        uint256 startTime;
        uint256 duration;
        // 最高出价信息
        address highestBidder;
        uint256 highestBid;
        uint256 highestBidInUSD;
        string highestBidTokenName;
        address highestBidTokenAddr;
        uint64 chainSelector; // 竞拍所在的链, 0代表主链
        // 是否还在竞拍中
        bool isActive;
    }

    event Bid(uint256 auctionId, address bidder, uint256 amount, address _tokenAddress);

    event AuctionCreated(uint256 tokenId, uint256 auctionId, uint256 startTime, uint256 duration, uint256 startPrice);

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        address bidder,
        uint256 auctionId
    );

    /*
     * 通过工厂合约创建MyAuction
     * 
     */
    constructor(address _nftAddress, address _router, address _link) CCIPReceiver(_router) {
        owner = msg.sender;
        nft = MyErc721Nft(_nftAddress);
        linkToken = _link;
        router = _router;

        auctionIdNext = 1;
    }
   
    /* ============================== public functions ======================================== */

    // for test
    function getTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function blanceOf() public view returns (uint256) {
        return address(this).balance;
    }

    function getLinkTokenBalance(address addr) public view returns (uint256) {
        return LinkTokenInterface(linkToken).balanceOf(addr);
    }

    /*
     * 设置跨链竞拍合约地址
     * 1. 只有合约创建者（工厂合约）有权限
     */
    function setAuctionSlaves(uint64 _chainSelector, address _slaveAddress) public onlyOwner {
        require(_slaveAddress != address(0), "The slave auction address cannot be zero.");
        auctionSlaves[_chainSelector] = _slaveAddress;
    }

    function getAuctionSlave(uint64 _chainSelector) public view returns (address) {
        return auctionSlaves[_chainSelector];
    }

    /*
     * 根据token name获取price feed地址
     * 1. tokenName必须存在
     */
    function getPriceFeedAddress(string memory _tokenName) public view returns(address) {
        require(bytes(_tokenName).length > 0, "The price feed name cannot be empty.");
        return priceFeeds[_tokenName];
    }

    /*
     * 根据token name获取token地址
     * 1. tokenName必须存在
     */
    function getTokenAddress(string memory _tokenName) public view returns(address) {
        require(bytes(_tokenName).length > 0, "The price feed name cannot be empty.");
        return tokenAddresses[_tokenName];
    }

    /*
     * 注册支付token地址，及其相对USD的price feed地址
     *
     * 1. 只有合约创建者（工厂合约）有权限
     * 2. tokenName必须存在
     * 3. priceFeedAddress必须存在
     */
    function registerTokenAndPriceFeed(string memory _tokenName, address _priceFeedAddress, address _tokenAddress) public onlyOwner {
        require(bytes(_tokenName).length > 0, "The token name cannot be empty.");
        require(_priceFeedAddress != address(0), "The price feed address cannot be zero.");
        require(_tokenAddress != address(0), "The token address cannot be zero.");

        tokenAddresses[_tokenName] = _tokenAddress;
        priceFeeds[_tokenName] = _priceFeedAddress;
    }

    /*
     * 添加竞拍，token被添加竞拍之后，其所有权被转移给竞拍合约
     *
     * 1. 只有token拥有者才能添加竞拍
     * 2. token必须存在
     * 3. 起拍时间必须在当前时间之后
     * 4. 拍卖持续时间必须大于等于10s（方便测试）
     */
    function addAuction(uint256 _tokenId, uint256 _startPrice, uint256 _startTime, uint256 _duration) public returns (uint256 _auctionId){
        require(nft.ownerOf(_tokenId) == msg.sender, "You should only auction your own token.");
        require(nft.ownerOf(_tokenId) != address(0), "The owner of this token not exist.");
        require(_startTime > block.timestamp, "Invalid auction start time.");
        require(_duration >= 10, "Auction duration time should be greater than 1 min.");
        require(_startPrice > 0, "The start price should be greater than zero.");
        require(nftInAuction[_tokenId] == 0, "This token is already in auction.");

        Auction memory _auction = Auction(msg.sender, auctionIdNext, _tokenId
            , _startPrice, _startTime, _duration, address(0), uint256(0), uint256(0), "", address(0), 0, true);

        auctionIdNext ++;

        auctions[_auction.auctionId] = _auction;
        nftInAuction[_tokenId] = _auction.auctionId;

        nft.transferFrom(nft.ownerOf(_tokenId), address(this), _tokenId);

        emit AuctionCreated(_tokenId, _auction.auctionId, _startTime, _duration, _startPrice);

        return _auction.auctionId;
    }

    /*
     * 竞拍
     * 1. 可以使用ETH或者ERC20代币进行竞拍
     * 2. 根据_tokenName确定代币类型，_tokenName与token地址的映射关系在registerTokenAndPriceFeed中设置
     * 3. 如果是ETH竞拍，则token数量为msg.value而不是_tokenAmount
     */
    function bid(uint256 _tokenAmount, address _bidder, uint256 _auctionId, string memory _tokenName) public payable  {
        uint256 _amount = _tokenAmount;
        if (_isEquals(_tokenName, TOKEN_ETH_NAME)) {
            _amount = msg.value;
            require(_amount > 0, "The bid amount must be greater than zero.");
        }
        _bid(_amount,  _bidder, _auctionId, _tokenName, 0);
    }

    /* 结束拍卖
     * 1. 只有合约创建者（工厂合约）有权限
     * 2. 不能结束已经结束的拍卖
     * 3. 不能结束不存在的拍卖
     * 4. 不能结束还在竞拍期的拍卖
     */
    function endAuction(uint256 _auctionId) public onlyOwner {
        Auction memory _auction = auctions[_auctionId];
        require(_auction.creator != address(0), "This auction not exist.");
        require(_auction.isActive, "The expired auction cannot be expired again.");
        require(block.timestamp >= _auction.startTime + _auction.duration, "The aution cannot been ended before the expired time.");

        _auction.isActive = false;
        auctions[_auctionId] = _auction;

        if(_auction.highestBid == uint256(0)) {
            return;
        }

        // 1. 支付拍卖金额给NFT拥有者
        if(_isEquals(_auction.highestBidTokenName, TOKEN_ETH_NAME)) {
            payable(_auction.creator).transfer(_auction.highestBid);
        } else {
            IERC20(_auction.highestBidTokenAddr).transfer(_auction.creator, _auction.highestBid);
        }

        // 2. 转移NFT所有权给最高出价者
        nft.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);
    }

    /* ============================== internal functions ======================================== */

    function _isEquals(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    /*
     * 使用Price Feed将代币价格转换为USD
     */
    function _convertPrice(uint256 _amount, string memory _tokenName) internal view returns (uint256) {
        require(_amount > 0, "The bid amount must be greater than zero.");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[_tokenName]); 
        (, int256 _price, , , ) = priceFeed.latestRoundData();
        uint8 _decimals = priceFeed.decimals();

        return _amount * uint256(_price) / (10 ** _decimals);
    }

    function getAuction(uint256 _auctionId) public view returns(Auction memory){
        return auctions[_auctionId];
    }

    // 从其他链接收消息，进行竞拍
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override onlyAllowedChain(any2EvmMessage.sourceChainSelector) {
        bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
        uint64 chainSelector = any2EvmMessage.sourceChainSelector;
        (uint256 auctionId, address bidder, uint256 tokenAmount, string memory tokenName) =  abi.decode(any2EvmMessage.data, (uint256, address, uint256, string));
        address senderAddr = abi.decode(any2EvmMessage.sender, (address));
        Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;
        address tokenAddr;

        if(tokenAmounts.length > 0) {    // ERC20
            tokenAddr = tokenAmounts[0].token;
            tokenAmount = tokenAmounts[0].amount;
            require(tokenAddr == tokenAddresses[tokenName], "The token address is not correct.");
        }

        emit MessageReceived(
            messageId,
            chainSelector,
            senderAddr,
            bidder,
            auctionId
        );

        _bid(tokenAmount, bidder, auctionId, tokenName, chainSelector);
    }

     /*
     * 竞拍
     * 1. 竞拍必须已经存在
     * 2. 竞拍必须尚未结束
     * 3. 竞拍必须已经开始
     * 4. 竞拍必须还未结束
     * 5. 竞拍价格必须高于等于起拍价
     */
    function _bid(uint256 _tokenAmount, address _bidder, uint256 _auctionId, string memory _tokenName, uint64 _chainSelector) internal {
        Auction memory _auction = auctions[_auctionId];
        require(_bidder != address(0), "The bidder address cannot be zero.");
        require(_auction.creator != address(0), "This auction not exist.");
        require(_auction.isActive, "The auction has ended.");
        require(block.timestamp >= _auction.startTime, "The auction not started.");
        require(block.timestamp <= _auction.startTime + _auction.duration, "The auction duration has expired.");
        require(_tokenAmount > _auction.startPrice, "The auction bidding price should be higher than start bid price.");
        require(priceFeeds[_tokenName] != address(0), "Please set the price feed address first.");

        uint256 _amountInUSD = _convertPrice(_tokenAmount, _tokenName);

        // 出价高于最高价
        if (_amountInUSD > _auction.highestBidInUSD) {
            if (_auction.highestBid > 0){
                _refund(_auction.highestBidder, _auction.highestBid, _auction.highestBidTokenAddr, _auction.highestBidTokenName, _auction.chainSelector);
            }

            // 更新竞拍信息
            _auction.highestBid = _tokenAmount;
            _auction.highestBidTokenAddr = tokenAddresses[_tokenName];
            _auction.highestBidTokenName = _tokenName;
            _auction.highestBidInUSD = _amountInUSD;
            _auction.highestBidder = _bidder;
            _auction.chainSelector = _chainSelector;
            auctions[_auctionId] = _auction;

            // 将token转给合约
            if(_chainSelector == 0  && !_isEquals(_tokenName, TOKEN_ETH_NAME)) {
                IERC20(tokenAddresses[_tokenName]).transferFrom(_bidder, address(this), _tokenAmount);
            }

            emit Bid(_auctionId, _bidder, _tokenAmount, tokenAddresses[_tokenName]);
        } else if(_chainSelector != 0) {    // 出价低于最高价，且出价是跨链的
            _refund(_bidder, _tokenAmount, tokenAddresses[_tokenName], _tokenName, _chainSelector);
        }
    }

    /*
     * 退款
     * 1. 主链上退款，即_chainSelector为0
     * 2. 跨链退款，即_chainSelector不为0
     */
    function _refund(address _to, uint256 _amount, address _tokenAddr, string memory _tokenName, uint64 _chainSelector) internal returns (bytes32 messageId) {
        // 主链上退款
        if(_chainSelector == 0) {
            // 退款ETH
            if(_isEquals(_tokenName, TOKEN_ETH_NAME)) {
                payable(_to).transfer(_amount);
            } else { // 退款ERC20代币
                require(_tokenAddr != address(0), "The token address cannot be zero.");
                IERC20(_tokenAddr).transfer(_to, _amount);
            }
        } else { // 跨链退款
            require(auctionSlaves[_chainSelector] != address(0), "The auction slave address not exist.");

            address auctionSlaveAddr = auctionSlaves[_chainSelector];
            Client.EVMTokenAmount[] memory _tokenAmounts;
            
            // 构建message
            if(_isEquals(_tokenName, TOKEN_ETH_NAME)) {
                _tokenAmounts = new Client.EVMTokenAmount[](0);
            } else {
                _tokenAmounts = new Client.EVMTokenAmount[](1);
                _tokenAmounts[0] = Client.EVMTokenAmount({
                    token: _tokenAddr,
                    amount: _amount
                });
            }

            Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(address(auctionSlaveAddr)), // 从链地址
                data: abi.encode(_to, _amount, _tokenName), // 从链用户
                tokenAmounts: _tokenAmounts, 
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({
                        gasLimit: 30_000, 
                        allowOutOfOrderExecution: true
                    })
                ),

                feeToken: linkToken
            });

            // 计算CCIP费用
            uint256 fees = IRouterClient(router).getFee(_chainSelector, evm2AnyMessage);
            uint256 totalFees = fees + (fees * 20) / 100;

            // 检查余额
            if (LinkTokenInterface(linkToken).balanceOf(address(this)) < totalFees)
                revert NotEnoughBalance(LinkTokenInterface(linkToken).balanceOf(address(this)), totalFees);

            // 将费用金额授权给router
            LinkTokenInterface(linkToken).approve(router, totalFees);

            if(!_isEquals(_tokenName, TOKEN_ETH_NAME)) {
                // 授权给router
                IERC20(_tokenAddr).approve(router, _amount);
            }
            
            messageId = IRouterClient(router).ccipSend(_chainSelector, evm2AnyMessage);
        }
    }

}