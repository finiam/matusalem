%lang starknet
from src.main import l1_address, set_l1_address, create_proposal, proposal_list, get_proposal
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc20.library import ERC20

const ADMIN = 1;
const ETH_ADDRESS = 0x049d36570d4e46f48e99674Bd3fcC84644dDD6B96F7C741b1562b82F9E004dc7;

@contract_interface
namespace Fund {
    func monthly_deposit(amount: Uint256) -> (success: felt) {
    }
}

@external
func __setup__() {
    %{ context.contract_address = deploy_contract("./src/main.cairo", [0x01]).contract_address %}

    return ();
}

@external
func test_create_proposal{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    let (prop_before) = get_proposal(341);
    assert prop_before.strategy_id = 0;

    create_proposal(341);

    let (prop) = get_proposal(341);
    assert prop.strategy_id = 341;

    return ();
}

@external
func test_set_l1_address{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    let (result_before) = l1_address.read();
    assert result_before = 0;

    set_l1_address(0x123);

    let (result_after) = l1_address.read();
    assert result_after = 0x123;
    return ();
}

@external
func test_cannot_set_null_l1_address{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let (result_before) = l1_address.read();
    assert result_before = 0;

    %{ expect_revert(error_message="L1 address cannot be null") %}
    set_l1_address(0);

    return ();
}
