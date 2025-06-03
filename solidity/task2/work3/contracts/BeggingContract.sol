// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BeggingContract {

    mapping(address user => uint256 amount) donateAmounts;
    mapping(address user => string message) donateMessage;

    DonateRank[3] private donateRanks;
    uint256 private donateStartTime;
    uint256 private donatePeriod;
    address private owner;

    modifier ownerable {
        require(msg.sender == owner, "The caller should be the conctract owner.");
        _;
    }

    event Donation(address indexed donateUser, string message);

    struct DonateRank {
        address donateUser;
        uint256 donateAmount;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable { }

    fallback() external payable { }

    function setDonateTime(uint256 startTime, uint256 period) public ownerable {
        require(msg.sender == owner, "The caller should be the conctract owner.");
        // require(startTime >= block.timestamp && (period > 0), "Illegal parameters for setDonateTime");
        donateStartTime = startTime;
        donatePeriod = period;
    }

    function getDonteTime() public view returns (uint256 startTime, uint256 endTime) {
        return (donateStartTime, donatePeriod);
    }

    function _setRanks(address user, uint256 amount) internal {
        if(amount > donateRanks[0].donateAmount) {
            _updateRank(donateRanks[2], donateRanks[1].donateUser, donateRanks[1].donateAmount);
            _updateRank(donateRanks[1], donateRanks[0].donateUser, donateRanks[0].donateAmount);
            _updateRank(donateRanks[0], user, amount);
        } else if(amount > donateRanks[1].donateAmount) {
            _updateRank(donateRanks[2], donateRanks[1].donateUser, donateRanks[1].donateAmount);
            _updateRank(donateRanks[1], user, amount);
        } else if(amount > donateRanks[2].donateAmount) {
            _updateRank(donateRanks[2], user, amount);
        }
    }

    function _updateRank(DonateRank storage rank, address user, uint256 amount) internal {
        rank.donateAmount = amount;
        rank.donateUser = user;
    }

    function isValidDonateTime(uint256 startTime, uint256 period) internal view returns (bool) {
        require(period > 0, "The period should be greater than zero.");
        if (block.timestamp < startTime) {
            return false;
        }

        if(block.timestamp > startTime + period) {
            return false;
        }

        return true;
    }

    function getTimestamp() public view returns (uint256 timestamp) {
        return block.timestamp;
    }

    function donate(string memory message) public payable {
        require(msg.value > 0, "The donated amount must be greater than zero.");
        require(isValidDonateTime(donateStartTime, donatePeriod), "It is not valid donate time.");
        donateAmounts[msg.sender] += msg.value;
        if(bytes(message).length > 0) {
            donateMessage[msg.sender] = message;
        }

        _setRanks(msg.sender, donateAmounts[msg.sender]);

        emit Donation(msg.sender, message);
    }

    function getDonatedAmount(address user) public view returns (uint256) {
         return donateAmounts[user];
    }

    function withdraw() public ownerable{
        payable(owner).transfer(address(this).balance);
    }

    function getDonateRanks() public view returns (address[3] memory) {
        return [donateRanks[0].donateUser, donateRanks[1].donateUser, donateRanks[2].donateUser];
    }

}