%lang starknet
from starkware.cairo.common.math import assert_le_felt, assert_not_equal
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_add
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash import hash2

from cairo_contracts.src.openzeppelin.token.erc20.IERC20 import IERC20

from src.balances import _token_addr, _balances, increase_balance, decrease_balance
from src.disputes import (
    dispute_opened,
    DisputeData,
    _dispute_data,
    _dispute_state_1,
    _dispute_state_2,
    DisputeData2,
)
from src.game import games, GameData

//
// Money
//

@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: Uint256) {
    // might be safe to remove depending on IERC20.transferFrom impl
    uint256_check(amount);

    // move funds
    let (caller) = get_caller_address();
    let (target) = get_contract_address();
    let (token_addr) = _token_addr.read();
    IERC20.transferFrom(token_addr, caller, target, amount);

    increase_balance(caller, amount);
    return ();
}

@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: Uint256) {
    // might be safe to remove depending on IERC20.transfer impl
    uint256_check(amount);

    // decrease balance and ensure new balance >= 0
    let (target) = get_caller_address();
    decrease_balance(target, amount);

    // move funds
    let (token_addr) = _token_addr.read();
    IERC20.transfer(token_addr, target, amount);
    return ();
}

@view
func get_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt) -> (
    amount: Uint256
) {
    let (deposit: Uint256) = _balances.read(user);
    return (deposit,);
}

// Game

@external
func create_game{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    id: felt, entry_fee: Uint256, key_a, key_b
) {
    // ensures a game with this id doesn't already exist, because key_a=0 is invalid
    let (current_game: GameData) = games.read(id);
    assert current_game.key_a = 0;
    games.write(id, GameData(entry_fee, key_a, key_b, 0, 0));
    return ();
}

@external
func set_a_user{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(game_id, sig: (felt, felt)) {
    let (game_data: GameData) = games.read(game_id);

    let (caller) = get_caller_address();
    verify_ecdsa_signature(caller, game_data.key_a, sig[0], sig[1]);
    decrease_balance(caller, game_data.entry_fee);
    games.write(
        game_id,
        GameData(game_data.entry_fee, game_data.key_a, game_data.key_b, caller, game_data.user_b),
    );
    return ();
}

@external
func set_b_user{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(game_id, sig: (felt, felt)) {
    let (game_data: GameData) = games.read(game_id);

    let (caller) = get_caller_address();
    verify_ecdsa_signature(caller, game_data.key_b, sig[0], sig[1]);
    decrease_balance(caller, game_data.entry_fee);
    games.write(
        game_id,
        GameData(game_data.entry_fee, game_data.key_a, game_data.key_b, game_data.user_a, caller),
    );
    return ();
}

@view
func get_game_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    game_id: felt
) -> (game_data: GameData) {
    let (game_data) = games.read(game_id);
    return (game_data,);
}

// Submit

// gives valid state1, expects valid state2
@external
func open_dispute_state_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute, game_id, h1, sig: (felt, felt)) {
    // validation
    let (game_data: GameData) = games.read(game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(game_id, h1);
    // we hash with state1
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 1);
    verify_ecdsa_signature(hash, game_data.key_a, sig[0], sig[1]);

    // ensure there is no existing data
    let (existing_data) = _dispute_data.read(dispute);
    assert existing_data.expiry = 0;

    // create the dispute, expiring in 5 minutes
    let (now) = get_block_timestamp();
    _dispute_data.write(dispute, DisputeData(TRUE, game_id, hash, 1, now + 600));
    dispute_opened.emit(game_id, dispute);

    // write the data required to close the dispute
    _dispute_state_1.write(dispute, h1);
    return ();
}

// gives valid state2 to close a dispute on a valid state1
@external
func close_dispute_state_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute, game_id, prev_state_hash, s2, h1, sig: (felt, felt)) {
    // validation
    let (game_data: GameData) = games.read(game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(game_id, prev_state_hash);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, s2);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, h1);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 2);
    verify_ecdsa_signature(hash, game_data.key_b, sig[0], sig[1]);

    // h = old(h)
    let (old_h1) = _dispute_state_1.read(dispute);
    assert h1 = old_h1;
    let (dispute_data) = _dispute_data.read(dispute);
    assert dispute_data.state = 1;
    _dispute_data.write(
        dispute,
        DisputeData(dispute_data.from_a, dispute_data.game_id, dispute_data.hash, dispute_data.state, 0),
    );

    return ();
}

// gives valid state2, expects valid state3
@external
func open_dispute_state_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute, game_id, prev_state_hash, s2, h1, sig: (felt, felt), prev_sig: (felt, felt)) {
    // validation
    let (game_data: GameData) = games.read(game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(game_id, prev_state_hash);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, s2);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, h1);
    // we hash with state2
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 2);
    verify_ecdsa_signature(hash, game_data.key_b, sig[0], sig[1]);
    // we ensure link to previous dispute
    verify_ecdsa_signature(prev_state_hash, game_data.key_a, prev_sig[0], prev_sig[1]);

    // ensure there is no existing data
    let (existing_data) = _dispute_data.read(dispute);
    assert existing_data.expiry = 0;

    // create the dispute, expiring in 5 minutes
    let (now) = get_block_timestamp();
    _dispute_data.write(dispute, DisputeData(FALSE, game_id, hash, 2, now + 600));
    dispute_opened.emit(game_id, dispute);

    // write the data required to close the dispute
    _dispute_state_2.write(dispute, DisputeData2(h1, s2));
    return ();
}

