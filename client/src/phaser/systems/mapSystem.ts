import { Tileset } from "../../assets/world";
import { PhaserLayer } from "..";
import { createNoise2D } from "simplex-noise";
import alea from "alea";

export function mapSystem(layer: PhaserLayer) {
    const {
        scenes: {
            Main: {
                maps: {
                    Main: { putTileAt },
                },
            },
        },
    } = layer;

    const noise = createNoise2D(alea("emojiman_rnd_seed"));

    for (let x = 0; x < 50; x++) {
        for (let y = 0; y < 50; y++) {
            const coord = { x, y };
            const seed = noise(x, y);

            if (seed > 0.9) {
                // This would be the highest 'elevation'
                putTileAt(coord, Tileset.Desert, "Foreground");
            } else if (seed > 0.3) {
                // Even lower, could be fields or plains
                putTileAt(coord, Tileset.Sea, "Foreground");
            } else if (seed > 0.1) {
                // Close to water level, might be beach
                putTileAt(coord, Tileset.Forest, "Foreground");
            } else {
                // Below a certain threshold, it is sea
                putTileAt(coord, Tileset.Land, "Foreground");
            }
        }
    }
}
