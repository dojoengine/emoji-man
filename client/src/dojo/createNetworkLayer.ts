import { world } from "./world";
import { setup } from "./setup";
import { createSyncManager } from "@dojoengine/react";

export type NetworkLayer = Awaited<ReturnType<typeof createNetworkLayer>>;

export const createNetworkLayer = async () => {
    const { components, systemCalls, network } = await setup();

    const { Position, PlayerID, Energy, RPSType, PlayerAddress } =
        network.contractComponents;

    const { burnerManager, toriiClient, account } = network;

    const initial_sync = () => {
        const models: any = [];

        for (let i = 1; i <= 30; i++) {
            let keys = [BigInt(i)];
            models.push({
                model: Position,
                keys,
            });
            models.push({
                model: RPSType,
                keys,
            });
            models.push({
                model: PlayerAddress,
                keys,
            });
            models.push({
                model: Energy,
                keys,
            });
        }

        models.push({
            model: PlayerID,
            keys: [BigInt(account.address)],
        });

        return models;
    };

    const { sync } = createSyncManager(toriiClient, initial_sync());

    sync();

    return {
        world,
        components,
        systemCalls,
        network,
        account,
        burnerManager,
    };
};
