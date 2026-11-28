# 렌더 공통: 어두운 배경 + 키/림/채움 조명 + 카메라 (EEVEE, 소리 없음)
import bpy, math
from mathutils import Vector


def setup(res=(720, 960), clay=None, bg=(0.035, 0.038, 0.045)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    try:
        sc.eevee.taa_render_samples = 32
        sc.eevee.use_shadows = True
    except Exception:
        pass
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('W')
    sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value = (*bg, 1)
    sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.0
    for nm, loc, en, col, size in (('Key', (2.2, -3.0, 3.4), 900, (1, .93, .84), 1.6), ('Rim', (-2.4, 3.0, 2.8), 1100, (.62, .78, 1.0), 1.2),
                                   ('Fill', (-3.2, -2.2, 1.2), 220, (.75, .85, 1.0), 2.5), ('Under', (0, -2.5, -.3), 60, (.6, .8, .7), 2.0)):
        if nm in bpy.data.objects:
            continue
        ld = bpy.data.lights.new(nm, 'AREA'); ld.energy = en; ld.color = col; ld.size = size
        lo = bpy.data.objects.new(nm, ld); sc.collection.objects.link(lo); lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 1.1)) - lo.location).to_track_quat('-Z', 'Y').to_euler()
    # 바닥
    if 'Floor' not in bpy.data.objects:
        me = bpy.data.meshes.new('Floor'); me.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
        fl = bpy.data.objects.new('Floor', me); sc.collection.objects.link(fl)
        mt = bpy.data.materials.new('FloorMat'); mt.use_nodes = True
        b = mt.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = (.045, .045, .048, 1); b.inputs['Roughness'].default_value = .6
        me.materials.append(mt)
    if 'Cam' not in bpy.data.objects:
        cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); sc.camera = cam
        cam.data.lens = 50; cam.data.clip_start = .02; cam.data.clip_end = 100
    if clay:
        mt = bpy.data.materials.new('Clay'); mt.use_nodes = True
        b = mt.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = (.55, .58, .54, 1); b.inputs['Roughness'].default_value = .45
        for o in clay:
            o.data.materials.clear(); o.data.materials.append(mt)
    return sc


def aim(target, yaw_deg, dist, height=0.0, lens=50):
    cam = bpy.data.objects['Cam']; cam.data.lens = lens
    t = Vector(target); yaw = math.radians(yaw_deg)
    cam.location = t + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, height))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.context.scene.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
