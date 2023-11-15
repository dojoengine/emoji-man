import { Account } from "starknet";
import { RPSSprites } from "../phaser/config/constants";
import { Direction } from "./utils";

export interface SystemSigner {
    signer: Account;
}

export interface SpawnSystemProps extends SystemSigner {
    rps: RPSSprites;
}

export interface MoveSystemProps extends SystemSigner {
    direction: Direction;
}
