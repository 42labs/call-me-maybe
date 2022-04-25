%lang starknet

from starkware.starknet.common.syscalls import (
    get_caller_address, get_block_timestamp, get_contract_address)
from starkware.cairo.common.math import assert_lt, assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import split_64, uint256_signed_lt, uint256_sub

from contracts.erc20.IERC20 import IERC20
from contracts.security.reentrancy_guard import ReentrancyGuard_start, ReentrancyGuard_end
from contracts.oracle.IOracle import IOracle
from contracts.utils.fixedpointmathlib import mulDivDown

#
# Structs
#
struct CallOption_CallOptionSubmission:
    member id : felt  # incrementing ID that also acts as a Nonce
    member expiration_timestamp : felt  # UTC, epoch
    member fee : Uint256  # fee in currency, with 18 decimals (because ETH)
    member size : Uint256  # size of the option (amount of currency)
    member strike_price : Uint256  # strike price in currency/USD
    member currency_address : felt  # currency address (for the fee and option denomination)
    member oracle_key : felt  # key to lookup price with Pontis oracle, e.g. str_to_felt("eth/usd")
end

struct CallOption_CallOption:
    member id : felt
    member expiration_timestamp : felt
    member fee : Uint256
    member size : Uint256
    member strike_price : Uint256
    member currency_address : felt
    member oracle_key : felt
    member buyer_address : felt
    member seller_address : felt
    member did_buyer_initialize : felt  # Boolean, TRUE iff buyer has submitted data and fee
    member did_seller_initialize : felt  # Boolean, TRUE iff seller has submitted data and margin
    member is_open : felt  # Boolean, TRUE iff was initialized AND has not been canceled AND has not been redeemed
end

#
# Consts
#
const DECIMALS = 18

#
# Storage
#
@storage_var
func CallOption_next_call_option_id_storage() -> (next_call_option_id : felt):
end

@storage_var
func CallOption_call_option_storage(option_id : felt) -> (call_option : CallOption_CallOption):
end

@storage_var
func CallOption_decimals_storage() -> (decimals : felt):
end

@storage_var
func CallOption_oracle_address_storage() -> (oracle_address : felt):
end

#
# Initializers
#
func CallOption_intialize_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(oracle_address : felt):
    let (decimals) = IOracle.get_decimals(oracle_address)

    with_attr error_message("Oracle decimals diverges from call option decimals"):
        assert decimals = DECIMALS
    end

    CallOption_decimals_storage.write(decimals)
    CallOption_oracle_address_storage.write(oracle_address)
    return ()
end

#
# Getters
#
func CallOption_generate_call_option_id{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        call_option_id : felt):
    let (call_option_id) = CallOption_next_call_option_id_storage.read()
    let next_call_option_id = call_option_id + 1
    CallOption_next_call_option_id_storage.write(next_call_option_id)
    return (call_option_id)
end

func CallOption_get_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        option_id : felt) -> (call_option : CallOption_CallOption):
    let (call_option) = CallOption_call_option_storage.read(option_id)
    return (call_option)
end

#
# Setters
#

# Called by buyer to register the call option
func CallOption_register_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        call_option_submission : CallOption_CallOptionSubmission):
    let (existing_call_option) = CallOption_get_call_option(call_option_submission.id)

    with_attr error_message("Call already registered"):
        assert existing_call_option.expiration_timestamp = 0
    end

    let (current_timestamp) = get_block_timestamp()

    with_attr error_message("Expiration timestamp must be in the future"):
        assert_lt(current_timestamp, call_option_submission.expiration_timestamp)
    end

    # Pull in fee from buyer
    let (buyer_address) = get_caller_address()
    let (call_option_contract_address) = get_contract_address()
    let (did_buyer_pay) = IERC20.transferFrom(
        call_option_submission.currency_address,
        buyer_address,
        call_option_contract_address,
        call_option_submission.fee)

    with_attr error_message("Buyer fee payment failed"):
        assert did_buyer_pay = TRUE
    end

    let call_option = CallOption_CallOption(
        id=call_option_submission.id,
        expiration_timestamp=call_option_submission.expiration_timestamp,
        fee=call_option_submission.fee,
        size=call_option_submission.size,
        strike_price=call_option_submission.strike_price,
        currency_address=call_option_submission.currency_address,
        oracle_key=call_option_submission.oracle_key,
        buyer_address=buyer_address,
        seller_address=0,
        did_buyer_initialize=TRUE,
        did_seller_initialize=FALSE,
        is_open=FALSE)

    CallOption_call_option_storage.write(call_option_submission.id, call_option)
    return ()
