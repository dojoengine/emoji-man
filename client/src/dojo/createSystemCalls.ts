import { SetupNetworkResult } from "./setupNetwork";
import { ClientComponents } from "./createClientComponents";
import { MoveSystemProps, SpawnSystemProps } from "./types";
import { uuid } from "@latticexyz/utils";
import { Entity, getComponentValue } from "@dojoengine/recs";

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

        // TODO: Add optimistic updates

        // 1. get player ID
        // 2. get player by playerID position
        // 3. calculate new position
        // 4. update position

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
        } catch (e) {
            console.error(e);
        }
    };

    return {
        spawn,
        move,
    };
}
