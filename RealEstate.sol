// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.8.0/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";

contract RealEstate is ERC1155, Ownable {
    address public admin;
    uint256 public constant MIN_FEE = 0.05 ether;

    fallback() external payable {}
    receive() external payable {}

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;
    Counters.Counter private offerId;

    function currTokenId() public view returns(uint256) {
        return tokenId.current();
    }

    function incTokenId() public {
        tokenId.increment();
    }

    function decTokenId() public {
        tokenId.decrement();
    }

    function currOfferId() public view returns(uint256) {
        return offerId.current();
    }

    function incOfferId() public {
        offerId.increment();
    }

    function decOfferId() public {
        offerId.decrement();
    }

    constructor() ERC1155("") {
        admin = msg.sender;
        incTokenId();
        incOfferId();
    }

    event NewTokenCreated(uint256 indexed tokenId, address owner, uint256 maxSupply, uint256 price, string landDetails);
    event OfferCreated(uint256 indexed offerId, uint256 tokenId, address creator, uint256 quantity);
    event TokenTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 quantity);
    event OfferCanceled(uint256 offerId);
    event OfferReset(uint256 offerId);

    struct Account {
        address walletAddress;
        string name;
    }
    Account[] public accounts;

    mapping (address => Account) public accDetails;
    mapping (address => bool) public accountExists;
    mapping (address => Token[]) public ownerTokenDetails;

    mapping (address => mapping(uint256 => uint256)) public accTokenBalance;

    struct Token {
        uint256 tokenId;
        string metaData;
        uint256 maxSupply;
        uint256 price;
    }

    Token[] public tokens;
    mapping (uint256 => Token) public tokenInfo;

    function createToken(uint256 _maxSupply, uint256 _price, string memory _landDetails, string memory _name) public payable {
        require(msg.value == MIN_FEE, "Please pay the transaction fee");

        if (!accountExists[msg.sender]) {
            accountExists[msg.sender] = true;
            Account memory newAccount = Account(msg.sender, _name);
            accDetails[msg.sender] = newAccount;
            accounts.push(newAccount);
        }

        uint256 currId = currTokenId();

        Token memory newToken = Token(currId, _landDetails, _maxSupply, _price);
        // added to array
        tokens.push(newToken);
        // added to mapping
        tokenInfo[currId] = newToken;
        ownerTokenDetails[msg.sender].push(newToken);
        
        _mint(msg.sender, currId, _maxSupply, "");

        // event NewTokenCreated(uint256 indexed tokenId, address owner, uint256 maxSupply, uint256 price, string landDetails);
        emit NewTokenCreated(currId, msg.sender, _maxSupply, _price, _landDetails);

        incTokenId();


    }

    function transfer(address _from, address _to, uint256 _tokenId, uint256 _amount) public {
        _safeTransferFrom(_from, _to, _tokenId, _amount, "");
    }

    function buyToken(uint256 _offerId, uint256 _tokenId, uint256 _quantity) public payable {
        // check if account has balance >= quantity
        require(balanceOf(offersMap[_offerId].owner, _tokenId) >= _quantity, "Not enough balance in the owners account");

        // can buy only when status of offer is started
        require(offersMap[_offerId].status == Status.Started, "The offer expired");
        
        // then (quantity * price) + MIN_FEE == msg.value
        require((offersMap[_offerId].totalPrice + MIN_FEE) == msg.value, "Please enter the correct amount");
        
        // tokenId <= tokens.length else tokenId doest exist
        require(_tokenId <= tokens.length, "Token doesn't exist");

        offersMap[_offerId].status = Status.Completed;
        transfer(offersMap[_offerId].owner, msg.sender, _tokenId, _quantity);

        (bool sent, ) = payable(offersMap[_offerId].owner).call{value: offersMap[_offerId].totalPrice}("");
        require(sent, "Failed to send Ether");

        // TokenTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 quantity);
        emit TokenTransferred(offersMap[_offerId].owner, msg.sender, _tokenId, _quantity);
    }

    enum Status { Started, Completed, Canceled}
    Status public status;

    struct Offer {
        address owner;
        uint256 quantity;
        uint256 totalPrice;
        uint256 tokenId;
        Status status;
    }

    Offer[] public offers;

    mapping(address => mapping(uint256 => Offer)) public accOffers;
    mapping(uint256 => Offer) public offersMap;

    function offer(uint256 _quantity, uint256 _tokenId) public {
        require(balanceOf(msg.sender, _tokenId) >= _quantity, "You do not have enough tokens");

        uint256 currOffer = currOfferId();

        // enum state = started
        uint256 _totalPrice = _quantity * tokenInfo[_tokenId].price;

        // created newOffer
        Offer memory newOffer = Offer(msg.sender, _quantity, _totalPrice, _tokenId, Status.Started);

        // added to offers array
        offers.push(newOffer);

        // added to offers mapping
        accOffers[msg.sender][currOffer] = newOffer;
        offersMap[currOffer] = newOffer;

        // OfferCreated(uint256 indexed offerId, address creator, uint256 quantity);
        emit OfferCreated(currOffer, _tokenId, msg.sender, _quantity);

        incOfferId();
    }

    // give the money in escrow, then dispatch tokens to the address
    function offerCancel(uint256 _offerId) public payable {
        require(msg.value == MIN_FEE, "Please enter the required fee");

        // change state to cancelled
        offersMap[_offerId].status = Status.Canceled; 

        // OfferCanceled(uint256 offerId);
        emit OfferCanceled(_offerId);
    }

    function offerReset(uint256 _offerId) public payable {
        require(msg.value == MIN_FEE, "Please enter the required fee");

        // change state to cancelled
        offersMap[_offerId].status = Status.Started; 

        // OfferReset(uint256 offerId);
        emit OfferReset(_offerId);
    }

    function withdraw() payable public onlyOwner {
        require(address(this).balance >= 0, "Balance is 0");

        (bool sent, ) = payable(admin).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    // returns the balance of the smart contract
    function balance() public view returns(uint256) {
        return address(this).balance;
    }
}