end

# Called by seller to confirm the call option
func CallOption_confirm_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        call_option_submission : CallOption_CallOptionSubmission):
    let (call_option) = CallOption_call_option_storage.read(call_option_submission.id)

    let (current_timestamp) = get_block_timestamp()

    let (seller_address) = get_caller_address()

    with_attr error_message("Expiration timestamp must be in the future"):
        assert_lt(current_timestamp, call_option_submission.expiration_timestamp)
    end

    with_attr error_message("Buyer must register call option first"):
        assert_not_equal(call_option.expiration_timestamp, 0)
        assert call_option.did_buyer_initialize = TRUE
    end

    with_attr error_message("Call is no longer open"):
        assert call_option.is_open = TRUE
    end

    with_attr error_message("Call submission does not match the buyer's submission"):
        assert call_option.expiration_timestamp = call_option_submission.expiration_timestamp
        assert call_option.fee = call_option_submission.fee
        assert call_option.size = call_option_submission.size
        assert call_option.strike_price = call_option_submission.strike_price
        assert call_option.currency_address = call_option_submission.currency_address
        assert call_option.oracle_key = call_option_submission.oracle_key
    end

    # Pull in collateral from seller
    let (call_option_contract_address) = get_contract_address()
    let (did_seller_deposit) = IERC20.transferFrom(
        call_option.currency_address,
        seller_address,
        call_option_contract_address,
        call_option_submission.size)

    with_attr error_message("Seller deposit failed"):
        assert did_seller_deposit = TRUE
    end

    let new_call_option = CallOption_CallOption(
        id=call_option.id,
        expiration_timestamp=call_option.expiration_timestamp,
        fee=call_option.fee,
        size=call_option.size,
        strike_price=call_option.strike_price,
        currency_address=call_option.currency_address,
        oracle_key=call_option.oracle_key,
        buyer_address=call_option.buyer_address,
        seller_address=seller_address,
        did_buyer_initialize=call_option.did_buyer_initialize,
        did_seller_initialize=TRUE,
        is_open=TRUE)
    CallOption_call_option_storage.write(call_option.id, new_call_option)
    return ()
end

# Called by the buyer if the seller hasn't submitted yet and they want to cancel
func CallOption_cancel_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(option_id : felt):
    alloc_locals

    let (call_option) = CallOption_get_call_option(option_id)
    let (caller_address) = get_caller_address()

    with_attr error_message("Only buyer can cancel call option"):
        assert caller_address = call_option.buyer_address
    end

    with_attr error_message("Call is no longer open"):
        assert call_option.is_open = TRUE
    end

    ReentrancyGuard_start(option_id)

    # Send buyer back their fee
    # TODO: minus gas costs?
    let (call_option_contract_address) = get_contract_address()
    let (did_buyer_refund_succeed) = IERC20.transfer(
        call_option.currency_address, call_option.buyer_address, call_option.fee)

    if did_buyer_refund_succeed == TRUE:
        let new_call_option = CallOption_CallOption(
            id=call_option.id,
            expiration_timestamp=call_option.expiration_timestamp,
            fee=call_option.fee,
            size=call_option.size,
            strike_price=call_option.strike_price,
            currency_address=call_option.currency_address,
            oracle_key=call_option.oracle_key,
            buyer_address=call_option.buyer_address,
            seller_address=call_option.seller_address,
            did_buyer_initialize=call_option.did_buyer_initialize,
            did_seller_initialize=call_option.did_buyer_initialize,
            is_open=FALSE)
        CallOption_call_option_storage.write(option_id, new_call_option)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    ReentrancyGuard_end(option_id)

    with_attr error_message("Buyer refund failed. State not updated, please try again"):
        assert did_buyer_refund_succeed = TRUE
    end

    return ()
end

