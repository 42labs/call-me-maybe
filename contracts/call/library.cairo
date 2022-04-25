%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.math import assert_lt, assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.erc20.IERC20 import IERC20

namespace Call:
    #
    # Structs
    #
    struct CallOptionSubmission:
        member id : felt  # incrementing ID that also acts as a Nonce
        member expiration_timestamp : felt  # UTC, epoch
        member fee : felt  # fee in currency, with 18 decimals (because ETH)
        member size : felt  # size of the option (amount of currency)
        member currency_address : felt  # currency address (for the fee and option denomination)
        member strike_price : felt  # strike price in currency/USD
    end

    struct CallOption:
        member id : felt
        member expiration_timestamp : felt
        member fee : felt
        member size : felt
        member currency_address : felt
        member strike_price : felt
        member buyer_address : felt
        member seller_address : felt
        member did_buyer_initialize : felt  # Boolean, TRUE iff buyer has submitted data and fee
        member did_seller_initialize : felt  # Boolean, TRUE iff seller has submitted data and margin
        member is_canceled : felt  # Boolean, TRUE iff buyer submitted a cancel request before the seller initialized
    end

    #
    # Consts
    #
    const DECIMALS = 18

    #
    # Storage
    #
    @storage_var
    func next_call_option_id_storage() -> (next_call_option_id : felt):
    end

    @storage_var
    func call_option_storage(id : felt) -> (call_option : CallOption):
    end

    @storage_var
    func get_decimals() -> (decimals : felt):
    end

    #
    # Initializers
    #
    func intialize_decimals():
        get_decimals.write(DECIMALS)
        return ()
    end

    #
    # Getters
    #
    func generate_call_option_id() -> (call_option_id : felt):
        let (call_option_id) = next_call_option_id_storage.read()
        let next_call_option_id = call_option_id + 1
        next_call_option_id_storage.write(next_call_option_id)
        return (call_option_id)
    end

    func get_call_option(option_id : felt) -> (call_option : felt):
        let (call_option) = call_option_storage.read(option_id)
        return (call_option)
    end

    #
    # Setters
    #

    # Called by buyer to register the call option
    func register_call_option(call_option_submission : CallOptionSubmission):
        let (existing_call_option) = get_call_option(call_option_submission.id)

        with_attr error_message("Call already registered"):
            assert existing_call_option.expiration_timestamp = 0
        end

        let (current_timestamp) = get_block_timestamp()

        with_attr error_message("Expiration timestamp must be in the future"):
            assert_lt(current_timestamp, call_option_submission.expiration_timestamp)
        end

        let (buyer_address) = get_caller_address()

        with_attr error_message("Buyer must register"):
            assert buyer_address = call_option_submission.buyer_address
        end

        # Pull in fee from buyer
        let (call_option_contract_address) = get_contract_address()
        let (did_buyer_pay) = IERC20.transferFrom(
            call_option.currency_address,
            buyer_address,
            call_option_contract_address,
            call_option_submission.fee)

        with_attr error_message("Buyer fee payment failed"):
            assert did_buyer_pay = TRUE
        end

        let (call_option) = CallOption(
            id=call_option_submission.id,
            expiration_timestamp=call_option_submission.expiration_timestamp,
            fee=call_option_submission.fee,
            size=call_option_submission.size,
            currency_address=call_option_submission.currency_address,
            strike_price=call_option_submission.strike_price,
            buyer_address=buyer_address,
            seller_address=0,
            did_buyer_initialize=TRUE,
            did_seller_initialize=FALSE,
            is_canceled=FALSE)

        call_option_storage.write(call_option.id, call_option)
        return ()
    end

    # Called by seller to confirm the call option
    func confirm_call_option(call_option_submission : CallOptionSubmission):
        let (call_option) = call_option_storage.read(call_option_submission.id)

        let (current_timestamp) = get_block_timestamp()

        let (seller_address) = get_caller_address()

        with_attr error_message("Expiration timestamp must be in the future"):
            assert_lt(current_timestamp, call_option_submission.expiration_timestamp)
        end

        with_attr error_message("Buyer must register call option first"):
            assert_not_equal(call_option.expiration_timestamp, 0)
            assert call_option.did_buyer_initialize = TRUE
        end

        with_attr error_message("Call has been canceled"):
            assert call_option.is_canceled = FALSE
        end

        with_attr error_message("Call submission does not match the buyer's submission"):
            assert call_option.expiration_timestamp = call_option_submission.expiration_timestamp
            assert call_option.fee = call_option_submission.fee
            assert call_option.size = call_option_submission.size
            assert call_option.currency_address = call_option_submission.currency_address
            assert call_option.strike_price = call_option_submission.strike_price
        end

        # Pull in collateral from seller
        let (call_option_contract_address) = get_contract_address()
        let (did_seller_deposit) = IERC20.transferFrom(
            call_option.currency_address,
            seller_address,
            call_option_address,
            call_option_submission.size)

        with_attr error_message("Seller deposit failed"):
            assert did_seller_deposit = TRUE
        end

        let (new_call_option) = CallOption(
            id=call_option.id,
            expiration_timestamp=call_option.expiration_timestamp,
            fee=call_option.fee,
            size=call_option.size,
            currency_address=call_option.currency_address,
            strike_price=call_option.strike_price,
            buyer_address=call_option.buyer_address,
            seller_address=seller_address,
            did_buyer_initialize=call_option.did_buyer_initialize,
            did_seller_initialize=TRUE,
            is_canceled=FALSE)
        call_option_storage.write(new_call_option)
    end

    # Called by the buyer if the seller hasn't submitted yet and they want to cancel
    func cancel_call_option(option_id : felt):
        let (call_option) = get_call_option(option_id)
        let (caller_address) = get_caller_address()

        with_attr error_message("Only buyer can cancel call option"):
            assert caller_address = call_option.buyer_address
        end

        let (new_call_option) = CallOption(
            id=call_option.id,
            expiration_timestamp=call_option.expiration_timestamp,
            fee=call_option.fee,
            size=call_option.size,
            currency_address=call_option.currency_address,
            strike_price=call_option.strike_price,
            buyer_address=call_option.buyer_address,
            seller_address=call_option.seller_address,
            did_buyer_initialize=call_option.did_buyer_initialize,
            did_seller_initialize=call_option.did_buyer_initialize,
            is_canceled=TRUE)
        call_option_storage.write(new_call_option)

        # Send buyer back their fee
        # TODO: minus gas costs?
        let (call_option_contract_address) = get_contract_address()
        let (did_buyer_refund_succeed) = IERC20.transfer(
            call_option.currency_address, call_option.buyer_address, call_option.fee)

        with_attr error_message("Buyer refund failed, please try again"):
            assert did_buyer_refund_succeed = TRUE
        end

        return ()
    end

    # Called by the buyer to exercise their call option
    func exercise_call_option(option_id : felt):
        let (call_option) = call_option_storage.read(option_id)

        let (caller_address) = get_caller_address()

        with_attr error_message("Only buyer can exercise option"):
            assert caller_address = call_option.buyer_address
        end

        # TODO: Get price from oracle, calculate net payout and send to buyer, send the rest to the seller
    end

    # Called by the seller to redeem the call if the option has expired and was not exercised
    func redeem_call_option(option_id : felt):
        let (call_option) = call_option_storage.read(option_id)
        let (current_timestamp) = get_block_timestamp()

        with_attr error_message("Call option must be expired before it can be redeemed"):
            assert_lt(call_option.expiration_timestamp, current_timestamp)
        end

        let (caller_address) = get_caller_address()

        with_attr error_message("Only seller can redeem option"):
            assert caller_address = call_option.seller_address
        end

        # TODO: Return collateral to seller
    end
end
