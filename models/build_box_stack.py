# build_box_stack.py — author models/box_stack.glb headlessly.
#
# Committed (unlike the earlier throwaway prop scripts) so the Blender
# pipeline is reproducible: every prop GLB can be rebuilt with
#   /Applications/Blender.app/Contents/MacOS/Blender --background \
#       --python models/build_box_stack.py
# Dusk + toybox rules: chunky low-poly, principled materials, one warm
# emissive accent, tri budget <= 300, real-world scale (stack ~1.1m).
import bpy
import os


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_box(name, size, loc, rot_z, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rot_z))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    return obj


def make_material(name, color, rough=0.85, emissive=None, emissive_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emissive is not None:
        bsdf.inputs["Emission Color"].default_value = (*emissive, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emissive_strength
    return mat


clear_scene()

cardboard = make_material("Cardboard", (0.52, 0.36, 0.20), rough=0.92)
cardboard_dark = make_material("CardboardDark", (0.42, 0.28, 0.15), rough=0.92)
tape = make_material("Tape", (0.78, 0.62, 0.30), rough=0.6,
                     emissive=(1.0, 0.72, 0.35), emissive_strength=0.25)

# Three crushed-office-cardboard boxes, askew stack, tape stripe on top.
make_box("BoxBottom", (0.72, 0.56, 0.42), (0, 0, 0.21), 0.08, cardboard)
make_box("BoxMiddle", (0.60, 0.50, 0.36), (0.03, -0.02, 0.60), -0.14, cardboard_dark)
make_box("BoxTop", (0.46, 0.40, 0.30), (-0.04, 0.03, 0.93), 0.22, cardboard)
make_box("TapeTop", (0.10, 0.42, 0.012), (-0.04, 0.03, 1.085), 0.22, tape)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "box_stack.glb")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")

tris = 0
for mesh in bpy.data.meshes:
    tris += len(mesh.polygons)
print("BOX_STACK_BUILD_OK tris=%d out=%s" % (tris, out))
