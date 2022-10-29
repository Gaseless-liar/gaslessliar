%lang starknet
from src.main import deposit, withdraw, get_deposit
from starkware.cairo.common.cairo_builtins import HashBuiltin
from cairo_contracts.src.openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from src.interface import IGasLessLiar
from src.game import GameData

@external
func __setup__() {
    %{
        context.eth_contract = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [123, 123, 20, 0, 1000, 456]).contract_address
        context.gll_contract = deploy_contract("./src/main.cairo", [context.eth_contract]).contract_address
    %}
    return ();
}

// In these scenarios, A will play against B
// A will use private key 1 and B will use private key 2
// keys
const A_PUB = 874739451078007766457464989774322083649278607533249481151382481072868806602;
const B_PUB = 3324833730090626974525872402899302150520188025637965566623476530814354734325;

// Account addresses:
const A = 456;
const B = 789;

@external
func test_dispute1{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    local eth_contract;
    local gll_contract;
    %{
        ids.eth_contract = context.eth_contract
        ids.gll_contract = context.gll_contract
        stop_prank_eth = start_prank(ids.A, context.eth_contract)
    %}

    // Let's make A and B deposit enough to play
    local to_deposit: Uint256 = Uint256(0, 500);
    IERC20.transfer(eth_contract, B, to_deposit);
    IERC20.approve(eth_contract, gll_contract, to_deposit);
    %{
        stop_prank_eth()
        stop_prank_gll = start_prank(ids.A, context.gll_contract)
    %}

    IGasLessLiar.deposit(gll_contract, to_deposit);

    %{
        stop_prank_gll() 
        stop_prank_eth = start_prank(ids.B, context.eth_contract)
    %}
    IERC20.approve(eth_contract, gll_contract, to_deposit);
    %{
        stop_prank_eth()
        stop_prank_gll = start_prank(ids.B, context.gll_contract)
    %}
    IGasLessLiar.deposit(gll_contract, to_deposit);
    %{ stop_prank_gll() %}

    // We can then start a game (anyone can start it)
    IGasLessLiar.create_game(
        gll_contract, id=1, entry_fee=Uint256(0, 500), key_a=A_PUB, key_b=B_PUB
    );

    // A joins the game and pay
    local signature_a_1;
    local signature_a_2;
    %{
        stop_prank_gll = start_prank(ids.A, context.gll_contract)
        from starkware.crypto.signature.signature import sign
        ids.signature_a_1, ids.signature_a_2 = sign(ids.A, 1)
    %}
    IGasLessLiar.set_a_user(gll_contract, game_id=1, sig=(signature_a_1, signature_a_2));
    %{ stop_prank_gll() %}

    // B joins the game and pay
    local signature_b_1;
    local signature_b_2;
    %{
        stop_prank_gll = start_prank(ids.B, context.gll_contract)
        from starkware.crypto.signature.signature import sign
        ids.signature_b_1, ids.signature_b_2 = sign(ids.B, 2)
    %}
    IGasLessLiar.set_b_user(gll_contract, game_id=1, sig=(signature_b_1, signature_b_2));

    local h1;
    local state1_sig0;
    local state1_sig1;
    local hashed_state1;
    local s2;
    local h1;
    local state2_sig0;
    local state2_sig1;
    %{
        from starkware.crypto.signature.signature import sign
        from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
        import random
        P = 2**251 + 17*2**192 + 1

        # state1
        s1 = random.randrange(P)
        ids.h1 = pedersen_hash(s1, 0)
        state1 = { 'game_id' : 1, 'h1' : ids.h1, 'type' : 1}
        ids.hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        ids.state1_sig0, ids.state1_sig1 = sign(ids.hashed_state1, 1)

        # state2
        assert state1['game_id'] == 1
        assert state1['type'] == 1
        hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        ids.s2 = random.randrange(P)
        state2 = { 'game_id' : 1, 'prev_state_hash' : hashed_state1, 's2' : ids.s2, 'h1' : pedersen_hash(s1, 0), 'type' : 2}
        hashed_state2 = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(state2['game_id'], state2['prev_state_hash']), state2['s2']), state2['h1']), state2['type'])
        ids.state2_sig0, ids.state2_sig1 = sign(hashed_state2, 2)

        # state3
        assert state1['game_id'] == 1
        assert state1['type'] == 1
        assert state2['h1'] == state1['h1']
        hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        assert hashed_state1 == state2['prev_state_hash']
        hashed_state2 = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(state2['game_id'], state2['prev_state_hash']), state2['s2']), state2['h1']), state2['type'])
        state3 = { 'game_id' : 1, 'prev_state_hash' : hashed_state2, 's1' : s1, 'starting_card' : pedersen_hash(s1, state2['s2']), 'type' : 3}

        warp(1, context.gll_contract)
    %}

    // let's open and close a dispute 1
    IGasLessLiar.open_dispute_state_1(gll_contract, 'dispute_1', 1, h1, (state1_sig0, state1_sig1));
    IGasLessLiar.close_dispute_state_1(
        gll_contract, 'dispute_1', 1, hashed_state1, s2, h1, (state2_sig0, state2_sig1)
    );

    // let's reopen it and wait (we could forbid reopening it in the future but let's keep it that way for the hackathon)
    IGasLessLiar.open_dispute_state_1(gll_contract, 'dispute_1', 1, h1, (state1_sig0, state1_sig1));
    %{ warp(1200, context.gll_contract) %}

    IGasLessLiar.close_dispute(gll_contract, 'dispute_1');
    let (a_bal: Uint256) = IERC20.balanceOf(eth_contract, A);
    assert_uint256_eq(a_bal, Uint256(0, 1000));

    let (b_bal: Uint256) = IERC20.balanceOf(eth_contract, B);
    assert_uint256_eq(b_bal, Uint256(0, 0));

    return ();
}

