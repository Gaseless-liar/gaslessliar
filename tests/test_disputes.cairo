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
        context.eth_contract = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [123, 123, 20, 2**127, 2**127, 456]).contract_address
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
func test_game_creation{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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
    %{ stop_prank_gll() %}

    let (game_data: GameData) = IGasLessLiar.get_game_data(gll_contract, game_id=1);
    assert game_data.user_a = A;
    assert game_data.user_b = B;

    return ();
}
