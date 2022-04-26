# "But here's my number, so call me maybe"

You took your time with StarkNet <br />
But there was simply no choice <br />
L1 is nothing at all <br />
So I learned Cairo quick <br />
I beg and borrow and steal <br />
StarkNet works, and it's real <br />
I didn't know I would feel it <br />
But it's in my way

Uri’s stare was holdin' <br />
Ripped jeans, skin was showin' <br />
Hot night, wind was blowin' <br />
Where you think ETH’s going, baby? (To the moon!) <br />

Hey, I just bought Eth, and this is crazy <br />
But here's my option, so call Eth, maybe <br />
It's hard to buy right, in this market <br />
But here's my option, so call Eth, maybe <br />

 -- Oskar Schulz

## About

Hackathon project for 2022 Starknet Hackathon in Amsterdam, by Jonas Nelle.

Project: P2P American Style Call Options Protocol.

Description: Currency: The currency of the option, the token the option holder has the right to buy at strike price. Currently also the currency for payment of the buyer's fee.

Motivation: Perpetuals are preferred to options because they are more liquid and because they have no delivery, so the contract parties do not have to hold the underlying assets. We address the second weakness: By using price feeds from the Pontis oracle, we enable the options to deal only with one currency for the fee, collateral and underlying spot asset.

## Usage

Compile the contract by running `starknet-compile contracts/call_option/CallOption.cairo --abi contracts/abi/CallOption.json --output CallOption_compiled.json`.

# Future Extensions

- User interface
- Put options
- Non-USD quote currency
- Verify ERC20 decimals and adjust if not 18
- Turn the tokens into tradeable assets
- Incorporate Black-Scholes models for using options as collateral
- Marketplace on top of the options protocol to facilitate matching supply and demand
