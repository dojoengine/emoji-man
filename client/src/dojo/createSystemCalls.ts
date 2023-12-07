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
    { Position, PlayerID, Energy }: ClientComponents
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
        const rpsId = getComponentValue(PlayerID, playerID)?.id;

        // get the RPS entity
        const rpsEntity = getEntityIdFromKeys([
            BigInt(rpsId?.toString() || "0"),
        ]);

        // get the RPS position
        const position = getComponentValue(Position, rpsEntity);

        let currentEnergyAmt = getComponentValue(Energy, rpsEntity)?.amt || 0;

        // update the position with the direction
        const new_position = updatePositionWithDirection(
            direction,
            position || { x: 0, y: 0 }
        );

        // add an override to the position
        const positionId = uuid();
        Position.addOverride(positionId, {
            entity: rpsEntity,
            value: { id: rpsId, x: new_position.x, y: new_position.y },
        });

        // add an override to the energy
        const energyId = uuid();
        Energy.addOverride(energyId, {
            entity: rpsEntity,
            value: { id: rpsId, amt: currentEnergyAmt-- },
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

            // just wait until indexer - currently ~1 second.
            // TODO: make this more robust
            await new Promise((resolve) => setTimeout(resolve, 1000));
        } catch (e) {
            console.log(e);
            Position.removeOverride(positionId);
            Energy.removeOverride(energyId);
        } finally {
            Position.removeOverride(positionId);
            Energy.removeOverride(energyId);
        }
    };

    return {
        spawn,
        move,
    };
}
