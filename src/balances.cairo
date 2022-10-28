%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le_felt
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_add,
    uint256_sub,
    assert_uint256_le,
)

@storage_var
func _token_addr() -> (token_name: felt) {
}

@storage_var
func _balances(user: felt) -> (amount: Uint256) {
}

func decrease_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt, amount: Uint256
) {
    let (existing: Uint256) = _balances.read(user);
    with_attr error_message("You didn't deposit enough for this operation.") {
        assert_uint256_le(amount, existing);
    }
    let (new_bal) = uint256_sub(existing, amount);
    _balances.write(user, new_bal);
    return ();
}

func increase_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt, amount: Uint256
) {
    let (existing: Uint256) = _balances.read(user);
    let (added: Uint256, carry) = uint256_add(existing, amount);
    assert carry = 0;
    _balances.write(user, added);
    return ();
}
