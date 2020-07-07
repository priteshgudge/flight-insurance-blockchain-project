
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 5;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;
    
        // Watch contract events
        const ON_TIME = 10;
      //  config.flightSuretyApp.allEvents(
      //  (error, event) => {
      //     // if (result.event === 'OracleRequest') {
      //     //   console.log(`\n\nOracle Requested: index: ${result.args.index.toNumber()}, flight:  ${result.args.flight}, timestamp: ${result.args.timestamp.toNumber()}`);
      //     // } else {
      //     //   console.log(`\n\nFlight Status Available: flight: ${result.args.flight}, timestamp: ${result.args.timestamp.toNumber()}, status: ${result.args.status.toNumber() == ON_TIME ? 'ON TIME' : 'DELAYED'}, verified: ${result.args.verified ? 'VERIFIED' : 'UNVERIFIED'}`);
      //     // }
      //     console.log(error, event);
      //   });

  });


  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {
    
    // ARRANGE
    let flight = 'ND1309'; // Course number
    let timestamp = Math.floor(Date.now() / 1000);

    await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, flight, timestamp);
    const requestEvents = await config.flightSuretyApp.getPastEvents('OracleRequest');
    requestEvents.forEach(event => {
      console.log(event.returnValues);
    });
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {
      console.log(`\nOracle: ${a}`)
      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {
        console.log(`\n Index: ${oracleIndexes[idx].toNumber()}`)
        try {
          // Submit a response...it will only be accepted if there is an Index match
          
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, flight, timestamp, 10, { from: accounts[a] });
          console.log(`Submitted ${oracleIndexes[idx].toNumber()}, ${config.firstAirline}, ${flight}, ${timestamp}, ${10}`)
          
          const oracleReportEvents = await config.flightSuretyApp.getPastEvents('OracleReport');
          oracleReportEvents.forEach(event => {
          console.log(event.returnValues);
        });

        }
        catch(e) {
          // Enable this when debugging
          //console.log(e);
           console.log('Error', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }

      }
    }

  const flightStausEvents = await config.flightSuretyApp.getPastEvents('FlightStatusInfo');
  flightStausEvents.forEach(event => {
    console.log(event.returnValues);
  });

  });
});
