// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.8.0/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";

contract RealEstate is ERC1155, Ownable {
    address public admin;
    uint256 public constant MIN_FEE = 0.05 ether;
    
    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    function currTokenId() public view returns(uint256) {
        return tokenId.current();
    }

    function incTokenId() public {
        tokenId.increment();
    }

    function decTokenId() public {
        tokenId.decrement();
    }

    constructor() ERC1155("") {
        admin = msg.sender;
        incTokenId();
    }

    struct Account {
        address walletAddress;
        string name;
    }

    mapping (address => Account) public accDetails;
    mapping (address => bool) public accountExists;
    mapping (address => Token[]) public ownerTokenDetails;

    struct Token {
        uint256 tokenId;
        string landDetails;
        uint256 maxSupply;
        uint256 price;
    }

    Token[] public tokens;
    mapping (uint256 => Token) public tokenInfo;

    function createToken(uint256 _maxSupply, uint256 _price, string memory _landDetails, string memory _name) public payable {
        require(msg.value == MIN_FEE, "Please pay the transaction fee");

        if (!accountExists[msg.sender]) {
            Account memory newAccount = Account(msg.sender, _name);
            accDetails[msg.sender] = newAccount;
        }

        uint256 currId = currTokenId();

        Token memory newToken = Token(currId, _landDetails, _maxSupply, _price);
        tokens.push(newToken);
        tokenInfo[currId] = newToken;
        ownerTokenDetails[msg.sender].push(newToken);
        
        incTokenId();

        _mint(msg.sender, currId, _maxSupply, "");
    }

    function transfer(address _to, uint256 _tokenId, uint256 _amount) public {
        _safeTransferFrom(msg.sender, _to, _tokenId, _amount, "");
    }

    function withdraw() payable public onlyOwner {
        require(address(this).balance >= 0, "Balance is 0");

        (bool sent, ) = payable(admin).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }
}