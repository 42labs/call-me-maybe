%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.call_option.library import (
    CallOption_CallOptionSubmission, CallOption_CallOption, CallOption_intialize_call_option,
    CallOption_generate_call_option_id, CallOption_get_call_option, CallOption_register_call_option,
    CallOption_confirm_call_option, CallOption_cancel_call_option, CallOption_redeem_call_option,
    CallOption_exercise_call_option)

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        oracle_address : felt):
    CallOption_intialize_call_option(oracle_address)
    return ()
end

#
# Getters
@view
func get_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        option_id : felt) -> (call_option : CallOption_CallOption):
    let (call_option) = CallOption_get_call_option(option_id)
    return (call_option)
end

#
# Setters
#
@external
func generate_call_option_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (call_option_id : felt):
    let (call_option_id) = CallOption_generate_call_option_id()
    return (call_option_id)
end

@external
func register_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        call_option_submission : CallOption_CallOptionSubmission):
    CallOption_register_call_option(call_option_submission)
    return ()
end

@external
func confirm_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        call_option_submission : CallOption_CallOptionSubmission):
    CallOption_confirm_call_option(call_option_submission)
    return ()
end

@external
func cancel_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        option_id : felt):
    CallOption_cancel_call_option(option_id)
    return ()
end

@external
func redeem_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        option_id : felt):
    CallOption_redeem_call_option(option_id)
    return ()
end

@external
func exercise_call_option{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        option_id : felt):
    CallOption_exercise_call_option(option_id)
    return ()
end
