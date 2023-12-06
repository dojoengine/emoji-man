// ---------------------------------------------------------------------
// This file contains the interface of the contract.
// ---------------------------------------------------------------------

#[starknet::interface]
trait IActions<TContractState> {
    fn spawn(self: @TContractState, rps: u8);
    fn move(self: @TContractState, dir: emojiman::models::Direction);
    fn cleanup(self: @TContractState);
}
