import os
import pytest
import pytest_asyncio
import time

from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.crypto.signature.signature import get_random_private_key, private_to_stark_key

from utils import str_to_felt, CallOptionSubmission, to_uint

# The path to the contract source code.
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/call_option/CallOption.cairo"
)
MOCK_ORACLE_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "MockOracle.cairo"
)
ACCOUNT_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/account/Account.cairo"
)
TOKEN_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/erc20/ERC20.cairo"
)
# Also need to deploy two account contracts and a mock oracle
# And a ERC20 token contract

@pytest.fixture
def private_keys():
    buyer_private_key = get_random_private_key()
    seller_private_key = get_random_private_key()
    return buyer_private_key, seller_private_key

def to_uint_decimals(input):
    return to_uint(int(input*10**18))

@pytest_asyncio.fixture
async def contracts(private_keys):
    buyer_private_key, seller_private_key = private_keys
    starknet = await Starknet.empty()
    mock_oracle_contract = await starknet.deploy(
        source=MOCK_ORACLE_CONTRACT_FILE,
    )
    call_option_contract = await starknet.deploy(
        source=CONTRACT_FILE,
        constructor_calldata=[mock_oracle_contract.contract_address]
    )
    buyer_public_key = private_to_stark_key(buyer_private_key)
    buyer_account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[buyer_public_key]
    )
    seller_public_key = private_to_stark_key(seller_private_key)
    seller_account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[seller_public_key]
    )

    # Mint 4 tokens and send one to each account
    name = str_to_felt("test")
    symbol = str_to_felt("tst")
    decimals = 18
    initial_supply = to_uint_decimals(4)
    token_contract = await starknet.deploy(
        source=TOKEN_CONTRACT_FILE,
        constructor_calldata=[name, symbol, decimals, *initial_supply, seller_account_contract.contract_address]
    )
    transfer_amount = to_uint_decimals(2)
    await token_contract.transfer(buyer_account_contract.contract_address, transfer_amount).invoke(caller_address=seller_account_contract.contract_address)

    return call_option_contract, buyer_account_contract, seller_account_contract, token_contract

@pytest.mark.asyncio
async def test_deploy(contracts):
    _, buyer_account_contract, seller_account_contract, token_contract = contracts
    result = await token_contract.balanceOf(buyer_account_contract.contract_address).invoke()
    assert result.result.balance == to_uint_decimals(2)
    result = await token_contract.balanceOf(seller_account_contract.contract_address).invoke()
    assert result.result.balance == to_uint_decimals(2)
    return

@pytest.mark.asyncio
async def test_call(contracts):
    call_option_contract, buyer_account_contract, seller_account_contract, token_contract = contracts

    result = await call_option_contract.generate_call_option_id().invoke()
    option_id = result.result.call_option_id
    expiration_timestamp = int(time.time())
    fee = to_uint_decimals(0.1)
    size = to_uint_decimals(1)
    strike_price = to_uint_decimals(21) # Half of 42, the oracle's answer so buyer and seller should end up with half of the collateral
    currency_address = token_contract.contract_address
    oracle_key = str_to_felt("tst/usd") # Doesn't matter because mock oracle always returns 42
    call_option_submission = CallOptionSubmission(id=option_id, expiration_timestamp=expiration_timestamp, fee=fee, size=size, strike_price=strike_price, currency_address=currency_address, oracle_key=oracle_key)

    await token_contract.approve(call_option_contract.contract_address, fee).invoke(caller_address=buyer_account_contract.contract_address)
    await call_option_contract.register_call_option(call_option_submission).invoke(caller_address=buyer_account_contract.contract_address)

    await token_contract.approve(call_option_contract.contract_address, size).invoke(caller_address=seller_account_contract.contract_address)
    await call_option_contract.confirm_call_option(call_option_submission).invoke(caller_address=seller_account_contract.contract_address)

    await call_option_contract.exercise_call_option(option_id).invoke(caller_address=buyer_account_contract.contract_address)

    result = await token_contract.balanceOf(buyer_account_contract.contract_address).invoke()
    assert result.result.balance == to_uint_decimals(2.4)

    result = await token_contract.balanceOf(seller_account_contract.contract_address).invoke()
    assert result.result.balance == to_uint_decimals(1.5)

    return

