%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin

#
# Getters
#

@view
func get_value{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(key : felt) -> (
        value : felt, last_updated_timestamp : felt):
    let (block_timestamp) = get_block_timestamp()
    return (42, block_timestamp)
end

@view
func get_decimals() -> (decimals):
    return (18)
end
