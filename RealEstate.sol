// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.8.0/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";

contract RealEstate is ERC1155, Ownable {
    address public admin;
    uint256 public constant MIN_FEE = 1 ether;

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
    event OfferCreated(uint256 indexed offerId, uint256 tokenId, address creator, uint256[] quantity, address[] buyers , uint256[] areas , uint256[] prices);
    event TokenTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 quantity);
    event OfferCanceled( address indexed seller , uint256 offerId);

    struct Account {
        address walletAddress;
        string aadharCard;
        string cardNo;
        uint256 cvv;
        string name;
        string expiry;
        string avatar;
        // Token[] properties;
        // mapping(uint256 => Offer) buyOffers;
        // mapping(uint256 => Offer) sellOffers;
    }
    Account[] public accounts;

    mapping(address => Token[]) public properties;

    mapping(address => mapping(uint256 => Offer)) public buyOffers;
    mapping(address => mapping(uint256 => Offer)) public sellOffers;

    struct Offer {
        uint256 offerId;
        address owner;
        uint256[] quantity;
        uint256 tokenId;
        Status status;
        address[] buyers;
        uint256[] areas;
        uint256[] prices;
    }
    Offer[] public offers;

    struct Token {
        uint256 tokenId;
        string metaData;
        uint256 maxDivisions;
        uint256 price;
    }
    Token[] public tokens;

    // 1
    mapping (uint256 => Token) public tokenInfo;
    // 2
    mapping (address => Account) public accDetails;
    // 3
    mapping (address => bool) public accountExists;
    // 4
    mapping (address => Token[]) public ownerTokenDetails;
    // 5
    mapping (address => mapping(uint256 => uint256)) public accTokenBalance;

    function createAccount(address _wallet, string memory _aadharCard, string memory _cardNo, uint256 _cvv, string memory _name, string memory _expiry, string memory _avatar) public {
        
        accountExists[msg.sender] = true;
        
        Account memory newAccount = Account(_wallet, _aadharCard, _cardNo, _cvv, _name, _expiry, _avatar);
        // 2
        accDetails[msg.sender] = newAccount;
        accounts.push(newAccount);
    }

    function createToken(uint256 _maxSupply, uint256 _price, string memory _landDetails) public payable {
        require(msg.value == MIN_FEE, "No transaction fee");
        require(accountExists[msg.sender] == true, "Create an account");
        
        uint256 currId = currTokenId();

        Token memory newToken = Token(currId, _landDetails, _maxSupply, _price);
        // added to array
        tokens.push(newToken);
        // added to mapping, 1
        tokenInfo[currId] = newToken;
        // 4
        ownerTokenDetails[msg.sender].push(newToken);
        
        _mint(msg.sender, currId, _maxSupply, "");

        // event NewTokenCreated(uint256 indexed tokenId, address owner, uint256 maxSupply, uint256 price, string landDetails);
        emit NewTokenCreated(currId, msg.sender, _maxSupply, _price, _landDetails);

        incTokenId();
    }

    function transfer(address _from, address _to, uint256 _tokenId, uint256 _amount) public {
        _safeTransferFrom(_from, _to, _tokenId, _amount, "");
    }

    enum Status { Started, Completed, Canceled}
    Status public status;

    function offer(uint256 _tokenId, address[] memory _buyers, uint256[] memory _quantity,uint256[] memory _areas,uint256[] memory _prices) public {
        uint256 sum = 0;
        
        for (uint256 i=0; i < _quantity.length; i++) {
            sum += _quantity[i];
        }
        
        require(balanceOf(msg.sender, _tokenId) >= sum, "You do not own this asset");

        uint256 currOffer = currOfferId();
        for (uint256 i = 0; i < _buyers.length ; i++) {
            // created newOffer
            Offer memory newOffer = Offer(currOffer, msg.sender, _quantity, _tokenId, Status.Started, _buyers, _areas , _prices);
            
            // sellOffers[msg.sender] = newOffer;
            sellOffers[msg.sender][currOffer] = newOffer;

            //   buyOffers[msg.sender] = newOffer;
            buyOffers[_buyers[i]][currOffer] = newOffer;

            // added to offers array
            offers.push(newOffer);

        }
        // OfferCreated(uint256 indexed offerId, address creator, uint256 quantity);
        emit OfferCreated(currOffer, _tokenId, msg.sender, _quantity, _buyers , _areas , _prices);

        incOfferId();
    }

    // give the money in escrow, then dispatch tokens to the address
    function offerCancel( address _wallet , uint256 _offerId) public payable {
        require(msg.value == MIN_FEE, "Please enter the required fee");

        // change state to cancelled
        // offersMap[_offerId].status = Status.Canceled; 
        sellOffers[_wallet][_offerId].status = Status.Canceled;

        // OfferCanceled(uint256 offerId);
        emit OfferCanceled(sellOffers[_wallet][_offerId].owner, _offerId);
    }

    function withdraw() payable public onlyOwner {
        require(address(this).balance >= 0, "Balance is 0");

        (bool sent,  ) = payable(admin).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    
    function buyToken(uint256 _offerId, uint256 _tokenId, uint256 _quan) public payable {
        Offer memory currOffer = buyOffers[msg.sender][_offerId];

        // check if account has balance >= quantity
        require(balanceOf(currOffer.owner, _tokenId) >= _quan, "You do not own enogh of it this property !");

        // can buy only when status of offer is started
        require(currOffer.status == Status.Started, "The offer has been accepted or rejected");
        
        // tokenId <= tokens.length else tokenId doest exist
        require(_tokenId <= tokens.length, "Token doesn't exist");

        currOffer.status = Status.Completed;
       
        (bool sent, ) = payable(currOffer.owner).call{value: currOffer.prices[0]}("");
        require(sent, "Failed to send Ether");

        transfer(currOffer.owner, msg.sender , _tokenId, _quan);

        // TokenTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 quantity);
        emit TokenTransferred(currOffer.owner,msg.sender, _tokenId, _quan);
    }


    // returns the balance of the smart contract
    function balance() public view returns(uint256) {
        return address(this).balance;
    }
}