// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Import ERC721 interface
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol"; // Import ERC721Receiver interface
import "@openzeppelin/contracts/utils/Address.sol"; // Import Address library

contract NFTMarketplace is IERC721Receiver {
    using Address for address payable;

    struct Listing {
        address owner; // Owner of the NFT
        uint256 tokenId; // ID of the NFT
        uint256 price; // Listing price in wei
        bool active; // Whether the listing is active or not
    }

    IERC721 private _nftContract; // Address of the ERC721 contract
    mapping(uint256 => Listing) private _listings; // Mapping of tokenId to listing
    mapping(address => uint256[]) private _userListings; // Mapping of user address to their listings
    uint256 private _platformFee; // Fee percentage charged by the marketplace platform

    event NFTListed(address indexed owner, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor() {
        _platformFee = 2; // Default platform fee is 2% (you can modify this value as desired)
    }
    
    // Function to set the ERC721 contract address
    function setERC721Contract(address nftContract) external {
        _nftContract = IERC721(nftContract);
    }

    // Function to list an NFT for sale
    function listNFT(uint256 tokenId, uint256 price) external {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(_listings[tokenId].active == false, "NFT is already listed");
        
        _nftContract.safeTransferFrom(msg.sender, address(this), tokenId); // Transfer NFT to the marketplace contract
        _listings[tokenId] = Listing({ owner: msg.sender, tokenId: tokenId, price: price, active: true });
        _userListings[msg.sender].push(tokenId);
        
        emit NFTListed(msg.sender, tokenId, price);
    }

    // Function to buy an NFT
    function buyNFT(uint256 tokenId) external payable {
        Listing storage listing = _listings[tokenId];
        require(listing.active == true, "NFT is not listed");
        require(msg.value >= listing.price, "Insufficient payment");

        address payable seller = payable(listing.owner);
        uint256 feeAmount = (msg.value * _platformFee) / 100; // Calculate the platform fee
        uint256 remainingAmount = msg.value - feeAmount; // Remaining amount to be sent to the seller
        
        listing.active = false;
        delete _listings[tokenId];
        
        _nftContract.safeTransferFrom(address(this), msg.sender, tokenId); // Transfer NFT to the buyer
        seller.sendValue(remainingAmount); // Send remaining amount to the seller
        
        emit NFTSold(seller, msg.sender, tokenId, msg.value);
    }

    // Function to unlist an NFT
    function unlistNFT(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        require(listing.active == true, "NFT is not listed");
        require(listing.owner == msg.sender, "You don't own this NFT");

        listing.active = false;
        delete _listings[tokenId];

        _nftContract.safeTransferFrom(address(this), msg.sender, tokenId); // Transfer NFT back to the owner
    }

    // Function to get the listing details of an NFT
    function getListing(uint256 tokenId) external view returns (address owner, uint256 price, bool active) {
        Listing storage listing = _listings[tokenId];
        return (listing.owner, listing.price, listing.active);
    }

    // Function to get the list of listings owned by a user
    function getUserListings(address user) external view returns (uint256[] memory) {
        return _userListings[user];
    }

    // Function to set the platform fee percentage
    function setPlatformFee(uint256 fee) external {
        require(msg.sender == address(this), "Only contract owner can set the fee");
        require(fee <= 10, "Fee percentage should be less than or equal to 10");
        _platformFee = fee;
    }

    // Function to receive ERC721 tokens
    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata) external override returns (bytes4) {
        require(operator == address(this), "ERC721 token not accepted");
        _listings[tokenId] = Listing({ owner: msg.sender, tokenId: tokenId, price: 0, active: false });
        _userListings[msg.sender].push(tokenId);
        
        return this.onERC721Received.selector;
    }
}