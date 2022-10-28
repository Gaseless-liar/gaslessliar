%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from src.balances import decrease_balance

struct GameData {
    entry_fee: Uint256,

    key_a: felt,
    key_b: felt,

    user_a: felt,
    user_b: felt,
}

@storage_var
func games(id: felt) -> (game_data: GameData) {
}
