// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./EventNFT.sol";
import "./EventToken.sol";

contract TicketMarketplace {
    EventToken private _token;
    EventNFT private _event;

    address public _organiser; // TODO private 

    constructor(EventToken token, EventNFT event_) {
        _token = token;
        _event = event_;
        _organiser = _event.getOrganiser();
    }

    event Purchase(address indexed buyer, address seller, uint256 ticketId);
    
    // Purchase tickets from the organiser directly
    function purchaseTicket() public {
        address buyer = msg.sender;
        // Transfer TicketPrice EventTokens to organizer
        _token.transferFrom(buyer, _organiser, _event.getTicketPrice());
        // Transfer ticket to buyer
        _event.transferTicket(buyer);
    }

    // Purchase ticket from the secondary market hosted by organiser
    function secondaryPurchaseTicket(uint256 ticketId) public {
        require(_event.getSellingPrice(ticketId) > 0);
        address seller = _event.ownerOf(ticketId);
        address buyer = msg.sender;
        uint256 sellingPrice = _event.getSellingPrice(ticketId);
        uint256 commision = uint((sellingPrice * 10) / 100);

        _token.transferFrom(buyer, seller, sellingPrice - commision);
        _token.transferFrom(buyer, _organiser, commision);

        _event.secondaryTransferTicket(buyer, ticketId);

        // emit Purchase(buyer, seller, ticketId);
    }

}