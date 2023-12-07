import { useComponentValue } from "@dojoengine/react";
import { useDojo } from "../hooks/useDojo";
import { getEntityIdFromKeys } from "@dojoengine/utils";
import { Entity } from "@dojoengine/recs";

export const EnergyLevels = () => {
    const {
        account: { account },
        contractComponents: { PlayerID, Energy },
    } = useDojo();

    const playerID = getEntityIdFromKeys([
        BigInt(account.address ?? ""),
    ]) as Entity;

    // get the RPS ID associated with the PlayerID
    const rps_id = useComponentValue(PlayerID, playerID)?.id;

    // // // get the RPS entity
    const rps_entity = getEntityIdFromKeys([BigInt(rps_id?.toString() || "0")]);

    // // // get the RPS position
    const energy = useComponentValue(Energy, rps_entity);

    return (
        <div className="absolute top-3 left-3 text-white  p-9">
            <h5>energy</h5>
            <h1 className="text-3xl">{energy?.amt ? energy.amt : "dead"}</h1>
        </div>
    );
};
