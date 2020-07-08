import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
            

            //this.owner = accts[0];
            let self = this;

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
                
            }
            

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            
            }

            self.registerInitialAirlines(() => console.log("Registered airlines"));
            self.registerFlights(() => console.log("Flights Registered"));
            self.buyInsuranceSamplePassengers(() => console.log("Bought insurance"));
            callback();
        });
    }

    registerFlights(callback){

         let self = this;

        self.flightSuretyApp.methods.registerFlight('ND1309', self.airlines[1], 1593820800).send({ from: self.airlines[1]}, (error, result) => {
            callback(error);});
        self.flightSuretyApp.methods.registerFlight('ND1409', self.airlines[1], 1593820800).send({ from: self.airlines[1]}, (error, result) => {
            callback(error);});
        self.flightSuretyApp.methods.registerFlight('ND1509', self.airlines[1], 1593820800).send({ from: self.airlines[1]}, (error, result) => {
            callback(error);});

            callback();

    }

    registerInitialAirlines(callback){

        //this.owner = accts[0];
        let self = this;

        for(let i=1; i<5; i++){
            self.flightSuretyApp.methods.fundInsurance().send({ from: self.airlines[i], value: Web3.utils.toWei("10", "ether")}, (error, result) => {
                callback(error);
            });
            console.log("Funded airlines");
            self.flightSuretyApp.methods.registerAirline(self.airlines[i]).send({ from: self.owner}, (error, result) => {
                callback(error);
            });
        }

        callback();
    }

    buyInsuranceSamplePassengers(callback){

        //this.owner = accts[0];
        let self = this;

        let payload = {
            airline: self.airlines[0],
            flight: "ND1309",
            timestamp: 1593820800//Math.floor(Date.now() / 1000)
        } 

        for(let i=1; i<5; i++){
            self.flightSuretyApp.methods.buyInsurance(
                payload.airline,
                payload.flight,
                payload.timestamp
                ).send({ from: self.passengers[i], value: Web3.utils.toWei("0.9", "ether")}, (error, result) => {
                    callback(error, payload);
                });
        }
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: 1593820800//Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
}