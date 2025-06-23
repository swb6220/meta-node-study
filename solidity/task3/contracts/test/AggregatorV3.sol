// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AggregatorV3 is AggregatorV3Interface {
    int256 private _latestAnswer;

    constructor(int256 initialAnswer) {
        _latestAnswer = initialAnswer;
    }

    function decimals() public pure returns (uint8) {
        return 18; // Example: returning 18 decimals
    }

    function description() public pure returns (string memory) {
        return "Mock AggregatorV3"; // Example: returning a mock description
    }

    function version() public pure returns (uint256) {
        return 1; // Example: returning version 1
    }

    function getRoundData(
        uint80 _roundId
    ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        require(_roundId == 0, "Only round 0 is supported in this mock");
        return (0, _latestAnswer, 0, 0, 0);
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, _latestAnswer, 0, 0, 0);
    }

    function setAnswer(int256 answer) external {
        _latestAnswer = answer;
    }
}
