// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;

    // Declared two variables
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    // The owner of the market place gets this amount
    uint256 listingPrice = 0.025 ether;

    // Owner
    address payable owner;

    // List of MarketItem fetched using the Item Id
    mapping(uint => MarketItem) private idToMarketItem;

    // Type of a data type with these properties
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    // Event that can be triggered during code
    event MarketItemCreated (
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );


    // The one deploying the contact is the owner and therefore gets the amount
    constructor() ERC721("Metaverse Tokens", "METT") {
        owner = payable(msg.sender);
    }

    function updateListingPrice (uint _listingPrice) public payable {
        require(owner == msg.sender, " Only marketplace owner can update the listing price");

        listingPrice = _listingPrice;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        
        // Incrementing the total tokenIds
        _tokenIds.increment();

        // Value of the recent tokenId (NFT_ID)
        uint256 newTokenId = _tokenIds.current();

        // Create or mint the UNIQUE token (NFT) with the tokenId (NFT_ID) for the SENDER
        _mint(msg.sender, newTokenId);

        // Create a unique identifier for the token (NFT) created
        _setTokenURI(newTokenId, tokenURI);

        // List the token (NFT) to the marketplace
        createMarketItem(newTokenId, price);

        return newTokenId;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {

        // The price of the NFT should be greater than 0
        require(price > 0, "Price should be greater than 0");

        // The price paying to market place should be equal to the listing price as decided by the contract owner 
        require(msg.value == listingPrice , "Price should be equal to listingPrice");

        // Creating an entry for the specific tokenId (NFT_ID), owner is "this" contract
        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender), // seller
            payable(address(this)), // owner
            price,
            false // sold
        );

        // initiate the transfer from the sender's address to "this" contract
        _transfer(msg.sender, address(this), tokenId);

        // Firing the event
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false);
    }

    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(idToMarketItem[tokenId].owner == msg.sender, "Only item owner can perform this operation");
        require(msg.value == listingPrice , "Price should be equal to listingPrice");

        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));

        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    function createMarketSale(uint tokenId) public payable {

        // extract the price of the token (NFT) using tokenId
        uint price = idToMarketItem[tokenId].price;

        // msg is an object (transaction) which has the property value
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        // the main functionality. Owner --> person who is buying, seller --> contract 
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].owner = payable(msg.sender);

        // address of random is 0
        idToMarketItem[tokenId].seller = payable(address(0)); 

        // number of items sold increased
        _itemsSold.increment();

        // this initiates transfer of tokenId from contract to the buyer (msg.sender)
        _transfer(address(this), msg.sender, tokenId);

        // give the listing price to the contract owner (address)
        payable(owner).transfer(listingPrice);

        // give the price (msg.value) to the seller with tokenId
        payable(idToMarketItem[tokenId].seller).transfer(msg.value);

    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        // we need  to get all the items that are unsold. Therefore, we loop over all the nfts to fetch the NFTs that have 0 address (marketplace)
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint currentId = i+ 1;

                MarketItem storage currentItem = idToMarketItem[currentId];

                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i+1].owner == msg.sender) {
                itemCount += 1;
            }    
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint currentId = i+ 1;

                MarketItem storage currentItem = idToMarketItem[currentId];

                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        return items;
    }

    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i+1].seller == msg.sender) {
                itemCount += 1;
            }    
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint currentId = i+ 1;

                MarketItem storage currentItem = idToMarketItem[currentId];

                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        return items;
    }

}



