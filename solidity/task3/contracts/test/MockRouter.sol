// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";

contract MockRouter {
    // Mock implementation of the IRouterClient interface
    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory text,
        address feeToken,
        uint256 fees
    ) external pure returns (bytes32) {
        // Mock logic for sending a message
        return keccak256(abi.encode(destinationChainSelector, receiver, text, feeToken, fees));
    }

    function getChainSelector() external pure returns (uint64) {
        return 0; // Mock chain selector
    }
}