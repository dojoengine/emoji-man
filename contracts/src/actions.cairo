use emojiman::models::{Direction};

const INITIAL_ENERGY: u8 = 10;
const RENEWED_ENERGY: u8 = 3;
const MOVE_ENERGY_COST: u8 = 1;
const X_RANGE: u128 = 50; // These need to be u128
const Y_RANGE: u128 = 50; // These need to be u128
const ORIGIN_OFFSET: u8 = 100; // Origin offset

// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn spawn(self: @TContractState, rps: u8);
    fn move(self: @TContractState, dir: Direction);
    fn cleanup(self: @TContractState);
    fn tick(self: @TContractState);
}

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use debug::PrintTrait;
    use emojiman::models::{
        GAME_DATA_KEY, GameData, Direction, Vec2, Position, PlayerAtPosition, RPSType, Energy,
        PlayerID, PlayerAddress
    };
    use emojiman::utils::next_position;
    use super::{
        INITIAL_ENERGY, RENEWED_ENERGY, MOVE_ENERGY_COST, X_RANGE, Y_RANGE, ORIGIN_OFFSET, IActions
    };
    use integer::{u128s_from_felt252, U128sFromFelt252Result, u128_safe_divmod};

    // region player id assignment
    fn assign_player_id(world: IWorldDispatcher, num_players: u8, player: ContractAddress) -> u8 {
        let id = num_players;
        set!(world, (PlayerID { player, id }, PlayerAddress { player, id }));
        id
    }
    // endregion player id assignment

    // region player position
    fn clear_player_at_position(world: IWorldDispatcher, x: u8, y: u8) {
        // Set no player at position
        set!(world, (PlayerAtPosition { x, y, id: 0 }));
    }

    fn player_at_position(world: IWorldDispatcher, x: u8, y: u8) -> u8 {
        get!(world, (x, y), (PlayerAtPosition)).id
    }
    // endregion player position

    // region game ops
    fn player_position_and_energy(world: IWorldDispatcher, id: u8, x: u8, y: u8, amt: u8) {
        set!(world, (PlayerAtPosition { x, y, id }, Position { x, y, id }, Energy { id, amt },));
    }

    fn player_dead(world: IWorldDispatcher, id: u8) {
        let pos = get!(world, id, (Position));
        let empty_player = starknet::contract_address_const::<0>();

        let id_felt: felt252 = id.into();
        let entity_keys = array![id_felt].span();
        let player = get!(world, id, (PlayerAddress)).player;
        let player_felt: felt252 = player.into();
        // Remove player address and ID mappings
        world.delete_entity('PlayerID', array![player_felt].span());
        world.delete_entity('PlayerAddress', entity_keys);

        set!(world, (PlayerID { player, id: 0 }));
        set!(world, (Position { id, x: 0, y: 0 }));

        // Remove player components
        world.delete_entity('RPSType', entity_keys);
        world.delete_entity('Position', entity_keys);
        world.delete_entity('Energy', entity_keys);
    }

    // panics if players are of same type (move cancelled)
    // if the player dies returns false
    // if the player kills the other player returns true
    fn encounter(world: IWorldDispatcher, player: u8, adversary: u8) -> bool {
        let ply_type = get!(world, player, (RPSType)).rps;
        let adv_type = get!(world, adversary, (RPSType)).rps;
        if encounter_win(ply_type, adv_type) {
            // adversary dies
            player_dead(world, adversary);
            true
        } else {
            // player dies
            player_dead(world, player);
            false
        }
    }

    fn encounter_win(ply_type: u8, adv_type: u8) -> bool {
        assert(adv_type != ply_type, 'occupied by same type');
        if (ply_type == 'r' && adv_type == 's')
            || (ply_type == 'p' && adv_type == 'r')
            || (ply_type == 's' && adv_type == 'p') {
            return true;
        }
        false
    }

    fn spawn_coords(world: IWorldDispatcher, player: felt252, mut salt: felt252) -> (u8, u8) {
        let mut x = 10;
        let mut y = 10;
        loop {
            let hash = pedersen::pedersen(player, salt);
            let rnd_seed = match u128s_from_felt252(hash) {
                U128sFromFelt252Result::Narrow(low) => low,
                U128sFromFelt252Result::Wide((high, low)) => low,
            };
            let (rnd_seed, x_) = u128_safe_divmod(rnd_seed, X_RANGE.try_into().unwrap());
            let (rnd_seed, y_) = u128_safe_divmod(rnd_seed, Y_RANGE.try_into().unwrap());
            let x_: felt252 = x_.into();
            let y_: felt252 = y_.into();

            x = ORIGIN_OFFSET + x_.try_into().unwrap();
            y = ORIGIN_OFFSET + y_.try_into().unwrap();
            let occupied = player_at_position(world, x, y);
            if occupied == 0 {
                break;
            } else {
                salt += 1; // Try new salt
            }
        };
        (x, y)
    }
    // endregion game ops

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        // Spawns the player on to the map
        fn spawn(self: @ContractState, rps: u8) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut game_data = get!(world, GAME_DATA_KEY, (GameData));
            game_data.number_of_players += 1;
            let number_of_players = game_data.number_of_players; // id starts at 1
            set!(world, (game_data));

            assert(rps == 'r' || rps == 'p' || rps == 's', 'only r, p or s type allowed');

            let mut id = get!(world, player, (PlayerID)).id;

            if id == 0 {
                // Player not already spawned, prepare ID to assign
                id = assign_player_id(world, number_of_players, player);
            } else {
                // Player already exists, clear old position for new spawn
                let pos = get!(world, id, (Position));
                clear_player_at_position(world, pos.x, pos.y);
            }

            set!(world, (RPSType { id, rps }));

            let (x, y) = spawn_coords(world, player.into(), id.into()); // Pick randomly
            player_position_and_energy(world, id, x, y, INITIAL_ENERGY);
        }

        // Queues move for player to be processed later
        fn move(self: @ContractState, dir: Direction) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            // player id
            let id = get!(world, player, (PlayerID)).id;

            let (pos, energy) = get!(world, id, (Position, Energy));

            assert(energy.amt >= MOVE_ENERGY_COST, 'Not enough energy');

            // Clear old position
            clear_player_at_position(world, pos.x, pos.y);

            let Position{id, x, y } = next_position(pos, dir);

            let max_x: felt252 = ORIGIN_OFFSET.into() + X_RANGE.into();
            let max_y: felt252 = ORIGIN_OFFSET.into() + Y_RANGE.into();

            assert(
                x <= max_x.try_into().unwrap() && y <= max_y.try_into().unwrap(), 'Out of bounds'
            );

            let adversary = player_at_position(world, x, y);
            if 0 == adversary {
                // Empty cell, move
                player_position_and_energy(world, id, x, y, energy.amt - MOVE_ENERGY_COST);
            } else {
                if encounter(world, id, adversary) {
                    // Move the player
                    player_position_and_energy(world, id, x, y, energy.amt - MOVE_ENERGY_COST);
                }
            }
        }

        fn cleanup(self: @ContractState) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            // reset player count
            let mut game_data = get!(world, GAME_DATA_KEY, (GameData));
            game_data.number_of_players = 0;
            set!(world, (game_data));

            // Kill off all players
            let mut i = 1;
            loop {
                if i > 20 {
                    break;
                }
                player_dead(world, i);
                i += 1;
            };
        }

        // Process player move queues
        // @TODO do the killing
        // @TODO update player entities
        // @TODO keep score
        fn tick(self: @ContractState) {}
    }
}

