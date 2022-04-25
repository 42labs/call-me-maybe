# "But here's my number, so call me maybe"
 -- Carly Rae Jepsen

## About

American Style Options

Currency: The currency of the option, the token the option holder has the right to buy at strike price. Currently also the currency for payment of the buyer's fee.

## Usage

Compile the contract by running `starknet-compile contracts/call_option/CallOption.cairo --abi contracts/abi/CallOption.json --output CallOption_compiled.json`.

# TODO

- Non-USD quote currency
- Verify ERC20 decimals and adjust if not 18