# Called by the seller to redeem the call if the option has expired and was not exercised
func CallOption_redeem_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(option_id : felt):
    alloc_locals

    let (call_option) = CallOption_call_option_storage.read(option_id)
    let (current_timestamp) = get_block_timestamp()

    with_attr error_message("Call option must be expired before it can be redeemed"):
        assert_lt(call_option.expiration_timestamp, current_timestamp)
    end

    let (caller_address) = get_caller_address()

    with_attr error_message("Only seller can redeem option"):
        assert caller_address = call_option.seller_address
    end

    with_attr error_message("Call is no longer open"):
        assert call_option.is_open = TRUE
    end

    ReentrancyGuard_start(option_id)

    let (local did_seller_refund_succeed) = IERC20.transfer(
        call_option.currency_address, call_option.seller_address, call_option.size)

    if did_seller_refund_succeed == TRUE:
        let new_call_option = CallOption_CallOption(
            id=call_option.id,
            expiration_timestamp=call_option.expiration_timestamp,
            fee=call_option.fee,
            size=call_option.size,
            strike_price=call_option.strike_price,
            currency_address=call_option.currency_address,
            oracle_key=call_option.oracle_key,
            buyer_address=call_option.buyer_address,
            seller_address=call_option.seller_address,
            did_buyer_initialize=call_option.did_buyer_initialize,
            did_seller_initialize=call_option.did_buyer_initialize,
            is_open=FALSE)
        CallOption_call_option_storage.write(call_option.id, new_call_option)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    ReentrancyGuard_end(option_id)

    with_attr error_message("Seller refund failed. State not updated, please try again"):
        assert did_seller_refund_succeed = TRUE
    end
    return ()
end

# Called by the buyer to exercise their call option
func CallOption_exercise_call_option{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(option_id : felt):
    alloc_locals

    let (call_option) = CallOption_call_option_storage.read(option_id)

    let (caller_address) = get_caller_address()

    with_attr error_message("Only buyer can exercise option"):
        assert caller_address = call_option.buyer_address
    end

    with_attr error_message("Call is no longer open"):
        assert call_option.is_open = TRUE
    end

    let (oracle_address) = CallOption_oracle_address_storage.read()
    let (price_felt, last_updated_timestamp) = IOracle.get_value(
        oracle_address, call_option.oracle_key)
    let (low, high) = split_64(price_felt)
    let price = Uint256(low, high)

    let (buyer_payout, seller_payout) = CallOption_calculate_payouts(
        call_option.size, call_option.strike_price, price)

    with_attr error_message("Buyer payout must be positive for call option strike to be executed"):
        let ZERO = Uint256(0, 0)
        uint256_signed_lt(ZERO, buyer_payout)
    end

    ReentrancyGuard_start(option_id)

    let (call_option_contract_address) = get_contract_address()
    let (local did_buyer_payout_succeed) = IERC20.transfer(
        call_option.currency_address, call_option.buyer_address, buyer_payout)
    let (local did_seller_payout_succeed) = IERC20.transfer(
        call_option.currency_address, call_option.seller_address, seller_payout)
    let did_payouts_succeed = did_buyer_payout_succeed * did_seller_payout_succeed

    if did_payouts_succeed == TRUE:
        let new_call_option = CallOption_CallOption(
            id=call_option.id,
            expiration_timestamp=call_option.expiration_timestamp,
            fee=call_option.fee,
            size=call_option.size,
            strike_price=call_option.strike_price,
            currency_address=call_option.currency_address,
            oracle_key=call_option.oracle_key,
            buyer_address=call_option.buyer_address,
            seller_address=call_option.seller_address,
            did_buyer_initialize=call_option.did_buyer_initialize,
            did_seller_initialize=call_option.did_buyer_initialize,
            is_open=FALSE)
        CallOption_call_option_storage.write(call_option.id, new_call_option)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    ReentrancyGuard_end(option_id)

    with_attr error_message("Buyer refund failed. State not updated, please try again"):
        assert did_payouts_succeed = TRUE
    end

    return ()
end

#
# Helpers
#

func CallOption_calculate_payouts{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        size : Uint256, strike_price : Uint256, price : Uint256) -> (
        buyer_payout : Uint256, seller_payout : Uint256):
    alloc_locals

    let (decimals) = CallOption_decimals_storage.read()
    let (multiplier) = pow(10, decimals)
    local normalizer : Uint256 = Uint256(multiplier, 0)
    let (price_delta) = uint256_sub(price, strike_price)
    let (profit) = mulDivDown(price_delta, size, normalizer)  # round down in the seller's favor
    let (buyer_payout) = mulDivDown(profit, normalizer, price)  # round down in the seller's favor
    let (seller_payout) = uint256_sub(size, buyer_payout)
    return (buyer_payout, seller_payout)
end