#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;
    use debug::PrintTrait;

    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // import test utils
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // import models
    use emojiman::models::{
        position, player_at_position, rps_type, energy, player_id, player_address,
    };
    use emojiman::models::{
        Position, RPSType, Energy, Direction, Vec2, PlayerAtPosition, PlayerID, PlayerAddress,
    };

    // import actions
    use super::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use super::{INITIAL_ENERGY, RENEWED_ENERGY, MOVE_ENERGY_COST};

    fn init() -> (ContractAddress, IWorldDispatcher, IActionsDispatcher) {
        let caller = starknet::contract_address_const::<'jon'>();
        // This sets caller for current function, but not passed to called contract functions
        starknet::testing::set_caller_address(caller);
        // This sets caller for called contract functions.
        starknet::testing::set_contract_address(caller);
        // models
        let mut models = array![
            player_at_position::TEST_CLASS_HASH,
            position::TEST_CLASS_HASH,
            energy::TEST_CLASS_HASH,
            rps_type::TEST_CLASS_HASH,
            player_id::TEST_CLASS_HASH,
            player_address::TEST_CLASS_HASH,
        ];

        // deploy world with models
        let world = spawn_test_world(models);

        // deploy systems contract
        let contract_address = world
            .deploy_contract('actions', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions = IActionsDispatcher { contract_address };
        (caller, world, actions)
    }

    #[test]
    #[available_gas(30000000)]
    fn spawn_test() {
        let (caller, world, actions_) = init();

        actions_.spawn('r');

        // Get player ID
        let player_id = get!(world, caller, (PlayerID)).id;
        assert(1 == player_id, 'incorrect id');

        // Get player from id
        let (position, rps_type, energy) = get!(world, player_id, (Position, RPSType, Energy));
        assert(0 < position.x, 'incorrect position.x');
        assert(0 < position.y, 'incorrect position.y');
        assert('r' == rps_type.rps, 'incorrect rps');
        assert(INITIAL_ENERGY == energy.amt, 'incorrect energy');
    }

    #[test]
    #[available_gas(30000000)]
    fn dead_test() {
        let (caller, world, actions_) = init();

        actions_.spawn('r');
        // Get player ID
        let player_id = get!(world, caller, (PlayerID)).id;
        actions::player_dead(world, player_id);

        // Get player from id
        let (position, rps_type, energy) = get!(world, player_id, (Position, RPSType, Energy));
        assert(0 == position.x, 'incorrect position.x');
        assert(0 == position.y, 'incorrect position.y');
    // assert(0 == energy.amt, 'incorrect energy');
    }

    #[test]
    #[available_gas(30000000)]
    fn random_spawn_test() {
        let (caller, world, actions_) = init();

        actions_.spawn('r');
        // Get player ID
        let pos_p1 = get!(world, get!(world, caller, (PlayerID)).id, (Position));

        let caller = starknet::contract_address_const::<'jim'>();
        starknet::testing::set_contract_address(caller);
        actions_.spawn('r');
        // Get player ID
        let pos_p2 = get!(world, get!(world, caller, (PlayerID)).id, (Position));

        assert(pos_p1.x != pos_p2.x, 'spawn pos.x same');
        assert(pos_p1.y != pos_p2.y, 'spawn pos.x same');
    }

    #[test]
    #[available_gas(30000000)]
    fn random_duplicate_spawn_test() {
        let (caller, world, actions_) = init();

        let id = 16;
        let (x, y) = actions::spawn_coords(world, caller.into(), id);

        // Simulate player #5 on that location
        set!(world, (PlayerAtPosition { x, y, id: 5 }));

        let (x_, y_) = actions::spawn_coords(world, caller.into(), id);

        assert(x != x_, 'spawn pos.x same');
        assert(y != y_, 'spawn pos.x same');
    }

    #[test]
    #[available_gas(30000000)]
    fn moves_test() {
        let (caller, world, actions_) = init();

        actions_.spawn('r');

        // Get player ID
        let player_id = get!(world, caller, (PlayerID)).id;
        assert(1 == player_id, 'incorrect id');

        let (spawn_pos, spawn_energy) = get!(world, player_id, (Position, Energy));

        actions_.move(Direction::Up);
        // Get player from id
        let (pos, energy) = get!(world, player_id, (Position, Energy));

        assert(energy.amt == spawn_energy.amt - MOVE_ENERGY_COST, 'incorrect energy');
        assert(spawn_pos.x == pos.x, 'incorrect position.x');
        assert(spawn_pos.y - 1 == pos.y, 'incorrect position.y');
    }

    #[test]
    #[available_gas(30000000)]
    fn player_at_position_test() {
        let (caller, world, actions_) = init();

        actions_.spawn('r');

        // Get player ID
        let player_id = get!(world, caller, (PlayerID)).id;

        // Get player position
        let Position{x, y, id } = get!(world, player_id, Position);

        // Player should be at position
        assert(actions::player_at_position(world, x, y) == player_id, 'player should be at pos');

        // Player moves
        actions_.move(Direction::Up);

        // Player shouldn't be at old position
        assert(actions::player_at_position(world, x, y) == 0, 'player should not be at pos');

        // Get new player position
        let Position{x, y, id } = get!(world, player_id, Position);

        // Player should be at new position
        assert(actions::player_at_position(world, x, y) == player_id, 'player should be at pos');
    }

    #[test]
    #[available_gas(30000000)]
    fn encounter_test() {
        let (caller, world, actions_) = init();
        assert(false == actions::encounter_win('r', 'p'), 'R v P should lose');
        assert(true == actions::encounter_win('r', 's'), 'R v S should win');
        assert(false == actions::encounter_win('s', 'r'), 'S v R should lose');
        assert(true == actions::encounter_win('s', 'p'), 'S v P should win');
        assert(false == actions::encounter_win('p', 's'), 'P v S should lose');
        assert(true == actions::encounter_win('p', 'r'), 'P v R should win');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic()]
    fn encounter_rock_tie_panic() {
        actions::encounter_win('r', 'r');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic()]
    fn encounter_paper_tie_panic() {
        actions::encounter_win('p', 'p');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic()]
    fn encounter_scissor_tie_panic() {
        actions::encounter_win('s', 's');
    }
}
