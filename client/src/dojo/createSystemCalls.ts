import { SetupNetworkResult } from "./setupNetwork";
import { Entity, getComponentValue } from "@dojoengine/recs";
import { uuid } from "@latticexyz/utils";
import { ClientComponents } from "./createClientComponents";
import { updatePositionWithDirection } from "./utils";
import { MoveSystemProps, SpawnSystemProps } from "./types";

export type SystemCalls = ReturnType<typeof createSystemCalls>;

export function createSystemCalls(
    { execute, contractComponents }: SetupNetworkResult,
    { Position, PlayerID }: ClientComponents
) {
    const spawn = async (props: SpawnSystemProps) => {
        try {
            await execute(props.signer, "actions", "spawn", [props.rps]);
        } catch (e) {
            console.error(e);
        }
    };

    const move = async (props: MoveSystemProps) => {
        const { signer, direction } = props;

        const currentPosition = getComponentValue(
            Position,
            playerId?.id.toString() as Entity
        ) || { x: 0, y: 0 };

        const newPosition = updatePositionWithDirection(direction, {
            x: currentPosition["x"],
            y: currentPosition["y"],
        });

        const positionId = uuid();
        Position.addOverride(positionId, {
            entity: playerId?.id.toString() as Entity,
            value: {
                id: 1,
                x: newPosition["x"],
                y: newPosition["y"],
            },
        });

        try {
            const { transaction_hash } = await execute(
                signer,
                "actions",
                "move",
                [direction]
            );

            console.log(
                await signer.waitForTransaction(transaction_hash, {
                    retryInterval: 100,
                })
            );
        } catch (e) {
            console.log(e);
            // Position.removeOverride(positionId);
            // Moves.removeOverride(movesId);
        } finally {
            // Position.removeOverride(positionId);
            // Moves.removeOverride(movesId);
        }
    };

    return {
        spawn,
        move,
    };
}
