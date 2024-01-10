// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0; // 200 runs optimization

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventNFT.sol";
import "./TicketMarketplace.sol";

contract EventFactory is Ownable(msg.sender) {
    struct Event {
        string eventName;
        string eventSymbol;
        uint256 ticketPrice;
        uint256 totalSupply;
        address marketplace;
    }

    address[] private activeEvents;
    mapping(address => Event) private activeEventsMapping;

    event Created(address ntfAddress, address marketplaceAddress);

    // Creates new NFT and a marketplace for its purchase
    function createNewEvent(
        EventToken token,
        string memory eventName,
        string memory eventSymbol,
        uint256 ticketPrice,
        uint256 totalSupply,
        uint256 event_ts,
        string memory event_place
    ) public onlyOwner returns (address) {
        EventNFT newEvent =
            new EventNFT(
                eventName,
                eventSymbol,
                ticketPrice,
                totalSupply,
                msg.sender,
                event_ts,
                event_place
            );
        TicketMarketplace newMarketplace = new TicketMarketplace(token, newEvent);
        address newEventAddress = address(newEvent);
        activeEvents.push(newEventAddress);
        activeEventsMapping[newEventAddress] = Event({
            eventName: eventName,
            eventSymbol: eventSymbol,
            ticketPrice: ticketPrice,
            totalSupply: totalSupply,
            marketplace: address(newMarketplace)
        });

        emit Created(newEventAddress, address(newMarketplace));

        return newEventAddress;
    }

    // // Get all active events
    // function getActiveEvents() public view returns (address[] memory) {
    //     return activeEvents;
    // }

    // Get events's details
    function getEventsDetails(address eventAddress)
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            address
        )
    {
        return (
            activeEventsMapping[eventAddress].eventName,
            activeEventsMapping[eventAddress].eventSymbol,
            activeEventsMapping[eventAddress].ticketPrice,
            activeEventsMapping[eventAddress].totalSupply,
            activeEventsMapping[eventAddress].marketplace
        );
    }
}