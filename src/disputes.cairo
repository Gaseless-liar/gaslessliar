%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp

@event
func dispute_opened(game_id: felt, dispute: felt) {
}

struct DisputeData {
    from_a: felt,
    game_id: felt,
    hash: felt,
    state: felt,
    expiry: felt,
}

@storage_var
func _dispute_data(dispute: felt) -> (dispute_data: DisputeData) {
}

@storage_var
func _dispute_state_1(dispute: felt) -> (h1: felt) {
}

struct DisputeData2 {
    h1: felt,
    s2: felt,
}

@storage_var
func _dispute_state_2(dispute: felt) -> (dispute_data2: DisputeData2) {
}
