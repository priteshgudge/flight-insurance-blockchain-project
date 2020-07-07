pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping (address => uint256) authorizedCallers;
    address[] registeredAirlines = new address[](0);
    mapping(address => bool) private registeredAirlinesMapping; //= new mapping(address => bool);
    mapping(address => address[]) private multiCallsMapping; //= new mapping(address => address[]); // Multiparty consensus data structure
    mapping(address => bool) private multiCallExistenseMapping;
    mapping(address => bool) private airlineHasFunded;
    uint256 FUNDING_AMOUNT = 10 ether;
    uint256 MAX_INSURANCE_AMOUNT = 1 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
        string flightCode;
        uint256 passengerSize;
        mapping(uint256 => PassengerAmount) passengerAmounts;

    }

       // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    struct PassengerAmount{
        address passengerAddress;
        uint256 amount;
    }
    

    mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        registeredAirlinesMapping[msg.sender] = true;
        Flight memory flight1  = Flight({isRegistered: true, flightCode: 'Flight1', passengerSize: 0,
            statusCode: STATUS_CODE_ON_TIME, updatedTimestamp: 1593820800, airline: msg.sender}); //  Saturday, July 4, 2020 12:00:00 AM 
        Flight memory flight2  = Flight({isRegistered: true, flightCode: 'Flight2', passengerSize: 0,
            statusCode: STATUS_CODE_LATE_AIRLINE, updatedTimestamp: 1593907200, airline: msg.sender}); //  Sunday, July 5, 2020 12:00:00 AM 
        Flight memory flight3  = Flight({isRegistered: true, flightCode: 'Flight3', passengerSize: 0,
            statusCode: STATUS_CODE_LATE_AIRLINE, updatedTimestamp: 1593993600, airline: msg.sender}); //  Monday, July 6, 2020 12:00:00 AM 
        // address airline,
                            // string memory flight,
                            // uint256 timestamp
        flights[getFlightKey(flight1.airline, flight1.flightCode, flight1.updatedTimestamp)] = flight1;
        flights[getFlightKey(flight2.airline, flight2.flightCode, flight2.updatedTimestamp)] = flight2;
        flights[getFlightKey(flight3.airline, flight3.flightCode, flight3.updatedTimestamp)] = flight3;

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsRegisteredAirline()
    {
        require(registeredAirlinesMapping[msg.sender], "Caller is not registered Airline");
        _;
    }

    modifier requireIsFundedAirline()
    {
        require(airlineHasFunded[msg.sender], "Caller is not funded Airline");
        _;
    }
     // Define a modifier that checks if the paid amount is sufficient to cover the price
    modifier paidEnough(uint256 _amount) {
        require(msg.value >= _amount, "Caller has not paid enough for funding");
        _;
    }

    modifier maxValueCheck(uint256 _amount){
        require(msg.value <= _amount, "Caller has paid too much for buying");
        _;
    }

    modifier requireIsAuthorizedCaller(){
        require(authorizedCallers[msg.sender] == 1, "Caller is not authorized");
        _;
    }

//   // Define a modifier that checks the price and refunds the remaining balance
//     modifier checkRefundValue(uint _upc) {
//         _;
//         uint _price = items[_upc].productPrice;
//         uint amountToReturn = msg.value - _price;
//         msg.sender.transfer(amountToReturn);
//   }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeCaller(address caller) 
                        requireIsOperational
                        requireContractOwner

    {
        authorizedCallers[caller] = 1;
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    
    function registerAirline
                            (   
                                address airlineAddress
                            )
                            external
                            requireIsOperational
                            requireIsRegisteredAirline
    {
        // <= 4 scenario
        if(registeredAirlines.length <= 4){
            registeredAirlines.push(airlineAddress);
            registeredAirlinesMapping[airlineAddress] = true;
            return;
        }

        // General MultiParty Consensus Scenario
        if(multiCallExistenseMapping[airlineAddress] == true){
            bool isDuplicate = false;
            for(uint256 c = 0; c<multiCallsMapping[airlineAddress].length; c++) {
            if (multiCallsMapping[airlineAddress][c] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller has already called this function.");

        multiCallsMapping[airlineAddress].push(msg.sender);
        if (multiCallsMapping[airlineAddress].length >= uint256(registeredAirlines.length/2)) {
                registeredAirlinesMapping[airlineAddress] = true;
             }
        }else{ // First time airline registration
            multiCallsMapping[airlineAddress] = new address[](0);
            multiCallsMapping[airlineAddress].push(airlineAddress);
            multiCallExistenseMapping[airlineAddress] = true;
            
        }
       
        
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (               
                                bytes32 flightKey              
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsRegisteredAirline
                            requireIsFundedAirline
                            maxValueCheck(MAX_INSURANCE_AMOUNT)
                            
    {      PassengerAmount memory pAmount = PassengerAmount({passengerAddress: msg.sender, amount: msg.value});
           flights[flightKey].passengerAmounts[flights[flightKey].passengerSize] = pAmount;
           flights[flightKey].passengerSize ++;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
                            requireIsRegisteredAirline
                            paidEnough(FUNDING_AMOUNT)
    {
        airlineHasFunded[msg.sender] = true;
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

