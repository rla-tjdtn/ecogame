# 소품 메시 만들기 (에코포비아 — 맵 소품을 실제 3D 메시 에셋으로)

The game is a pitch-black sonar horror. **The only thing the player ever sees of a prop is its white sonar lines**:
the black body only hides lines that are behind it. So a prop's quality is how well its lines read as the
real object (contours, creases, a few telling details), like a clean technical line drawing.

Today every prop is built from MapKit primitives (`Kit.box / cylinder / ball / wedge`) in
`src/server/Props.luau`, `src/server/HomeProps.luau`, `src/server/ChapterProps/<Chapter>.luau`.
We keep those builders **unchanged** (they still make collision, sound blocking, monster ray blockers),
and at the end of each builder add one line:

```lua
PM.dress(m, "<Group>.<Name>", frameCFrame)            -- or PM.dress(m, key, cf, Vector3.new(sx, sy, sz)) to stretch
```

At runtime `PropMesh.dress` puts ONE MeshPart (our procedurally modeled mesh, uploaded as an asset) at
`frameCFrame`, hides the visible primitives that still matter for gameplay (collide/query/blocks) and deletes
purely decorative ones. Sonar lines come from line data we bake from the same model. If the mesh can't
load, nothing changes (old primitives stay) — so the builder code must keep working exactly as before.

## Files (per group — you own only yours)
- `src/server/ChapterProps/<Chapter>.luau` (or `Props.luau` / `HomeProps.luau` for Props/Home): add
  `local PM = require(script.Parent.Parent.PropMesh)` near the top (Props.luau / HomeProps.luau: `script.Parent.PropMesh`)
  and one `PM.dress(...)` line per prop model. **Do not change any other line of the builders.**
- `art/props/models/<Group>.js`: `module.exports = { '<Group>.<Name>': (m) => { ...model... }, ... }`
  See `art/props/models/Hospital.js` (`Hospital.Bed`) for a finished example.
- Never touch: StageBuilder, Stages/*, client code, PropMesh.luau, lib/*, other groups' files. Don't upload, don't run Studio, don't commit.

## Frame (the coordinate system you model in)
`frameCFrame` is a CFrame you choose inside the builder, usually the builder's own local frame (e.g.
`look(mid)`, `cf`, `CFrame.lookAt(p, p + axis)`) **placed at floor level** under the prop centre. In the model:
x = right, y = up (y = 0 is the floor), **-z = the frame's LookVector**. Units are studs. Tiles are 8×8 studs,
ceiling 14 (11 on the 1st floor of 2-storey maps). Make the mesh occupy the same footprint and height as
the old primitives (within ~0.3 studs), so the collision and what the player sees agree.

Instances that differ only by rotation share one mesh. Props whose size varies per placement:
pass a scale `Vector3` (mesh stretches per axis — fine for boxes/runs, bad for round things), or make 2–3 variant
keys (`Warehouse.PalletStack1`, `...2`) picked with the builder's existing `ctx.hash` value. Random sub-items
(crate piles, rubble, toys) become one fixed arrangement per variant.

Props that put parts straight into `ctx.props` (no Model), or functions that make several Models:
dress each Model separately, or pass the part list: `PM.dress(ctx.props, key, cf, nil, {p1, p2, ...}, ctx.props)`
(collect the parts the function created, e.g. by recording `#ctx.props:GetChildren()` before/after).
Structural pieces that are already ideal as primitives (a flat floor marking, a plain wall slab, water
surface plane, a 1-part invisible blocker) may stay primitives: say so in your report.

## Modeling API (`art/props/lib/model.js`)
```js
const { T, Rx, Ry, Rz, S, roundRect, circle2, arc2 } = require('../lib/model.js');
m.box(center, size, { bevel, lines, solid })    // lines: 'all' | 'none' | 'X' | 'Y' | 'Z' | 'XZ' | 'XY' | 'top'
m.slab(x, y0, z, sx, h, sz, opts)               // box standing on y0
m.cushion(center, size, radius, { lines })      // rounded box (mattress, seat cushion, sofa arm)
m.cyl(a, b, r, { seg, rings: [t..], caps, line, silhouette })   // line:true → one stroke (thin rods < ~0.12 r)
m.cone(a, b, r1, r2, opts)                      // frustum
m.sphere(c, r)                                  // silhouette circle
m.lathe([[r, y], ...], { at, seg, crease, rings })   // surface of revolution (lamp, bucket, toilet bowl, vase)
m.extrude(poly2d, depth, { z0, caps: true|'front'|'back'|false, sides, crease })  // 2D polygon (xy) pushed along z
m.torus(c, axisUnit, R, r)                      // steering wheel, ring
m.tube([p0, p1, ...], r)                        // bent pipe / frame
m.line([p0, p1, ...], { closed })               // pure decorative line (seams, panel grooves, labels) — no body
m.with(T(x,y,z).mul(Ry(a)), () => { ... })      // local transform; m.push(xf)/m.pop()
m.mirrorX(() => { ... })                        // build once, mirrored to the other side (draw for +x)
```
Lines buried inside another solid shape are removed automatically. Cylinders/spheres/lathes draw a
view-dependent silhouette in game (2 lines along a cylinder), plus end rings when r ≥ 0.3.
`solid: false` = body does not hide/cut other lines (use for thin decorative plates).

## Line budget (performance — important)
Every sonar line is a pooled part (pool 5500, 4 players). `preview.js` prints the line cost (game line parts:
static lines split at 2.5 studs + silhouette lines). Rules:
- Each prop: **≤ 2× the old prop's lines** (old = "before" number), and props placed > 40 times: ≤ 1.5×.
- Your whole group (sum over placements, printed as TOTAL by `--group`): **≤ 1.5× before**.
- Prefer long continuous contours over many short pieces; circles cost 8–24 lines each — use them where
  they read (wheels, knobs, drums), not everywhere. Thin plates: `extrude(..., { caps: 'front' })` = one
  outline instead of two parallel ones. Don't draw two lines closer than ~0.15 studs apart.
- Triangles: aim ≤ 6000 per prop (hard limit 18000). Bevels/cushions/lathe add triangles, keep `seg` modest.

## Look & feel
Real objects of that place, abandoned (some tilt, a dropped item, a missing panel are good). Silhouette first:
the outline must say "wheelchair" from 10 studs away. Then 3–6 telling details (handles, hinges, vents, labels,
buttons, seams). Not cartoony, not noisy. Keep proportions believable at Roblox scale (a character is ~5 studs
tall; doors 7 high; desks 2.6 high; chairs seat 1.6).

## Workflow per prop
1. Read the builder function; pick the frame; add the `PM.dress` line (key `<Group>.<FunctionOrModelName>`).
2. `node art/props/sim.js <stage>` (Hospital 4, Facility 1, Warehouse 2, Sewer 3, Maze 5, Hotel 6, School 7,
   Kindergarten 8, Parking 9, Cinema 10; HomeProps: `node art/props/sim.js --home`). The sim runs the real builders.
3. Write the model; `node art/props/preview.js <key>` → `art/props/out/preview/<key>.png` (top row = old game
   lines, bottom = new mesh lines, 3 angles; dark grey = body). **Open the PNG and look**; iterate until it
   clearly reads as the real object and fits the old footprint.
4. At the end: `node art/props/preview.js --group <Group>` (all keys + TOTAL ratio) and
   `C:/Users/User/Tools/luau/luau-compile.exe --text <your .luau> > /dev/null` must succeed.
