# "But here's my number, so call me maybe"

You took your time with StarkNet
But there was simply no choice
L1 gave me nothing at all
So I learned Cairo quick
I beg and borrow and steal
StarkNet works, and it's real
I didn't know I would feel it
But it's in my way

Uri’s stare was holdin'
Ripped jeans, skin was showin'
Hot night, wind was blowin'
Where you think ETH’s going, baby? (To the moon!)

Hey, I just bought Eth, and this is crazy
But here's my option, so call Eth, maybe
It's hard to buy right, in this market
But here's my option, so call Eth, maybe

 -- Oskar Schulz

## About

American Style Options

Currency: The currency of the option, the token the option holder has the right to buy at strike price. Currently also the currency for payment of the buyer's fee.

## Usage

Compile the contract by running `starknet-compile contracts/call_option/CallOption.cairo --abi contracts/abi/CallOption.json --output CallOption_compiled.json`.

# TODO

- Non-USD quote currency
- Verify ERC20 decimals and adjust if not 18
- Turn the tokens into tradeable assets
- Incorporate Black-Scholes models for using options as collateral
