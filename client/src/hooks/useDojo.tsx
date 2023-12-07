import { Account } from "starknet";
import { NetworkLayer } from "../dojo/createNetworkLayer";
import { PhaserLayer } from "../phaser";
import { store } from "../store/store";
import { useBurnerManager } from "@dojoengine/create-burner";

export const useDojo = () => {
    const layers = store((state) => {
        return {
            networkLayer: state.networkLayer,
            phaserLayer: state.phaserLayer,
        };
    });

    if (!layers.phaserLayer || !layers.networkLayer) {
        throw new Error("Store not initialized");
    }

    const { get, create, select, list, isDeploying, clear } = useBurnerManager({
        burnerManager: layers.networkLayer.burnerManage,
    });

    return {
        networkLayer: layers.networkLayer as NetworkLayer,
        phaserLayer: layers.phaserLayer as PhaserLayer,
        account: {
            account: layers.networkLayer.burnerManage.account as Account,
            get,
            create,
            select,
            list,
            clear,
            isDeploying,
        },
        systemCalls: layers.networkLayer.systemCalls,
        toriiClient: layers.networkLayer.network.toriiClient,
        contractComponents: layers.networkLayer.network.contractComponents,
    };
};
