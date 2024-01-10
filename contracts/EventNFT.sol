// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract EventNFT is Context, AccessControl, ERC721{
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint public constant RESALE_COMISSION = 10; //комиссия перепродажи в процентах
    uint public constant MAX_TICKET_NUMBER = 5;

    Counters.Counter public _ticketId; // количество сминченных NFT // TODO private
    Counters.Counter public _saleTicketId; // количество проданных NFT // TODO private

    address private _organiser;
    uint256 private _ticketPrice;
    uint256 private _ticketSupply;
    uint256 private _event_ts;
    string private _event_place;

    // address[] public customers; // TODO private

    mapping(uint256 => TicketDetails) public _ticketDetails; // TODO private
    mapping(address => uint256) public _numberOfPurchasedTickets; // TODO private
    mapping(address => mapping(uint256 => bool)) public _purchasedTickets; // TODO private

    struct TicketDetails {
        uint256 purchasePrice; // цена, по которой куплен билет
        uint256 sellingPrice; // цена для продажи
        bool forSale; // флаг, продается ли билет
        uint256 event_ts; // время события
        string event_place; // местоположение события
    }

    constructor(
        string memory eventName,
        string memory eventSymbol,
        uint256 ticketPrice,
        uint256 ticketSupply,
        address organiser,
        uint256 event_ts,
        string memory event_place
    ) ERC721(eventName, eventSymbol) {
        _grantRole(MINTER_ROLE, organiser);
        _ticketPrice = ticketPrice;
        _ticketSupply = ticketSupply;
        _organiser = organiser;
        _event_ts = event_ts;
        _event_place = event_place;
    }
    /*
        Модификаторы
    */
    // Ограничение по количеству билетов на адрес
    modifier isValidNumberOfTickets(address customer) {
        require(
            _numberOfPurchasedTickets[customer] < MAX_TICKET_NUMBER,
            "One address can maximum buy only MAX_TICKET_NUMBER tickets"
        );
        _;
    }

    // Ограничение по цене перепродажи билетов
    modifier isValidSellAmount(uint256 ticketId) {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;
        uint256 sellingPrice = _ticketDetails[ticketId].sellingPrice;

        require(
            uint((purchasePrice * 110) / 100) >= sellingPrice,
            "Re-selling price is more than 110%"
        );
        _;
    }

    /*
     * Mint new tickets and assign it to operator
     * Access controlled by minter only
     * Returns new ticketId
     */
    function mint(address operator)
        internal
        virtual
        returns (uint256)
    {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "User must have minter role to mint"
        );
        _ticketId.increment();
        uint256 newTicketId = _ticketId.current();
        _mint(operator, newTicketId);

        _ticketDetails[newTicketId] = TicketDetails({
            purchasePrice: _ticketPrice,
            sellingPrice: 0,
            forSale: false,
            event_ts: _event_ts,
            event_place: _event_place
        });

        return newTicketId;
    }

    /*
     * Bulk mint specified number of tickets to assign it to a operator
     * Modifier to check the ticket count is less than total supply
     */
    function bulkMintTickets(uint256 numOfTickets, address operator)
        public
        virtual
    {
        require(
            (_ticketId.current() + numOfTickets) < _ticketSupply,
            "Number of tickets exceeds maximum ticket count"
        );

        for (uint256 i = 0; i < numOfTickets; i++) {
            mint(operator);
        }
    }

    /*
     * Primary purchase for the tickets
     * Adds new customer if not exists
     * Adds buyer to tickets mapping
     * Update ticket details
     */
    function transferTicket(address buyer) public isValidNumberOfTickets(buyer) {
        _saleTicketId.increment();
        uint256 saleTicketId = _saleTicketId.current();

        require(
            msg.sender == ownerOf(saleTicketId),
            "Only initial purchase allowed"
        );

        transferFrom(ownerOf(saleTicketId), buyer, saleTicketId);

        _purchasedTickets[buyer][saleTicketId] = true;
        _numberOfPurchasedTickets[buyer] += 1;
    }

    /*
     * Secondary purchase for the tickets
     * Modifier to validate that the selling price shouldn't exceed 110% of purchase price for peer to peer transfers
     * Adds new customer if not exists
     * Adds buyer to tickets mapping
     * Remove ticket from the seller and from sale
     * Update ticket details
     */
    function secondaryTransferTicket(address buyer, uint256 saleTicketId)
        public
        isValidSellAmount(saleTicketId)
        isValidNumberOfTickets(buyer)
    {
        address seller = ownerOf(saleTicketId);
        uint256 sellingPrice = _ticketDetails[saleTicketId].sellingPrice;
        
        transferFrom(seller, buyer, saleTicketId);

        // if (!isCustomerExist(buyer)) {
        //     customers.push(buyer);
        // }

        _purchasedTickets[buyer][saleTicketId] = true;
        _purchasedTickets[seller][saleTicketId] = false;

        _numberOfPurchasedTickets[buyer] += 1;
        _numberOfPurchasedTickets[seller] -= 1;

        _ticketDetails[saleTicketId] = TicketDetails({
            purchasePrice: sellingPrice,
            sellingPrice: 0,
            forSale: false,
            event_ts: _event_ts,
            event_place: _event_place
        });
    }

    /*
     * Add ticket for sale with its details
     * Validate that the selling price shouldn't exceed 110% of purchase price
     * Organiser can not use secondary market sale
     */
    function setSaleDetails(
        uint256 ticketId,
        uint256 sellingPrice,
        address operator
    ) public {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;

        require(
            ((purchasePrice * 110) / 100) >= sellingPrice,
            "Re-selling price is more than 110%"
        );

        // Should not be an organiser
        require(
            !hasRole(MINTER_ROLE, _msgSender()),
            "Functionality only allowed for secondary market"
        );

        require(sellingPrice > 0);

        _ticketDetails[ticketId].sellingPrice = sellingPrice;
        _ticketDetails[ticketId].forSale = true;

        approve(operator, ticketId);
    }

    /*
        Get-functions
    */
    // Get organiser's address
    function getOrganiser() public view returns (address) {
        return _organiser;
    }

    // Get ticket actual price
    function getTicketPrice() public view returns (uint256) {
        return _ticketPrice;
    }

    // Get selling price for the ticket
    function getSellingPrice(uint256 ticketId) public view returns (uint256) {
        return _ticketDetails[ticketId].sellingPrice;
    }

    // Get current ticketId
    function ticketCounts() public view returns (uint256) {
        return _ticketId.current();
    }

    // Get next sale ticketId
    function getSaledTicketId() public view returns (uint256) {
        return _saleTicketId.current();
    }


    // // Get all tickets available for sale
    // function getTicketsForSale() public view returns (uint256[] memory) {
    //     return ticketsForSale;
    // }

    // Get ticket details
    function getTicketDetails(uint256 ticketId)
        public
        view
        returns (
            uint256 purchasePrice,
            uint256 sellingPrice,
            bool forSale
        )
    {
        return (
            _ticketDetails[ticketId].purchasePrice,
            _ticketDetails[ticketId].sellingPrice,
            _ticketDetails[ticketId].forSale
        );
    }

    // Get all tickets owned by a customer
    // function getTicketsOfCustomer(address customer)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     return _numberOfPurchasedTickets[customer];
    // }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721) returns (bool) {
        // Add your custom implementation here if needed
        return super.supportsInterface(interfaceId);
    }

}