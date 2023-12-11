//---------------------------------------------------------------------------------------------
// *Actions Contract*
// This contract handles all the actions that can be performed by the user
// Typically you group functions that require similar authentication into a single contract
// For this demo we are keeping all the functions in a single contract
//---------------------------------------------------------------------------------------------

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use debug::PrintTrait;
    use cubit::f128::procgen::simplex3;
    use cubit::f128::types::fixed::FixedTrait;
    use cubit::f128::types::vec3::Vec3Trait;

    // import actions
    use emojiman::interface::IActions;

    // import models
    use emojiman::models::{
        GAME_DATA_KEY, GameData, Direction, Vec2, Position, PlayerAtPosition, RPSType, Energy,
        PlayerID, PlayerAddress
    };

    // import utils
    use emojiman::utils::next_position;

    // import config
    use emojiman::config::{
        INITIAL_ENERGY, RENEWED_ENERGY, MOVE_ENERGY_COST, X_RANGE, Y_RANGE, ORIGIN_OFFSET, MAP_AMPLITUDE
    };

    // import integer
    use integer::{u128s_from_felt252, U128sFromFelt252Result, u128_safe_divmod};

    // resource of world
    const DOJO_WORLD_RESOURCE: felt252 = 0;

    // ---------------------------------------------------------------------------------------------
    // ---------------------------------------------------------------------------------------------
    // --------- EXTERNALS -------------------------------------------------------------------------
    // These functions are called by the user and are exposed to the public
    // ---------------------------------------------------------------------------------------------

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        // Spawns the player on to the map
        fn spawn(self: @ContractState, rps: u8) {
            // world dispatcher
            let world = self.world_dispatcher.read();

            // player address
            let player = get_caller_address();

            // game data
            let mut game_data = get!(world, GAME_DATA_KEY, (GameData));

            // increment player count
            game_data.number_of_players += 1;

            // NOTE: save game_data model with the set! macro
            set!(world, (game_data));

            // assert rps type
            assert(rps == 'r' || rps == 'p' || rps == 's', 'only r, p or s type allowed');

            // get player id 
            let mut player_id = get!(world, player, (PlayerID)).id;

            // if player id is 0, assign new id
            if player_id == 0 {
                // Player not already spawned, prepare ID to assign
                player_id = assign_player_id(world, game_data.number_of_players, player);
            } else {
                // Player already exists, clear old position for new spawn
                let pos = get!(world, player_id, (Position));
                clear_player_at_position(world, pos.x, pos.y);
            }

            // set player type
            set!(world, (RPSType { id: player_id, rps }));

            // spawn on random position
            let (x, y) = spawn_coords(world, player.into(), player_id.into());

            // set player position
            player_position_and_energy(world, player_id, x, y, INITIAL_ENERGY);
        }

        // Queues move for player to be processed later
        fn move(self: @ContractState, dir: Direction) {
            // world dispatcher
            let world = self.world_dispatcher.read();

            // player address
            let player = get_caller_address();

            // player id
            let id = get!(world, player, (PlayerID)).id;

            // player position and energy
            let (pos, energy) = get!(world, id, (Position, Energy));

            // Clear old position
            clear_player_at_position(world, pos.x, pos.y);

            // Get new position
            let Position{id, x, y } = next_position(pos, dir);

            // Get max x and y
            let max_x: felt252 = ORIGIN_OFFSET.into() + X_RANGE.into();
            let max_y: felt252 = ORIGIN_OFFSET.into() + Y_RANGE.into();

            // assert max x and y
            assert(
                x <= max_x.try_into().unwrap() && y <= max_y.try_into().unwrap(), 'Out of bounds'
            );

            // resolve encounter
            let adversary = player_at_position(world, x, y);

            let tile = tile_at_position(x - ORIGIN_OFFSET.into(), y - ORIGIN_OFFSET.into());
            let mut move_energy_cost = MOVE_ENERGY_COST;
            if tile == 3 {
                // Use more energy to go through ocean tiles
                move_energy_cost = MOVE_ENERGY_COST * 3;
            }

            // assert energy
            assert(energy.amt >= move_energy_cost, 'Not enough energy');

            if 0 == adversary {
                // Empty cell, move
                player_position_and_energy(world, id, x, y, energy.amt - move_energy_cost);
            } else {
                if encounter(world, id, adversary) {
                    // Move the player
                    player_position_and_energy(world, id, x, y, energy.amt - move_energy_cost);
                }
            }
        }

        // ----- ADMIN FUNCTIONS -----
        // These functions are only callable by the owner of the world
        fn cleanup(self: @ContractState) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            assert(
                world.is_owner(get_caller_address(), DOJO_WORLD_RESOURCE), 'only owner can call'
            );

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
    }

    // ---------------------------------------------------------------------------------------------
    // ---------------------------------------------------------------------------------------------
    // --------- INTERNALS -------------------------------------------------------------------------
    // These functions are called by the contract and are not exposed to the public
    // ---------------------------------------------------------------------------------------------

    // @dev: 
    // 1. Assigns player id
    // 2. Sets player address
    // 3. Sets player id
    fn assign_player_id(world: IWorldDispatcher, num_players: u8, player: ContractAddress) -> u8 {
        let id = num_players;
        set!(world, (PlayerID { player, id }, PlayerAddress { player, id }));
        id
    }

    // @dev: Sets no player at position
    fn clear_player_at_position(world: IWorldDispatcher, x: u8, y: u8) {
        set!(world, (PlayerAtPosition { x, y, id: 0 }));
    }

    // @dev: Returns player id at position
    fn player_at_position(world: IWorldDispatcher, x: u8, y: u8) -> u8 {
        get!(world, (x, y), (PlayerAtPosition)).id
    }

    // @dev: Sets player position and energy
    fn player_position_and_energy(world: IWorldDispatcher, id: u8, x: u8, y: u8, amt: u8) {
        set!(world, (PlayerAtPosition { x, y, id }, Position { x, y, id }, Energy { id, amt },));
    }

    // @dev: Kills player
    fn player_dead(world: IWorldDispatcher, id: u8) {
        let pos = get!(world, id, (Position));
        let empty_player = starknet::contract_address_const::<0>();

        let id_felt: felt252 = id.into();
        let entity_keys = array![id_felt].span();
        let player = get!(world, id, (PlayerAddress)).player;
        let player_felt: felt252 = player.into();
        // Remove player address and ID mappings

        let mut layout = array![];

        world.delete_entity('PlayerID', array![player_felt].span(), layout.span());
        world.delete_entity('PlayerAddress', entity_keys, layout.span());

        set!(world, (PlayerID { player, id: 0 }));
        set!(world, (Position { id, x: 0, y: 0 }, RPSType { id, rps: 0 }));

        // Remove player components
        world.delete_entity('RPSType', entity_keys, layout.span());
        world.delete_entity('Position', entity_keys, layout.span());
        world.delete_entity('Energy', entity_keys, layout.span());
    }

    // @dev: Handles player encounters
    // if the player dies returns false
    // if the player kills the other player returns true
    fn encounter(world: IWorldDispatcher, player: u8, adversary: u8) -> bool {
        let ply_type = get!(world, player, (RPSType)).rps;
        let adv_type = get!(world, adversary, (RPSType)).rps;
        if encounter_win(ply_type, adv_type) {
            let mut energy = get!(world, player, (Energy));

            // Add energy to player
            energy.amt += RENEWED_ENERGY;
            set!(world, (energy));

            // adversary dies
            player_dead(world, adversary);
            true
        } else {
            // player dies
            player_dead(world, player);
            false
        }
    }

    // @dev: Returns tile id at position
    fn tile_at_position(x: u8, y: u8) -> u8 {
        let vec = Vec3Trait::new(
            FixedTrait::from_felt(x.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into()),
            FixedTrait::from_felt(0),
            FixedTrait::from_felt(y.into()) / FixedTrait::from_felt(MAP_AMPLITUDE.into())
        );

        let simplexValue = simplex3::noise(vec);
        // compute the value between -1 and 1 to a value between 0 and 1
        let fixedValue = (simplexValue + FixedTrait::from_unscaled_felt(1)) / FixedTrait::from_unscaled_felt(2);

        // make it an integer between 0 and 100
        let value: u8 = FixedTrait::floor(fixedValue * FixedTrait::from_unscaled_felt(100)).try_into().unwrap();

        if (value > 70) {
            return 3; // Sea
        } else if (value > 60) {
            return 2; // Desert
        } else if (value > 53) {
            return 1; // Forest
        } else {
            return 0; // Plain
        }
    }

    // @dev: Returns true if player wins
    fn encounter_win(ply_type: u8, adv_type: u8) -> bool {
        assert(adv_type != ply_type, 'occupied by same type');
        if (ply_type == 'r' && adv_type == 's')
            || (ply_type == 'p' && adv_type == 'r')
            || (ply_type == 's' && adv_type == 'p') {
            return true;
        }
        false
    }

    // @dev: Returns random spawn coordinates
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
}
