import os
import pytest
import pytest_asyncio

from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException

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


@pytest_asyncio.fixture
async def contracts():
    starknet = await Starknet.empty()
    mock_oracle_contract = await starknet.deploy(
        source=MOCK_ORACLE_CONTRACT_FILE,
    )
    call_option_contract = await starknet.deploy(
        source=CONTRACT_FILE,
        constructor_calldata=[mock_oracle_contract.contract_address]
    )
    buyer_account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[mock_oracle_contract.contract_address]
    )
    seller_account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[mock_oracle_contract.contract_address]
    )
    token_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[mock_oracle_contract.contract_address]
    )

    return call_option_contract, buyer_account_contract, seller_account_contract, token_contract

@pytest.mark.asyncio
async def test_deploy(contracts):
    return

