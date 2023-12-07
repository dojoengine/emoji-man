import { Account } from "starknet";
import { NetworkLayer } from "../../dojo/createNetworkLayer";
import { PhaserLayer } from "../../phaser";
import { store } from "../../store";
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

    const { networkLayer, phaserLayer } = layers;

    const { get, create, select, list, isDeploying, clear } = useBurnerManager({
        burnerManager: layers.networkLayer.burnerManager,
    });

    return {
        networkLayer: networkLayer as NetworkLayer,
        phaserLayer: phaserLayer as PhaserLayer,
        account: {
            account: networkLayer.burnerManager.account as Account,
            get,
            create,
            select,
            list,
            clear,
            isDeploying,
        },
        systemCalls: networkLayer.systemCalls,
        contractComponents: networkLayer.network.contractComponents,
    };
};