// gives valid state3 to close a dispute on a valid state2
@external
func close_dispute_state_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute, game_id, prev_state_hash, s1, starting_card, sig: (felt, felt)) {
    // validation
    let (game_data: GameData) = games.read(game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(game_id, prev_state_hash);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, s1);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, starting_card);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 3);
    verify_ecdsa_signature(hash, game_data.key_a, sig[0], sig[1]);

    // hash(s1) = old(h1)
    let (old_data: DisputeData2) = _dispute_state_2.read(dispute);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(s1, 0);
    assert hash = old_data.h1;

    // starting_card = hash(s1, old(s2))
    let (hash) = hash2{hash_ptr=pedersen_ptr}(s1, old_data.s2);
    assert starting_card = hash;

    let (dispute_data) = _dispute_data.read(dispute);
    assert dispute_data.state = 2;
    _dispute_data.write(
        dispute,
        DisputeData(dispute_data.from_a, dispute_data.game_id, dispute_data.hash, dispute_data.state, 0),
    );

    return ();
}

// gives valid state2 and state3, expects valid state4
@external
func open_dispute_state_3{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(
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
    // ensure b tx is signed
    let (game_data: GameData) = games.read(game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(game_id, disp2_prev_state_hash);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, disp2_s2);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, disp2_h1);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 2);
    verify_ecdsa_signature(hash, game_data.key_b, disp2_sig[0], disp2_sig[1]);

    // ensure a tx is signed
    let (hash_disp_3) = hash2{hash_ptr=pedersen_ptr}(game_id, hash);
    let (hash_disp_3) = hash2{hash_ptr=pedersen_ptr}(hash_disp_3, disp3_s1);
    let (hash_disp_3) = hash2{hash_ptr=pedersen_ptr}(hash_disp_3, disp3_starting_card);
    let (hash_disp_3) = hash2{hash_ptr=pedersen_ptr}(hash_disp_3, 3);

    verify_ecdsa_signature(hash_disp_3, game_data.key_a, disp3_sig[0], disp3_sig[1]);

    // hash(s1) = old(h1)
    let (hash) = hash2{hash_ptr=pedersen_ptr}(disp3_s1, 0);
    assert hash = disp2_h1;

    // starting_card = hash(s1, old(s2))
    let (hash) = hash2{hash_ptr=pedersen_ptr}(disp3_s1, disp2_s2);
    assert hash = disp3_starting_card;

    // write DisputeData
    let (existing_data) = _dispute_data.read(dispute);
    assert existing_data.expiry = 0;

    // create the dispute, expiring in 5 minutes
    let (now) = get_block_timestamp();
    _dispute_data.write(dispute, DisputeData(FALSE, game_id, hash_disp_3, 3, now + 600));
    dispute_opened.emit(game_id, dispute);

    return ();
}

// gives valid state4
@external
func close_dispute_state_3{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute, ah0, ah1, ah2, ah3, seed_b, sig: (felt, felt)) {
    let (dispute_data: DisputeData) = _dispute_data.read(dispute);
    assert dispute_data.state = 3;

    // validation
    let (game_data: GameData) = games.read(dispute_data.game_id);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(dispute_data.game_id, dispute_data.hash);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, ah0);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, ah1);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, ah2);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, ah3);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, seed_b);
    let (hash) = hash2{hash_ptr=pedersen_ptr}(hash, 4);
    verify_ecdsa_signature(hash, game_data.key_b, sig[0], sig[1]);
    // todo: log event so A can continue

    _dispute_data.write(
        dispute,
        DisputeData(dispute_data.from_a, dispute_data.game_id, dispute_data.hash, dispute_data.state, 0),
    );
    return ();
}

// gives reference to an opened and expired dispute to send funds to the issue creator
@external
func close_dispute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(dispute) {
    let (dispute_data) = _dispute_data.read(dispute);
    // expiry = 0 => dispute closed
    assert_not_equal(dispute_data.expiry, 0);

    // we ensure now >= expiry
    let (now) = get_block_timestamp();
    assert_le_felt(dispute_data.expiry, now);

    // redistribute tokens
    let (game_data) = games.read(dispute_data.game_id);
    tempvar target;
    if (dispute_data.from_a == TRUE) {
        target = game_data.user_a;
    } else {
        target = game_data.user_b;
    }
    let (token_addr) = _token_addr.read();
    let (res: Uint256, carry: felt) = uint256_add(game_data.entry_fee, game_data.entry_fee);
    assert carry = 0;
    IERC20.transfer(token_addr, target, res);

    return ();
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(token_addr) {
    _token_addr.write(token_addr);
    return ();
}
