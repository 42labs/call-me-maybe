import asyncio
from collections import namedtuple
import datetime
import os

from starknet_py.contract import Contract
from starknet_py.net import Client
from oz_utils import Signer
from Crypto.Hash import keccak
from bitstring import BitArray

from utils import CallOptionSubmission, str_to_felt, to_uint_decimals

buyer_account_private_key = int(os.environ.get("BUYER_PRIVATE_KEY"))
buyer_signer = Signer(buyer_account_private_key)
buyer_account_address = (
    "0x03cbe3aa548cbdb54e8f83b486a51389526228af552bfa19c7c4571134459465"
)

seller_account_private_key = int(os.environ.get("SELLER_PRIVATE_KEY"))
seller_signer = Signer(seller_account_private_key)
seller_account_address = (
    "0x022a840112c1ffe7f3e788d3e7548fe25094e6a808274ffc548d25ca4cae951d"
)

call_option_contract_address = (
    "0x023528c20d1b2392233cc98ffd5ef16d6e76c92bea82ccb790b83cdb79d1b6d8"
)
oracle_address = "0x039d1bb4904cef28755c59f081cc88a576ecdf42240fb73dd44ddd003848ce33"
eth_token_address = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"

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
    call_option_contract = await Contract.from_address(
        call_option_contract_address, Client(NETWORK)
    )
    buyer_account_contract = await Contract.from_address(
        buyer_account_address, Client(NETWORK)
    )
    seller_account_contract = await Contract.from_address(
        seller_account_address, Client(NETWORK)
    )

    # Define Call
    option_id = 1  # result.result.call_option_id
    """
    hours_to_expiry = int(input("Hours until expiration"))
    expiration_timestamp = int(
        datetime.datetime.utcnow() + datetime.timedelta(hours=hours_to_expiry)
    ).timestamp()
    """
    expiration_timestamp = 1650964431
    # fee_input = float(input("Fee in ETH"))
    fee = 1000000000000000  # to_uint_decimals(fee_input)
    # size_input = float(input("Size of call in ETH"))
    size = 10000000000000000  # to_uint_decimals(size_input)
    # strike_price_input = float(input("Strike price in ETH/USD"))
    strike_price = 3000000000000000000000  # to_uint_decimals(strike_price_input)

    oracle_key = str_to_felt("eth/usd")
    call_option_submission = CallOptionSubmission(
        id=option_id,
        expiration_timestamp=expiration_timestamp,
        fee=fee,
        size=size,
        strike_price=strike_price,
        currency_address=eth_token_address,
        oracle_key=oracle_key,
    )

    # Approve Buyer
    selector_hash = keccak.new(digest_bits=256)
    selector_hash.update(b"transfer")
    selector = BitArray(hex=selector_hash.hexdigest())[:250].uint
    account_call = AccountCall(
        to=eth_token_address,
        selector=selector,
        data_offset=0,
        data_len=2,
    )
    result_approve_buyer = await buyer_account_contract.functions["__execute__"].invoke(
        [account_call._asdict()],
        [eth_token_address, fee],
        max_fee=MAX_FEE,
    )

    breakpoint()

    # Register Call
    result = await call_option_contract.generate_call_option_id().invoke(
        max_fee=MAX_FEE
    )
    print(result)
    breakpoint()

    result = await call_option_contract.functions["register_call_option"].invoke(
        call_option_submission._asdict(),
        max_fee=MAX_FEE,
    )
    breakpoint()

    # Approve Seller
    result_approve_seller = await seller_signer.send_transaction(
        seller_account_contract,
        eth_token_address,
        "approve",
        [eth_token_address, size],
        max_fee=MAX_FEE,
    )
    breakpoint()

    # Confirm Call
    result = await call_option_contract.functions["confirm_call_option"].invoke(
        call_option_submission._asdict(),
        max_fee=MAX_FEE,
    )
    breakpoint()

    # Exercise Call
    result = await call_option_contract.functions["exercise_call_option"].invoke(
        option_id,
        max_fee=MAX_FEE,
    )
    breakpoint()


if __name__ == "__main__":
    asyncio.run(main())
