export enum Scenes {
    Main = "Main",
}

export enum Maps {
    Main = "Main",
}

export enum Animations {
    RockIdle = "RockIdle",
    PaperIdle = "PaperIdle",
    ScissorsIdle = "ScissorsIdle",
}

// image addresses

export enum Sprites {
    Soldier,
}

export enum RPSSprites {
    Rock,
    Paper,
    Scissors,
}

export const ImagePaths: { [key in RPSSprites]: string } = {
    [RPSSprites.Rock]: "rock.png",
    [RPSSprites.Paper]: "paper.png",
    [RPSSprites.Scissors]: "scissors.png",
};

export enum Assets {
    MainAtlas = "MainAtlas",
    Tileset = "Tileset",
}

export enum Direction {
    Unknown,
    Up,
    Down,
    Left,
    Right,
}

export const TILE_HEIGHT = 32;
export const TILE_WIDTH = 32;

// contract offset so we don't overflow
export const POSITION_OFFSET = 1000;
