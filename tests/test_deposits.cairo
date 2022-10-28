%lang starknet
from src.main import deposit, withdraw, get_deposit
from starkware.cairo.common.cairo_builtins import HashBuiltin
from cairo_contracts.src.openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from src.interface import IGasLessLiar

@external
func __setup__() {
    %{
        context.eth_contract = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [123, 123, 20, 2**127, 2**127, 456]).contract_address
        context.gll_contract = deploy_contract("./src/main.cairo", [context.eth_contract]).contract_address
    %}
    return ();
}

@external
func test_deposits{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    local eth_contract;
    local gll_contract;
    %{
        ids.eth_contract = context.eth_contract
        ids.gll_contract = context.gll_contract
        stop_prank_eth = start_prank(456, context.eth_contract)
    %}

    let (deposited: Uint256) = IGasLessLiar.get_deposit(gll_contract, 456);
    assert_uint256_eq(deposited, Uint256(0, 0));

    local to_deposit: Uint256 = Uint256(0, 500);
    IERC20.approve(eth_contract, gll_contract, to_deposit);
    %{
        stop_prank_eth()
        stop_prank_gll = start_prank(456, context.gll_contract)
    %}

    IGasLessLiar.deposit(gll_contract, to_deposit);
    let (deposited: Uint256) = IGasLessLiar.get_deposit(gll_contract, 456);
    assert_uint256_eq(deposited, to_deposit);

    let half = Uint256(0, 250);
    IGasLessLiar.withdraw(gll_contract, half);
    let (deposited: Uint256) = IGasLessLiar.get_deposit(gll_contract, 456);
    assert_uint256_eq(deposited, half);

    %{ stop_prank_gll() %}

    return ();
}
