import { SetupNetworkResult } from "./setupNetwork";
import { ClientComponents } from "./createClientComponents";
import { MoveSystemProps, SpawnSystemProps } from "./types";
import { uuid } from "@latticexyz/utils";
import { Entity, getComponentValue } from "@dojoengine/recs";
import { getEntityIdFromKeys } from "@dojoengine/utils";
import { updatePositionWithDirection } from "./utils";

export type SystemCalls = ReturnType<typeof createSystemCalls>;

export function createSystemCalls(
    { execute }: SetupNetworkResult,
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

        // get player ID
        const playerID = getEntityIdFromKeys([
            BigInt(signer.address),
        ]) as Entity;

        // get the RPS ID associated with the PlayerID
        const rps_id = getComponentValue(PlayerID, playerID)?.id;

        // get the RPS entity
        const rps_entity = getEntityIdFromKeys([
            BigInt(rps_id?.toString() || "0"),
        ]);

        // get the RPS position
        const position = getComponentValue(Position, rps_entity);

        // update the position with the direction
        const new_position = updatePositionWithDirection(
            direction,
            position || { x: 0, y: 0 }
        );

        // add an override to the position
        const positionId = uuid();
        Position.addOverride(positionId, {
            entity: rps_entity,
            value: { id: rps_id, x: new_position.x, y: new_position.y },
        });

        try {
            const { transaction_hash } = await execute(
                signer,
                "actions",
                "move",
                [direction]
            );

            // logging the transaction hash
            console.log(
                await signer.waitForTransaction(transaction_hash, {
                    retryInterval: 100,
                })
            );
            // add half second timeout

            await new Promise((resolve) => setTimeout(resolve, 1000));
        } catch (e) {
            console.log(e);
            Position.removeOverride(positionId);
        } finally {
            Position.removeOverride(positionId);
        }
    };

    return {
        spawn,
        move,
    };
}
