// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MyERC721NFT {
    string private _name;
    string private _symbol;
    uint256 private  _decimals;
    address private immutable creator;
    uint256 private tokenIds;

    // user token mapping
    mapping(uint256 tokenId => address user) private userTokens;
    //mapping(address user => uint256 tokenId) private userTokens;
    // token URIs
    mapping(uint256 tokenId => string tokenURI) private tokenURIs;
    // 用户所拥有的NFT数量
    mapping(address user => uint256 balance) private userBalances;
    // 被授权给其他用户的token和被授权用户
    mapping( uint256 tokenId => address operator) operatorTokenIds;
    // 用户是否给其他用户授权了所有NFT
    mapping(address from => mapping(address to => bool isApproved)) private isApproved;
 
    // token转移event
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // token授权event
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);    

    constructor(string memory name_, string memory symbol_) { // 构造函数初始化名称和符号
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
        creator = msg.sender; // 设置创作者地址
        tokenIds = 0;
    }

    // 函数调用者给自己铸造 NFT
    function mintNFT(address recipient, string memory tokenURI_) public {
        // 验证是否是合约的创建者
        require(msg.sender == recipient, "Not the owner!");
        require(bytes(tokenURI_).length > 0, "The token URI can not be empty.");

        userTokens[tokenIds] = recipient;
        tokenURIs[tokenIds] = tokenURI_;
        userBalances[recipient] ++;

        emit Transfer(address(0), recipient, tokenIds);

        tokenIds ++;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function baseURI() internal pure returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(bytes(tokenURIs[tokenId]).length > 0, "The token URI can not be empty.");
        return string.concat(baseURI(), tokenURIs[tokenId]);
    }

    // 用户owner的token个数查询
    function balanceOf(address owner) external view returns (uint256 balance) {
        return userBalances[owner];
    }

    // tokenId的token的拥有者查询
    function ownerOf(uint256 tokenId) external view returns (address owner) {
        require(bytes(tokenURIs[tokenId]).length > 0, "The token URI not exest.");
        return userTokens[tokenId];
    }

    // 转移token
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
         _transfer(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId, "");
    }

    // 转移token
    function transferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId, "");
    }

    /*
     * 将tokenId从地址from转移到to
     * from和to不能为0地址
     * 调用者(msg.sender)必须有权限：
     *     1、调用者为token的owner
     *     2、调用者被授权
     *     2.1 tokenId被授权给to
     *     2.2 token的owner授权其全部token给to
     * 如果to是个合约地址，必须实现IERC721Receiver-onERC721Received接口
     * 
     */
    function _transfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        require(from != address(0) && to != address(0), "From and To cannot be zero address.");
        bool isTokenOwner = msg.sender == userTokens[tokenId] && msg.sender == from;
        bool isTokenApproved = isApproved[userTokens[tokenId]][msg.sender] || msg.sender == operatorTokenIds[tokenId]; 
        // 调用者是token的owner，或者被授权者
        require(isTokenOwner || isTokenApproved, "caller should be owner or approved of the token.");
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(to, from, tokenId, data) returns (bytes4 result) {
                require(result == IERC721Receiver.onERC721Received.selector, "When transfer NFT to a contract address, the EIP712 compliant contract should implement this interface");
            } catch {
             revert();
            }
        }
        userTokens[tokenId] = to;
        userBalances[from] --;
        userBalances[to] ++;
        emit Transfer(from, to, tokenId);
    }

    // 授权token给to
    function approve(address to, uint256 tokenId) external {
        require(msg.sender != to, "Can not set approve to self.");
        require(userTokens[tokenId] == msg.sender, "caller is not the owner of this token");
        operatorTokenIds[tokenId] = to;
        emit Approval(msg.sender, to, tokenId);
    }

    // 调用者将其所有token授权/撤销授权给operator
    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator, "Can not set approve to self.");
        isApproved[msg.sender][operator] = approved;
         emit ApprovalForAll(msg.sender, operator, approved);
    }

    // 查询tokenId的被授权者
    function getApproved(uint256 tokenId) external view returns (address operator) {
        operator = operatorTokenIds[tokenId];
    }

    // 查询用户owner是否将其所有NFT授权给用户operator
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return isApproved[owner][operator];
    }
}