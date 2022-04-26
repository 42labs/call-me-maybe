import asyncio
import datetime
from collections import namedtuple
import os

from starknet_py.contract import Contract
from starknet_py.net import Client
from Crypto.Hash import keccak
from bitstring import BitArray

from utils import CallOptionSubmission, str_to_felt, to_uint_decimals
from oz_utils import Signer

buyer_account_private_key = int(os.environ("BUYER_PRIVATE_KEY"))
buyer_signer = Signer(buyer_account_private_key)
buyer_account_address = (
    "0x02a4088598f6bc80d7b4720da8157aef31e29d5550b61669af59bc55ad4004b9"
)

seller_account_private_key = int(os.environ("SELLER_PRIVATE_KEY"))
seller_signer = Signer(seller_account_private_key)
seller_account_address = (
    "0x046813d14dff8ed5fa86413fb19c203f6fb1d35ade46f0ac8b76d365677dfd4a"
)

eth_token_address = "0x02a4088598f6bc80d7b4720da8157aef31e29d5550b61669af59bc55ad4004b9"

NETWORK = "testnet"
MAX_FEE = 0

AccountCall = namedtuple(
    "AccountCallArray",
    [
        "to",
        "selector",
        "data_offset",
        "data_len",
    ],
)


async def main():
    buyer_account_contract = await Contract.from_address(
        buyer_account_address, Client(NETWORK)
    )
    seller_account_contract = await Contract.from_address(
        seller_account_address, Client(NETWORK)
    )
    eth_token_contract = await Contract.from_address(eth_token_address, Client(NETWORK))

    transfer_amount = to_uint_decimals(0.01)
    result = await buyer_signer.send_transaction(
        buyer_account_address,
        eth_token_address,
        "transfer",
        [seller_account_contract, transfer_amount],
        max_fee=MAX_FEE,
    )
    breakpoint()
    selector_hash = keccak.new(digest_bits=256)
    selector_hash.update(b"transfer")
    selector = BitArray(hex=selector_hash.hexdigest())[:250].uint

    account_call = AccountCall(
        to=eth_token_address,
        selector=selector,
        data_offset=0,
        data_len=2,
    )

    result = await buyer_account_contract.functions["__default__"].invoke(
        [account_call._asdict()],
        [seller_account_contract, transfer_amount],
        max_fee=MAX_FEE,
    )
    breakpoint()


if __name__ == "__main__":
    asyncio.run(main())
