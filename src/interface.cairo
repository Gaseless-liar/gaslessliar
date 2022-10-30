%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.game import GameData

@contract_interface
namespace IGasLessLiar {
    func deposit(amount: Uint256) {
    }

    func withdraw(amount: Uint256) {
    }

    func get_deposit(user: felt) -> (amount: Uint256) {
    }

    func create_game(id: felt, entry_fee: Uint256, key_a, key_b) {
    }

    func set_a_user(game_id, sig: (felt, felt)) {
    }

    func set_b_user(game_id, sig: (felt, felt)) {
    }

    func get_game_data(game_id: felt) -> (game_data: GameData) {
    }

    func win_game_a(game_id: felt, sig: (felt, felt)) {
    }

    func win_game_b(game_id: felt, sig: (felt, felt)) {
    }

    func open_dispute_state_1(dispute, game_id, h1, sig: (felt, felt)) {
    }

    func close_dispute_state_1(dispute, game_id, prev_state_hash, s2, h1, sig: (felt, felt)) {
    }

    func open_dispute_state_2(
        dispute, game_id, prev_state_hash, s2, h1, sig: (felt, felt), prev_sig: (felt, felt)
    ) {
    }

    func close_dispute_state_2(
        dispute, game_id, prev_state_hash, s1, starting_card, sig: (felt, felt)
    ) {
    }

    func open_dispute_state_3(
        dispute,
        game_id,
        disp2_prev_state_hash,
        disp2_s2,
        disp2_h1,
        disp2_sig: (felt, felt),
        disp3_s1,
        disp3_starting_card,
        disp3_sig: (felt, felt),
    ) {
    }

    func close_dispute_state_3(dispute, ah0, ah1, ah2, ah3, seed_b, sig: (felt, felt)) {
    }

    func close_dispute(dispute) {
    }
}
