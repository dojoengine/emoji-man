import { useDojo } from "./hooks/useDojo";
import { ImagePaths, RPSSprites } from "../phaser/config/constants";
import { Button } from "./button";
import { useUIStore } from "../store";
import { useEffect } from "react";

export const Spawn = () => {
    const setLoggedIn = useUIStore((state: any) => state.setLoggedIn);
    const {
        account: { account, isDeploying },
        systemCalls: { spawn },
    } = useDojo();

    useEffect(() => {
        if (isDeploying) {
            return;
        }

        if (account) {
            return;
        }
    }, [account]);

    if (!account) {
        return <div>Deploying...</div>;
    }

    return (
        <div className="flex space-x-3 justify-between p-2 flex-wrap">
            {Object.keys(RPSSprites)
                .filter((key) => isNaN(Number(key)))
                .map((key) => (
                    <div key={key}>
                        <Button
                            variant={"default"}
                            onClick={async () => {
                                await spawn({
                                    signer: account,
                                    rps: RPSSprites[
                                        key as keyof typeof RPSSprites
                                    ],
                                });

                                setLoggedIn();
                            }}
                        >
                            Spawn {key}
                            <img
                                className="w-8 h-8"
                                src={
                                    ImagePaths[
                                        RPSSprites[
                                            key as keyof typeof RPSSprites
                                        ]
                                    ]
                                }
                            />
                        </Button>
                    </div>
                ))}
        </div>
    );
};
