// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyErc721Nft is ERC721 {

    uint256 private tokenIdNext_;

    constructor() ERC721("My NFT Token", "MyNFT") {
        // tokenId从1开始
        tokenIdNext_ = 1;
    }    

    function _baseURI() internal pure override returns(string memory) {
        return "https://ipfs.io/ipfs/QmTTQB6wYt2tJbvg54ch5TTetbUQnus8TYafnfxXa1wMhD/";
    }

    function mintNFT() public returns (uint256 tokenId) {
        tokenId = tokenIdNext_;
        _safeMint(msg.sender, tokenId);
        tokenIdNext_ ++;
        return tokenId;
    }

    function tokenIdNext() public view returns (uint256) {
        return tokenIdNext_;
    }
}