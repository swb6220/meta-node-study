// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";

import {MockCCIPRouter} from "@chainlink/contracts-ccip/contracts/test/mocks/MockRouter.sol";

contract AuctionSlave is CCIPReceiver {
    //address public auctionMaster;
    address public router;
    address public linkToken;

    uint64 public constant DEST_CHAIN_SELECTOR = 16015286601757825753;

    error NotEnoughBalance(
        uint256 currentBalance, 
        uint256 calculatedFees
    ); // Used to make sure contract has enough balance to cover the fees.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes text, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    event Refunded(
        bytes32 indexed messageId, 
        uint64 indexed chainSelector, 
        address senderAddr, 
        address _to, 
        uint256 tokenAmount, 
        string tokenName
    );

    struct AuctionData {
        address bidder;
        uint256 auctionId;
        string tokenName;
    }

    constructor(address _router, address _link) CCIPReceiver(_router) {
        //auctionMaster = _auctionMaster;
        router =_router;
        linkToken = _link;
    }

    function isEquals(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    // function getLinkTokenBalance(address addr) public view returns (balance) {
    //     return LinkTokenInterface(_link).balanceOf(addr)
    // }

    /**
     * @notice 跨链竞拍
     * @param auctionId The ID of the auction to bid on.
     * @param amount The amount of tokens to bid.
     * @param tokenAddr The address of the token being used for the bid.
     * @param tokenName The name of the token being used for the bid.
     * @return messageId The ID of the message sent to the auction master.
     */
    function bid(address auctionMaster, uint256 auctionId, uint256 amount, address tokenAddr, string memory tokenName) public payable returns (bytes32 messageId) {
        require(bytes(tokenName).length > 0, "Token name should not be empty.");
        if(isEquals(tokenName, "ETH")) {
            require(msg.value == amount, "Amount should match the value sent with the transaction.");
            tokenAddr = address(0); // Set tokenAddr to zero address for ETH
        } else {
            IERC20(tokenAddr).approve(auctionMaster, amount);
        }

        return sendMessage(DEST_CHAIN_SELECTOR, auctionMaster, auctionId, tokenName, amount, tokenAddr, msg.sender);
    }

    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        uint256 auctionId,
        string memory tokenName,
        uint256 tokenAmount,
        address tokenAddr,
        address bidder
    ) internal returns (bytes32 messageId) {
        Client.EVMTokenAmount[] memory tokenAmounts;
        if(tokenAddr == address(0)) {
            tokenAmounts = new Client.EVMTokenAmount[](0);
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: tokenAddr,
                amount: tokenAmount
            });
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(auctionId, bidder, tokenAmount, tokenName),
            tokenAmounts: tokenAmounts, 
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: linkToken
        });

        // Get the fee required to send the message
        uint256 fees = IRouterClient(router).getFee(
            destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > LinkTokenInterface(linkToken).balanceOf(address(this)))
            revert NotEnoughBalance(LinkTokenInterface(linkToken).balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        LinkTokenInterface(linkToken).approve(router, fees);

        if(tokenAmounts.length > 0) {
            IERC20(tokenAddr).transferFrom(bidder, address(this), tokenAmount);
            IERC20(tokenAddr).approve(router, tokenAmount);
        }

        // Send the message through the router and store the returned message ID
        messageId = IRouterClient(router).ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        // emit MessageSent(
        //     messageId,
        //     destinationChainSelector,
        //     receiver,
        //     text,
        //     linkToken,
        //     fees
        // );

        return messageId;
    }

    // 接收主链的退款
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        bytes32 messageId = any2EvmMessage.messageId;
        uint64 chainSelector = any2EvmMessage.sourceChainSelector;
        (address _to, uint256 _amount, string memory _tokenName) = abi.decode(any2EvmMessage.data, (address, uint256, string));
        address senderAddr = abi.decode(any2EvmMessage.sender, (address));

        Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;
        if(tokenAmounts.length == 0) {
           payable(_to).transfer(_amount);
        } else {
            uint256 tokenAmount = tokenAmounts[0].amount;
            address tokenAddr = tokenAmounts[0].token;  
            IERC20(tokenAddr).transfer(_to, tokenAmount);
        }

        emit Refunded(messageId, chainSelector, senderAddr, _to, _amount, _tokenName);
    }
}