@external
func test_dispute2{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    local eth_contract;
    local gll_contract;
    %{
        ids.eth_contract = context.eth_contract
        ids.gll_contract = context.gll_contract
        stop_prank_eth = start_prank(ids.A, context.eth_contract)
    %}

    // Let's make A and B deposit enough to play
    local to_deposit: Uint256 = Uint256(0, 500);
    IERC20.transfer(eth_contract, B, to_deposit);
    IERC20.approve(eth_contract, gll_contract, to_deposit);
    %{
        stop_prank_eth()
        stop_prank_gll = start_prank(ids.A, context.gll_contract)
    %}

    IGasLessLiar.deposit(gll_contract, to_deposit);

    %{
        stop_prank_gll() 
        stop_prank_eth = start_prank(ids.B, context.eth_contract)
    %}
    IERC20.approve(eth_contract, gll_contract, to_deposit);
    %{
        stop_prank_eth()
        stop_prank_gll = start_prank(ids.B, context.gll_contract)
    %}
    IGasLessLiar.deposit(gll_contract, to_deposit);
    %{ stop_prank_gll() %}

    // We can then start a game (anyone can start it)
    IGasLessLiar.create_game(
        gll_contract, id=1, entry_fee=Uint256(0, 500), key_a=A_PUB, key_b=B_PUB
    );

    // A joins the game and pay
    local signature_a_1;
    local signature_a_2;
    %{
        stop_prank_gll = start_prank(ids.A, context.gll_contract)
        from starkware.crypto.signature.signature import sign
        ids.signature_a_1, ids.signature_a_2 = sign(ids.A, 1)
    %}
    IGasLessLiar.set_a_user(gll_contract, game_id=1, sig=(signature_a_1, signature_a_2));
    %{ stop_prank_gll() %}

    // B joins the game and pay
    local signature_b_1;
    local signature_b_2;
    %{
        stop_prank_gll = start_prank(ids.B, context.gll_contract)
        from starkware.crypto.signature.signature import sign
        ids.signature_b_1, ids.signature_b_2 = sign(ids.B, 2)
    %}
    IGasLessLiar.set_b_user(gll_contract, game_id=1, sig=(signature_b_1, signature_b_2));

    local h1;
    local state1_sig0;
    local state1_sig1;
    local hashed_state1;
    local s2;
    local h1;
    local state2_sig0;
    local state2_sig1;
    local hashed_state2;
    local s1;
    local starting_card;
    local state3_sig0;
    local state3_sig1;
    %{
        from starkware.crypto.signature.signature import sign
        from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
        import random
        P = 2**251 + 17*2**192 + 1

        # state1
        s1 = random.randrange(P)
        ids.h1 = pedersen_hash(s1, 0)
        state1 = { 'game_id' : 1, 'h1' : ids.h1, 'type' : 1}
        ids.hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        ids.state1_sig0, ids.state1_sig1 = sign(ids.hashed_state1, 1)

        # state2
        assert state1['game_id'] == 1
        assert state1['type'] == 1
        hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        ids.s2 = random.randrange(P)
        state2 = { 'game_id' : 1, 'prev_state_hash' : hashed_state1, 's2' : ids.s2, 'h1' : pedersen_hash(s1, 0), 'type' : 2}
        ids.hashed_state2 = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(state2['game_id'], state2['prev_state_hash']), state2['s2']), state2['h1']), state2['type'])
        ids.state2_sig0, ids.state2_sig1 = sign(ids.hashed_state2, 2)

        # state3
        assert state1['game_id'] == 1
        assert state1['type'] == 1
        assert state2['h1'] == state1['h1']
        hashed_state1 = pedersen_hash(pedersen_hash(state1['game_id'], state1['h1']), state1['type'])
        assert hashed_state1 == state2['prev_state_hash']
        hashed_state2 = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(state2['game_id'], state2['prev_state_hash']), state2['s2']), state2['h1']), state2['type'])
        ids.s1 = s1
        ids.starting_card = pedersen_hash(s1, state2['s2'])
        state3 = { 'game_id' : 1, 'prev_state_hash' : hashed_state2, 's1' : s1, 'starting_card' : ids.starting_card, 'type' : 3}
        hashed_state3 = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(state3['game_id'], state3['prev_state_hash']), state3['s1']), state3['starting_card']), state3['type'])
        ids.state3_sig0, ids.state3_sig1 = sign(hashed_state3, 1)
        warp(1, context.gll_contract)
    %}

    // let's open and close a dispute 1
    IGasLessLiar.open_dispute_state_2(
        gll_contract, 'dispute_1', 1, hashed_state1, s2, h1, (state2_sig0, state2_sig1)
    );
    IGasLessLiar.close_dispute_state_2(
        gll_contract, 'dispute_1', 1, hashed_state2, s1, starting_card, (state3_sig0, state3_sig1)
    );

    return ();
}
