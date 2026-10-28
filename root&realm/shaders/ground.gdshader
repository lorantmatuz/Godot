shader_type canvas_item;

// The ground is computed per pixel from a tile grid, so terrain edges are
// smooth at any zoom and the CPU never builds a world-sized image.

uniform sampler2D terrain_tex : filter_nearest, repeat_disable;
uniform sampler2D jitter_tex : filter_linear, repeat_disable;
uniform sampler2D grain_tex : filter_linear, repeat_enable;

uniform vec2 tile_count = vec2(64.0, 64.0);
uniform float tile_size = 64.0;
uniform float jitter_amount;

// Tuning knobs, in land share units (one tile = 1.0 of share). Values come
// from WorldRenderer, so the whole look is tuned in one file.
uniform vec2 shore_shallow;
uniform vec2 shore_sand;
uniform vec2 shore_land;
uniform float land_sharpness;
uniform float rock_rim_width;
uniform float rock_rim_strength;

uniform vec4 water_color : source_color;
uniform vec4 shallow_color : source_color;
uniform vec4 sand_color : source_color;
uniform vec4 grass_color : source_color;
uniform vec4 forest_color : source_color;
uniform vec4 rock_color : source_color;
uniform vec4 rock_rim_color : source_color;

// One hot mask for the terrain at a tile, so the four corner samples can be
// blended into a single set of weights.
vec4 terrain_mask(vec2 cell) {
	vec2 uv = (clamp(cell, vec2(0.0), tile_count - 1.0) + 0.5) / tile_count;
	float id = floor(texture(terrain_tex, uv).r * 255.0 + 0.5);

	if (id < 0.5) {
		return vec4(1.0, 0.0, 0.0, 0.0);
	}
	if (id < 1.5) {
		return vec4(0.0, 1.0, 0.0, 0.0);
	}
	if (id < 2.5) {
		return vec4(0.0, 0.0, 1.0, 0.0);
	}

	return vec4(0.0, 0.0, 0.0, 1.0);
}

void fragment() {
	vec2 world = UV * tile_count * tile_size;

	// A noise sample per third of a tile warps the lookup position, so the
	// boundaries read as an organic curve instead of the tile grid.
	// Three jitter samples per tile; keep in sync with
	// WorldRenderer.JITTER_CELLS_PER_TILE.
	vec2 lattice = world / (tile_size / 3.0);
	vec2 jitter_uv = (lattice + 0.5) / (tile_count * 3.0 + 1.0);
	vec2 offset = (texture(jitter_tex, jitter_uv).rg * 2.0 - 1.0) * jitter_amount;

	vec2 grid = (world + offset) / tile_size - 0.5;
	vec2 base = floor(grid);
	vec2 t = grid - base;

	// Bilinear terrain blend; ids mix into a weight vector rather than into a
	// number, so no terrain index is ever interpolated.
	vec4 w =
		terrain_mask(base) * ((1.0 - t.x) * (1.0 - t.y))
		+ terrain_mask(base + vec2(1.0, 0.0)) * (t.x * (1.0 - t.y))
		+ terrain_mask(base + vec2(0.0, 1.0)) * ((1.0 - t.x) * t.y)
		+ terrain_mask(base + vec2(1.0, 1.0)) * (t.x * t.y);

	float land = clamp(1.0 - w.x, 0.0, 1.0);
	vec3 color = water_color.rgb;

	if (land > 0.0) {
		vec3 shares = vec3(w.y, w.z, w.w) / land;

		// Sharpening narrows every land boundary to a consistent band instead
		// of the full-tile blur that a plain weighted average produces.
		vec3 sharp = pow(shares, vec3(land_sharpness));
		// Weights can be one ulp off at pure water tiles; a zero sum would
		// produce NaNs and render as black specks in the lakes.
		sharp /= max(dot(sharp, vec3(1.0)), 1e-4);
		vec3 land_color =
			grass_color.rgb * sharp.x + forest_color.rgb * sharp.y + rock_color.rgb * sharp.z;

		color = mix(color, shallow_color.rgb, smoothstep(shore_shallow.x, shore_shallow.y, land));
		// The shore is a band rather than a line: water fades through shallow
		// water and sand before it reaches dry land.
		color = mix(color, sand_color.rgb, smoothstep(shore_sand.x, shore_sand.y, land));
		color = mix(color, land_color, smoothstep(shore_land.x, shore_land.y, land));

		// Rock keeps a defined gravel rim, so an outcrop reads as a solid edge
		// instead of a muddy fade into the grass.
		float first = max(shares.x, max(shares.y, shares.z));
		float second = max(
			min(shares.x, shares.y),
			max(min(shares.y, shares.z), min(shares.x, shares.z))
		);
		float rim = 1.0 - smoothstep(0.0, rock_rim_width, first - second);
		rim *= step(0.02, shares.z) * step(0.02, shares.x + shares.y);
		// Gate on dry land, or the rim would leak into water as dark specks.
		rim *= smoothstep(shore_land.x, shore_land.y, land);

		color = mix(color, rock_rim_color.rgb, rim * rock_rim_strength);
	}

	float grain =
		(texture(grain_tex, world / 96.0).r - 0.5) * 0.05
		+ (texture(grain_tex, world / 27.0).r - 0.5) * 0.03;

	COLOR = vec4(color + grain, 1.0);
}
