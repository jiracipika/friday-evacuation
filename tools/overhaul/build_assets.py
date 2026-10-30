"""Reproducible Blender authoring for Friday's modular office kit and seated rig.
Run: blender -b --python tools/overhaul/build_assets.py
Optional NVIDIA source: python tools/overhaul/fetch_nvidia_chair.py first.
All authored geometry is in meters. Godot receives Y-up, -Z-forward GLBs.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'models/overhaul'; OUT.mkdir(parents=True,exist_ok=True)
C={'ink':(0.045,0.065,0.09,1),'ivory':(.88,.85,.77,1),'wood':(.56,.34,.17,1),'teal':(.09,.36,.36,1),'orange':(.95,.32,.08,1),'metal':(.43,.49,.51,1),'paper':(.96,.94,.88,1),'green':(.2,.38,.23,1),'blue':(.18,.3,.42,1)}
MATS={}
def g(v): return Vector((v[0],-v[2],v[1]))
def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    MATS.clear()
def mat(key):
    if key not in MATS:
        m=bpy.data.materials.new(key); m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=C.get(key,(.7,.7,.7,1)); bs.inputs['Roughness'].default_value=.7
        bs.inputs['Metallic'].default_value=.65 if key=='metal' else 0
        MATS[key]=m
    return MATS[key]
def finish(o,name,region=None,bone=None,color='ivory'):
    o.name=name
    if region is not None:
        if 'Palette' not in MATS:
            m=bpy.data.materials.new('Palette');m.use_nodes=True
            attr=m.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color'
            m.node_tree.links.new(attr.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);MATS['Palette']=m
        o.data.materials.clear();o.data.materials.append(MATS['Palette'])
        a=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for value in a.data: value.color=(region/10.,.92,0,1)
    else: o.data.materials.append(mat(color))
    if bone:
        group=o.vertex_groups.new(name=bone);group.add(list(range(len(o.data.vertices))),1.,'REPLACE')
    return o
def box(name,size,pos,color='ivory',bevel=.035,region=None,bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=g(pos));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Manufactured edges','BEVEL');b.width=min(bevel,min(size)*.35);b.segments=3
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=b.name)
        n=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');n.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=n.name)
    return finish(o,name,region,bone,color)
def sphere(name,size,pos,color='ivory',region=None,bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=g(pos));o=bpy.context.object;o.scale=(size[0]/2,size[2]/2,size[1]/2);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,region,bone,color)
def rod(name,a,b,radius,color='metal',region=None,bone=None):
    a,b=g(a),g(b);v=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=v.length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
    return finish(o,name,region,bone,color)
def body_mesh(name,rings,region,bone):
    # Sculpted cross sections, not a stack of runtime primitives.
    verts=[];faces=[];segments=16
    for y,rx,rz,z in rings:
        for i in range(segments):
            a=i*math.tau/segments;verts.append(tuple(g((math.cos(a)*rx,y,z+math.sin(a)*rz))))
    for ring in range(len(rings)-1):
        for i in range(segments):
            a=ring*segments+i;b=ring*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))));faces.append(tuple(range((len(rings)-1)*segments,len(rings)*segments)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    for p in mesh.polygons:p.use_smooth=True
    return finish(o,name,region,bone)
def merge(name,objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
def export(name,objects=None):
    if objects:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=bool(objects),export_animations=True,export_apply=False,export_yup=True)
    triangles=0
    for o in (objects or bpy.context.scene.objects):
        if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    print('ASSET',name,triangles,'triangles')

def worker():
    reset(); groups={}
    def collect(name,fn):
        before=set(bpy.context.scene.objects);fn();objs=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH'];groups[name]=merge(name,objs)
    def anatomy():
        body_mesh('Torso',[(.65,.18,.13,.03),(.76,.22,.145,.02),(1.05,.25,.15,.02),(1.2,.22,.13,0),(1.24,.12,.09,0)],2,'Spine')
        rod('Neck',(0,1.18,0),(0,1.37,0),.073,region=0,bone='Head')
        body_mesh('Head',[(1.31,.09,.075,-.01),(1.35,.15,.12,-.015),(1.47,.19,.15,0),(1.61,.19,.145,.015),(1.69,.145,.11,.02),(1.71,.08,.065,.02)],0,'Head')
        sphere('Nose',(.085,.1,.13),(0,1.47,-.157),region=0,bone='Head')
        for s in (-1,1):
            sphere('Ear',(.065,.115,.07),(s*.19,1.47,.01),region=0,bone='Head')
            side='L' if s<0 else 'R'
            sphere('Upper arm',(.16,.34,.18),(s*.29,1.04,-.015),region=2,bone='Arm.'+side)
            rod('Forearm',(s*.3,.91,-.07),(s*.3,.85,-.31),.065,region=0,bone='Forearm.'+side)
            sphere('Hand',(.13,.1,.17),(s*.3,.85,-.32),region=0,bone='Forearm.'+side)
            sphere('Trouser thigh',(.22,.21,.43),(s*.13,.61,-.17),region=4,bone='Thigh.'+side)
            rod('Trouser shin',(s*.13,.56,-.34),(s*.13,.25,-.35),.08,region=4,bone='Shin.'+side)
            box('Shoe',(.2,.13,.32),(s*.13,.19,-.43),bevel=.06,region=4,bone='Shin.'+side)
            box('Sole',(.2,.035,.32),(s*.13,.13,-.43),bevel=.01,region=6,bone='Shin.'+side)
        box('ID badge',(.105,.14,.025),(.13,1.04,-.153),bevel=.01,region=5,bone='Spine')
        box('Photo',(.04,.05,.01),(.12,1.06,-.171),bevel=.003,region=3,bone='Spine')
        for s in (-1,1):rod('Lanyard',(s*.065,1.22,-.12),(.12,1.11,-.17),.008,region=3,bone='Spine')
    collect('Body',anatomy)
    def eyes():
        for s in (-1,1):
            sphere('White',(.11,.1,.065),(s*.078,1.535,-.143),region=5,bone='Head')
            sphere('Pupil',(.041,.05,.025),(s*.075,1.535,-.182),region=4,bone='Head')
            sphere('Highlight',(.012,.016,.01),(s*.075-.008,1.55,-.196),region=5,bone='Head')
    collect('Eyes',eyes)
    for expression in ('focused','sleepy','derpy','panic'):
        def face(expression=expression):
            for s in (-1,1):
                brow=box('Brow',(.11,.02,.018),(s*.08,1.61,-.146),bevel=.008,region=1,bone='Head');brow.rotation_euler.y=s*(.2 if expression=='focused' else -.15)
            if expression=='panic':sphere('Mouth',(.07,.09,.024),(0,1.39,-.123),region=4,bone='Head')
            elif expression=='derpy':
                mouth=box('Crooked grin',(.13,.035,.022),(.015,1.395,-.128),bevel=.012,region=4,bone='Head');mouth.rotation_euler.y=.18
                box('One tooth',(.032,.035,.015),(-.02,1.386,-.143),bevel=.006,region=5,bone='Head')
            else:box('Mouth',(.1,.016,.016),(0,1.4,-.132),bevel=.006,region=4,bone='Head')
            if expression=='sleepy':
                for s in (-1,1):box('Lid',(.11,.038,.025),(s*.078,1.565,-.18),bevel=.01,region=0,bone='Head')
        collect('Face_'+expression,face)
    for style in ('side_part','bob','bun','bedhead','bald'):
        def hair(style=style):
            if style=='bald':
                for s in (-1,1):sphere('Side hair',(.035,.13,.14),(s*.18,1.54,.06),region=1,bone='Head')
                return
            body_mesh('Hair cap',[(1.6,.185,.14,.02),(1.69,.19,.14,.03),(1.75,.12,.09,.035),(1.77,.02,.025,.035)],1,'Head')
            if style=='side_part':
                o=sphere('Sweep',(.34,.11,.18),(-.04,1.695,-.08),region=1,bone='Head');o.rotation_euler.y=-.15
            if style=='bob':
                for s in (-1,1):sphere('Bob side',(.1,.35,.26),(s*.18,1.53,.06),region=1,bone='Head')
                sphere('Bob back',(.35,.32,.12),(0,1.5,.16),region=1,bone='Head')
            if style=='bun':sphere('Bun',(.21,.2,.22),(0,1.75,.13),region=1,bone='Head')
            if style=='bedhead':
                for i in range(4):
                    o=sphere('Tuft',(.12,.17,.2),(-.14+i*.09,1.76,-.02),region=1,bone='Head');o.rotation_euler.y=-.3+i*.2
        collect('Hair_'+style,hair)
    for outfit in ('blazer','hoodie','cardigan','hi_vis'):
        def clothes(outfit=outfit):
            if outfit=='hoodie':
                sphere('Hood',(.39,.26,.22),(0,1.2,.11),region=2,bone='Spine')
                box('Pocket',(.23,.1,.04),(0,.88,-.14),region=2,bone='Spine')
                for s in (-1,1):rod('Cord',(s*.06,1.21,-.13),(s*.07,1.04,-.18),.007,region=5,bone='Spine')
            else:
                box('Shirt',(.17,.4,.035),(0,1.02,-.15),region=5,bone='Spine')
                for s in (-1,1):
                    o=box('Lapel',(.075,.29,.035),(s*.115,1.1,-.15),region=2,bone='Spine');o.rotation_euler.y=s*.2
                if outfit=='blazer':rod('Tie',(0,1.19,-.18),(0,.96,-.18),.024,region=3,bone='Spine')
                if outfit=='cardigan':
                    for y in (.89,.98,1.07):sphere('Button',(.025,.025,.02),(.12,y,-.18),region=3,bone='Spine')
                if outfit=='hi_vis':
                    for s in (-1,1):box('Safety stripe',(.045,.43,.025),(s*.17,1.0,-.145),region=5,bone='Spine')
        collect('Outfit_'+outfit,clothes)
    for prop in ('clipboard_shield','keyboard_booster','policy_binder','coffee_tower','calculator_dash','mop_lance','waiver_scroll','webcam_drone'):
        def accessory(prop=prop):
            if prop in ('clipboard_shield','policy_binder','waiver_scroll'):
                box('Cover',(.25,.34,.055),(.42,.98,-.28),region=3,bone='Forearm.R')
                box('Paper',(.21,.28,.015),(.42,.98,-.316),region=5,bone='Forearm.R')
                for y in (.9,.97,1.04):box('Print',(.13,.012,.01),(.42,y,-.328),bevel=.002,region=4,bone='Forearm.R')
                if prop=='waiver_scroll':box('Trailing paper',(.21,.25,.02),(.42,.72,-.27),region=5,bone='Forearm.R')
            elif prop=='coffee_tower':
                box('Tray',(.27,.035,.25),(.42,.85,-.3),region=4,bone='Forearm.R')
                for i in range(3):
                    rod('Cup',(.42,.9+i*.14,-.3),(.42,1.02+i*.14,-.3),.061,region=5,bone='Forearm.R')
                    rod('Lid',(.42,1.02+i*.14,-.3),(.42,1.035+i*.14,-.3),.068,region=4,bone='Forearm.R')
            elif prop=='mop_lance':
                rod('Mop handle',(.42,.6,.05),(.42,1.7,.05),.018,region=3,bone='Spine')
                box('Mop',(.25,.13,.14),(.42,1.7,.05),region=5,bone='Spine')
            elif prop=='webcam_drone':
                box('Webcam',(.22,.13,.13),(.44,1.5,.1),region=3,bone='Head')
                sphere('Lens',(.07,.07,.02),(.44,1.5,.025),region=4,bone='Head')
            else:
                keyboard=prop=='keyboard_booster';pos=(0,.85,.3) if keyboard else (.41,.95,-.3)
                box('Device',(.48 if keyboard else .2,.19,.06),pos,region=4,bone='Spine')
                for i in range(6 if keyboard else 3):
                    for j in range(2):box('Key',(.045,.038,.015),(pos[0]-.2+i*.075 if keyboard else pos[0]-.06+i*.06,pos[1]-.04+j*.07,pos[2]-.04),bevel=.004,region=5,bone='Spine')
        collect('Prop_'+prop,accessory)
    # One skeleton, shared by every modular mesh and body-build variant.
    bpy.ops.object.armature_add(enter_editmode=True);rig=bpy.context.object;rig.name='CoworkerRig';bones=rig.data.edit_bones;bones.remove(bones[0])
    specs={'Root':((0,.6,0),(0,.75,0),None),'Spine':((0,.7,0),(0,1.24,0),'Root'),'Head':((0,1.24,0),(0,1.69,0),'Spine')}
    for s,side in [(-1,'L'),(1,'R')]:
        specs['Arm.'+side]=((s*.22,1.18,0),(s*.3,.93,-.07),'Spine');specs['Forearm.'+side]=((s*.3,.93,-.07),(s*.3,.85,-.32),'Arm.'+side)
        specs['Thigh.'+side]=((s*.13,.65,0),(s*.13,.57,-.34),'Root');specs['Shin.'+side]=((s*.13,.57,-.34),(s*.13,.2,-.4),'Thigh.'+side)
    for name,(a,b,parent) in specs.items():
        bone=bones.new(name);bone.head=g(a);bone.tail=g(b)
        if parent:bone.parent=bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in groups.values():
        mod=obj.modifiers.new('Shared seated rig','ARMATURE');mod.object=rig;obj.parent=rig
    for clip in ('Idle','Push','Boost','Air','Land','Stun'):
        rig.animation_data_create();action=bpy.data.actions.new(clip);rig.animation_data.action=action
        for frame in (1,9,17,25,33):
            phase=(frame-1)/32*math.tau
            for name in specs:
                bone=rig.pose.bones[name];bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0)
                if name=='Spine':bone.rotation_euler.x=(.045*math.sin(phase) if clip=='Idle' else -.12 if clip=='Boost' else .1*math.sin(phase) if clip in ('Stun','Land') else .035*math.sin(phase))
                if clip=='Air' and name.startswith('Arm.'):bone.rotation_euler.z=.65 if name.endswith('L') else -.65
                if clip=='Push' and name.startswith('Shin.'):bone.rotation_euler.x=math.sin(phase+(math.pi if name.endswith('R') else 0))*.22
                if clip in ('Stun','Land') and name=='Head':bone.rotation_euler.y=math.sin(phase)*.2
                bone.keyframe_insert('rotation_euler',frame=frame,group=name)
        track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action)
        rig.animation_data.action=None
    bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=33
    export('coworker')

def furniture(name):
    reset()
    if name=='desk':
        box('Laminate top',(2.3,.12,1.0),(0,.83,0),'wood',.055)
        box('Edge band',(2.32,.04,1.02),(0,.78,0),'ivory',.012)
        for x in (-.98,.98):
            rod('Leg',(x,.03,.37),(x,.78,.37),.035);rod('Leg',(x,.03,-.37),(x,.78,-.37),.035)
        box('Cable tray',(1.7,.08,.18),(0,.66,.25),'ink')
        box('Monitor',(1.0,.6,.065),(0,1.28,.25),'ink',.04);box('Display',(.91,.5,.014),(0,1.28,.207),'blue',.012)
        rod('Stand',(0,.9,.25),(0,1.12,.25),.035);box('Foot',(.36,.025,.22),(0,.91,.25),'metal')
        box('Keyboard',(.65,.035,.22),(0,.92,-.28),'ink',.02)
        for i in range(10):
            for j in range(3):box('Key',(.043,.01,.04),(-.27+i*.06,.944,-.35+j*.06),'ivory',.004)
        rod('Coffee',(.7,.9,-.2),(.7,1.05,-.2),.055,'ivory')
    elif name=='sofa':
        box('Base',(2.4,.32,.85),(0,.38,0),'ink',.1)
        for x in (-.62,.62):box('Cushion',(1.1,.23,.75),(x,.6,-.02),'teal',.11)
        box('Back',(2.4,.8,.2),(0,.9,.35),'teal',.12)
        for x in (-1.2,1.2):box('Arm',(.23,.6,.85),(x,.7,0),'teal',.1)
        for x in (-.95,.95):
            for z in (-.3,.3):rod('Foot',(x,.03,z),(x,.25,z),.035)
    elif name=='cabinet':
        box('Case',(1,.95,.5),(0,.5,0),'ivory',.035)
        for y in (.23,.53,.83):
            box('Drawer',(.9,.26,.04),(0,y,-.265),'teal',.015);box('Pull',(.25,.025,.045),(0,y+.05,-.3),'metal',.012)
    elif name=='plant':
        rod('Pot',(0,0,0),(0,.45,0),.25,'ivory');rod('Stem',(0,.35,0),(0,1.5,0),.025,'wood')
        for i in range(12):
            a=i*2.4;y=.55+i*.07;x=math.cos(a)*.32;z=math.sin(a)*.32
            rod('Branch',(0,y,0),(x,y+.13,z),.01,'green');o=sphere('Leaf',(.25,.085,.45),(x,y+.14,z),'green');o.rotation_euler.z=a
    elif name=='printer':
        box('Cabinet',(1.1,.75,.8),(0,.38,0),'ivory',.08);box('Upper',(1.05,.25,.7),(0,.87,.05),'ivory',.06)
        box('Scanner lid',(.98,.05,.65),(0,1.04,.05),'ink',.04);box('Output slot',(.7,.12,.025),(0,.7,-.42),'ink',.01)
        box('Paper',(.48,.03,.34),(0,.74,-.48),'paper',.01);box('Controls',(.2,.08,.12),(.38,.97,-.35),'blue')
    elif name=='vending':
        box('Case',(1.2,2.2,.8),(0,1.1,0),'teal',.08);box('Window',(.72,1.35,.03),(-.14,1.35,-.42),'ink',.04)
        for x in (-.37,-.1,.17):
            for y in (.85,1.2,1.55,1.9):box('Snack',(.16,.17,.08),(x,y,-.45),'orange' if x<0 else 'ivory',.035)
        box('Keypad',(.15,.3,.05),(.43,1.3,-.44),'metal');box('Pickup',(.78,.2,.04),(-.1,.36,-.42),'ink')
    elif name=='water':
        box('Stand',(.55,.9,.5),(0,.45,0),'ivory',.06);rod('Bottle',(0,.95,0),(0,1.45,0),.2,'blue')
        box('Tap',(.1,.08,.09),(0,.75,-.29),'teal')
    elif name=='meeting':
        box('Table',(5,.14,1.8),(0,.82,0),'wood',.13)
        for x in (-1.6,1.6):box('Support',(.12,.8,1.1),(x,.4,0),'ink',.025)
        for x in (-1.4,0,1.4):
            box('Pad',(.5,.015,.38),(x,.9,0),'blue',.02);rod('Mug',(x+.35,.9,.1),(x+.35,1.05,.1),.06,'ivory')
    elif name=='shelf':
        for y in (.15,.75,1.35,1.95):box('Shelf',(2.3,.08,.65),(0,y,0),'ivory')
        for x in (-1.1,1.1):box('Upright',(.06,2.1,.65),(x,1.05,0),'metal')
        for i in range(16):
            x=-.9+(i%4)*.55;y=.36+(i//4)*.6
            box('Package',(.3,.32,.3),(x,y,0),'orange' if i%3==0 else 'teal' if i%3==1 else 'wood',.025)
    merge(name,[o for o in bpy.context.scene.objects if o.type=='MESH']);export(name)

def pizza_assets():
    reset();C['sauce']=(.44,.055,.025,1);C['cheese']=(.95,.58,.16,1);C['crust']=(.55,.27,.09,1)
    rod('Baked base',(0,-.6,0),(0,-.2,0),17.8,'crust')
    rod('Tomato sauce',(0,-.2,0),(0,-.12,0),17.2,'sauce')
    rod('Mozzarella',(0,-.12,0),(0,-.03,0),16.9,'cheese')
    bpy.ops.mesh.primitive_torus_add(major_radius=17.2,minor_radius=.6,major_segments=64,minor_segments=8,location=g((0,-.12,0)))
    finish(bpy.context.object,'Rolled crust',color='crust')
    for i in range(38):
        a=i*2.39996;r=3+((i*7)%13)
        x=math.cos(a)*r;z=math.sin(a)*r
        rod('Pepperoni',(x,-.01,z),(x,.055,z),.55,'sauce')
        for j in range(3):
            b=a+j*2.1;rod('Speck',(x+math.cos(b)*.25,.055,z+math.sin(b)*.25),(x+math.cos(b)*.25,.068,z+math.sin(b)*.25),.055,'ivory')
    for i in range(18):
        a=i*2.7;r=5+i%10;o=sphere('Basil',(.4,.08,.9),(math.cos(a)*r,.04,math.sin(a)*r),'green');o.rotation_euler.z=a
    merge('Pizza',[o for o in bpy.context.scene.objects if o.type=='MESH']);export('pizza')
    reset();rod('Chef hat band',(0,0,0),(0,.12,0),.18,'ivory')
    for x,z in ((0,0),(-.1,0),(.1,0),(0,-.09),(0,.09)):sphere('Toque',(.25,.28,.25),(x,.18,z),'ivory')
    merge('ChefHat',[o for o in bpy.context.scene.objects if o.type=='MESH']);export('chef_hat')

def cosmetic_chair(kind):
    reset()
    if kind=='bean_bag':
        body_mesh('Upholstered sack',[(.02,.22,.18,0),(.12,.4,.35,.03),(.4,.46,.38,.07),(.62,.32,.28,.16),(.9,.23,.16,.26),(1.0,.12,.09,.28)],2,'Root')
        o=bpy.data.objects['Upholstered sack'];o.data.materials.clear();o.data.materials.append(mat('teal'));o.vertex_groups.clear()
        rod('Seam',(-.35,.24,-.24),(.35,.24,-.24),.009,'ivory')
    elif kind=='exercise_ball':
        sphere('Stability ball',(.86,.86,.86),(0,.43,0),'teal')
        for y in (.23,.43,.63):
            bpy.ops.mesh.primitive_torus_add(major_radius=math.sqrt(.43**2-(y-.43)**2),minor_radius=.008,major_segments=24,minor_segments=6,location=g((0,y,0)))
            finish(bpy.context.object,'Grip band',color='ink')
    elif kind=='toilet':
        sphere('Porcelain bowl',(.65,.4,.85),(0,.48,-.1),'ivory')
        box('Pedestal',(.35,.42,.46),(0,.24,.02),'ivory',.14)
        box('Cistern',(.63,.6,.23),(0,.9,.31),'ivory',.08)
        box('Lid',(.68,.06,.28),(0,1.22,.31),'ivory',.045)
        box('Lever',(.14,.04,.05),(.21,1.05,.17),'metal',.02)
        sphere('Seat ring',(.64,.07,.75),(0,.68,-.12),'ink')
        sphere('Seat insert',(.44,.075,.5),(0,.68,-.15),'ivory')
    elif kind=='shopping_cart':
        for x in (-.34,.34):
            rod('Upright',(x,.16,.28),(x,1.05,.28),.022)
            rod('Base',(x,.16,-.46),(x,.16,.28),.025)
            for z in (-.4,.28):sphere('Caster',(.13,.13,.13),(x,.08,z),'ink')
        rod('Handle',(-.34,1.05,.28),(.34,1.05,.28),.035,'teal')
        for y in (.4,.6,.8):
            for z in (-.47,.22):rod('Basket rail',(-.36,y,z),(.36,y,z),.012)
            for x in (-.36,.36):rod('Basket rail',(x,y,-.47),(x,y,.22),.012)
        for x in (-.36,-.18,0,.18,.36):
            for z in (-.47,.22):rod('Wire',(x,.38,z),(x,.82,z),.008)
        box('Basket seat',(.67,.07,.63),(0,.58,-.08),'teal')
    else:
        box('Bucket seat',(.62,.18,.55),(0,.62,-.03),'ink',.09)
        box('Backrest',(.55,.75,.16),(0,1.03,.22),'teal',.1)
        for x in (-.32,.32):
            box('Side bolster',(.12,.5,.28),(x,.88,.12),'ink',.05)
            rod('Harness',(x*.55,.74,.1),(x*.55,1.33,.1),.026,'orange')
        for x in (-.3,.3):
            for z in (-.28,.28):sphere('Wheel',(.14,.14,.14),(x,.09,z),'ink')
        box('Chassis',(.68,.13,.62),(0,.22,0),'metal')
    merge(kind,[o for o in bpy.context.scene.objects if o.type=='MESH']);export('chair_'+kind)

def chair():
    reset();source=Path('/tmp/friday-nvidia-chair/simready_usd/sm_chair_office_fabric_manager_a01_01.usd')
    if not source.exists():raise SystemExit('NVIDIA chair source missing; run fetch_nvidia_chair.py')
    bpy.ops.wm.usd_import(filepath=str(source),import_materials=False,import_cameras=False,import_lights=False,support_scene_instancing=False)
    bpy.context.view_layer.update()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if not meshes:raise SystemExit('NVIDIA import produced no meshes')
    # USD parts are parented; bake world transforms before joining them.
    # Otherwise the active part's parent distorts the merged chair on export.
    for obj in meshes:
        world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=world
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # Flatten transforms and optimize all submeshes into a small material palette.
    for obj in meshes:
        bpy.context.view_layer.objects.active=obj
        if len(obj.data.polygons)>600:
            d=obj.modifiers.new('Game LOD','DECIMATE');d.ratio=min(1,4500/max(1,sum(len(m.data.polygons) for m in meshes)));bpy.ops.object.modifier_apply(modifier=d.name)
        obj.data.materials.clear();obj.data.materials.append(mat('teal' if any(s in obj.name.lower() for s in ('seat','back','cushion','fabric')) else 'metal' if any(s in obj.name.lower() for s in ('base','gas','arm','metal','steel')) else 'ink'))
    combined=merge('NVIDIA_OfficeChair',meshes)
    corners=[combined.matrix_world@Vector(v) for v in combined.bound_box]
    minimum=Vector(tuple(min(v[i] for v in corners) for i in range(3)));maximum=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
    height=maximum.z-minimum.z
    scale=1.25/height
    combined.location-=Vector(((minimum.x+maximum.x)/2,(minimum.y+maximum.y)/2,minimum.z));combined.scale*=scale;combined.location*=scale
    bpy.ops.object.select_all(action='DESELECT');combined.select_set(True);bpy.context.view_layer.objects.active=combined;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for o in list(bpy.context.scene.objects):
        if o!=combined:bpy.data.objects.remove(o,do_unlink=True)
    combined.data.calc_loop_triangles()
    d=combined.modifiers.new('Runtime triangle budget','DECIMATE');d.ratio=min(1,5500/max(1,len(combined.data.loop_triangles)))
    bpy.context.view_layer.objects.active=combined;bpy.ops.object.modifier_apply(modifier=d.name)
    export('office_chair')
    # Preserve actual authored LOD resources for distant avatars.
    for name,ratio in [('office_chair_lod1',.48),('office_chair_lod2',.28)]:
        copy=combined.copy();copy.data=combined.data.copy();bpy.context.collection.objects.link(copy)
        d=copy.modifiers.new('Distance LOD','DECIMATE');d.ratio=ratio;bpy.context.view_layer.objects.active=copy;bpy.ops.object.modifier_apply(modifier=d.name)
        export(name,[copy]);bpy.data.objects.remove(copy,do_unlink=True)

if __name__=='__main__':
    if '--pizza-only' in sys.argv:
        pizza_assets();sys.exit(0)
    pizza_assets()
    worker()
    for name in ('desk','sofa','cabinet','plant','printer','vending','water','meeting','shelf'):furniture(name)
    chair()
    for name in ('bean_bag','exercise_ball','shopping_cart','toilet','racing_seat'):cosmetic_chair(name)
