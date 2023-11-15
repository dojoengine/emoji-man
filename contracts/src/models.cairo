use starknet::ContractAddress;
use debug::PrintTrait;

// Declaration of an enum named 'Direction' with five variants
#[derive(Serde, Copy, Drop, Introspect)]
enum Direction {
    None,
    Left,
    Right,
    Up,
    Down,
}

// Implementation of a trait to convert Direction enum into felt252 data type
impl DirectionIntoFelt252 of Into<Direction, felt252> {
    fn into(self: Direction) -> felt252 {
        match self {
            Direction::None(()) => 0,
            Direction::Left(()) => 1,
            Direction::Right(()) => 2,
            Direction::Up(()) => 3,
            Direction::Down(()) => 4,
        }
    }
}

// Constant definition for a game data key. This allows us to fetch this model using the key.
const GAME_DATA_KEY: felt252 = 'game';

// Structure definition for a 2D vector with x and y as unsigned 32-bit integers
#[derive(Copy, Drop, Serde, Introspect)]
struct Vec2 {
    x: u32,
    y: u32
}

// Structure to represent a player's position with unique keys and an ID
#[derive(Model, Copy, Drop, Serde)]
struct PlayerAtPosition {
    #[key]
    x: u8,
    #[key]
    y: u8,
    id: u8,
}

// Structure representing a position with an ID, and x, y coordinates
#[derive(Model, Copy, Drop, Serde)]
struct Position {
    #[key]
    id: u8,
    x: u8,
    y: u8
}

// Structure representing a Rock, Paper, Scissors type game with an ID and a value
#[derive(Model, Copy, Drop, Serde)]
struct RPSType {
    #[key]
    id: u8,
    rps: u8,
}

#[generate_trait]
impl RPSTypeImpl of RPSTypeTrait {
    fn get_type(self: RPSType) -> u8 {
        self.rps
    }
}


// Structure for storing energy amount with an ID
#[derive(Model, Copy, Drop, Serde)]
struct Energy {
    #[key]
    id: u8,
    amt: u8,
}

// Structure representing a player's ID with a ContractAddress
#[derive(Model, Copy, Drop, Serde)]
struct PlayerID {
    #[key]
    player: ContractAddress,
    id: u8,
}

// Structure linking a player's ID to their ContractAddress
#[derive(Model, Copy, Drop, Serde)]
struct PlayerAddress {
    #[key]
    id: u8,
    player: ContractAddress,
}

// Structure for storing game data with a key, number of players, and available IDs
#[derive(Model, Copy, Drop, Serde)]
struct GameData {
    #[key]
    game: felt252, // Always 'game'
    number_of_players: u8,
    available_ids: u256, // Packed u8s?
}
