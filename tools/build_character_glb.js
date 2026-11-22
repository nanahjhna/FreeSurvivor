// node tools/build_character_glb.js [output.glb]
// Keep the character's mesh, skin and materials. Bake only the selected motions.
const fs = require('node:fs');
const path = require('node:path');

const project = path.resolve(__dirname, '..');
const target = readGlb(path.join(project, 'assets/source/char01/char01.glb'));
const source = readGlb(path.join(project, 'assets/source/rig/rig-model.glb'));
const output = process.argv[2] || path.join(project, 'assets/char/char01_game.glb');
const clips = {
  Idle: 'Rifle_Idle',
  Walk: 'Rifle_Walk',
  Run: 'Rifle_Run',
  Attack: 'Rifle_Fire',
  AttackAlt: 'Shoot_Rifle',
  Reload: 'Rifle_Reload',
  Hit: 'Rifle_Hit_To_Back',
  Death: 'Rifle_Run_To_Dying',
};

const names = {
  Hips: 'Hips', Waist: 'Spine', Spine01: 'Spine2', Neck: 'Neck', Head: 'Head',
};
for (const [side, mixamoSide] of [['L', 'Left'], ['R', 'Right']]) {
  const limbs = {
    Clavicle: 'Shoulder', UpperArm: 'Arm', Forearm: 'ForeArm', Hand: 'Hand',
    Thigh: 'UpLeg', Calf: 'Leg', Foot: 'Foot', Toe: 'ToeBase',
  };
  for (const [bone, mixamoBone] of Object.entries(limbs)) {
    names[side + '_' + bone] = mixamoSide + mixamoBone;
  }
  for (const [finger, fingerName] of ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'].entries()) {
    for (let joint = 0; joint < 3; joint++) {
      names[side + '_Finger' + finger + joint] = mixamoSide + 'Hand' + fingerName + (joint + 1);
    }
  }
}

const sourceRig = readRig(source.json);
const targetRig = readRig(target.json);
const mappings = new Map(Object.entries(names).map(([bone, match]) => [
  requireBone(targetRig, 'Amelia_SantaRL_' + bone),
  requireBone(sourceRig, 'mixamorig' + match),
]));
const targetHip = requireBone(targetRig, 'Amelia_SantaRL_Hips');
const sourceHip = mappings.get(targetHip);
const targetRest = samplePose(targetRig, readClip(target, 'Rest_Pose_RT'), 0);
const sourceRest = samplePose(sourceRig, readClip(source, 'Rest_Pose'), 0);
const targetParent = targetRig.parents[targetHip];
const bodyRatio = targetRest.world[targetHip].position[1] / sourceRest.world[sourceHip].position[1];
const rotationOffsets = new Map([...mappings].map(([bone, match]) => [
  bone, multiply(inverse(sourceRest.world[match].rotation), targetRest.world[bone].rotation),
]));

const chunks = [target.bin];
let byteLength = target.bin.length;
target.json.animations = Object.entries(clips).map(([name, sourceName]) => bake(name, sourceName));
for (const bone of target.json.skins[0].joints) {
  target.json.nodes[bone].rotation = targetRest.rotations[bone];
}
target.json.nodes[targetHip].translation = targetRest.positions[targetHip];
target.json.buffers[0].byteLength = byteLength;
writeGlb(output, target.json, Buffer.concat(chunks, byteLength));
console.log(path.basename(output) + ': ' + Object.keys(clips).join(', ') + ' from rig-model.glb');

function bake(name, sourceName) {
  const sourceClip = readClip(source, sourceName);
  const frameCount = Math.max(1, Math.round(sourceClip.duration * 30));
  const times = Array.from({length: frameCount + 1}, (_, i) => i * sourceClip.duration / frameCount);
  const rotations = new Map([...mappings.keys()].map(bone => [bone, []]));
  const hips = [];
  const timeAccessor = appendStream(times, 'SCALAR', [0], [sourceClip.duration]);
  const startHip = samplePose(sourceRig, sourceClip, 0).world[sourceHip].position;
  const parentRest = targetRest.world[targetParent];
  const invParentRotation = inverse(parentRest.rotation);

  for (const time of times) {
    const pose = samplePose(sourceRig, sourceClip, time);
    const worldRotations = [];
    for (const bone of targetRig.order) {
      const parent = worldRotations[targetRig.parents[bone]] || [0, 0, 0, 1];
      const match = mappings.get(bone);
      if (match === undefined) {
        worldRotations[bone] = multiply(parent, targetRest.rotations[bone]);
        continue;
      }
      const rotation = normalize(multiply(pose.world[match].rotation, rotationOffsets.get(bone)));
      const local = normalize(multiply(inverse(parent), rotation));
      const keys = rotations.get(bone);
      if (keys.length && dot(keys.at(-1), local) < 0) {
        keys.push(local.map(value => -value));
      } else {
        keys.push(local);
      }
      worldRotations[bone] = rotation;
    }

    // Retain vertical motion, but keep the model from walking away from its player collider.
    const origin = pose.world[sourceHip].position;
    const reference = sourceRest.world[sourceHip].position;
    const delta = startHip.map((value, i) => ((i === 1 ? origin[i] : value) - reference[i]) * bodyRatio);
    const localOffset = rotate(invParentRotation, delta).map((value, i) => value / parentRest.scale[i]);
    hips.push(targetRest.positions[targetHip].map((value, i) => value + localOffset[i]));
  }

  const animation = {name, channels: [], samplers: []};
  for (const [node, keys] of rotations) addTrack(node, 'rotation', keys.flat(), 'VEC4');
  addTrack(targetHip, 'translation', hips.flat(), 'VEC3');
  return animation;

  function addTrack(node, property, values, type) {
    animation.channels.push({sampler: animation.samplers.length, target: {node, path: property}});
    animation.samplers.push({input: timeAccessor, output: appendStream(values, type), interpolation: 'LINEAR'});
  }
}

function readRig(json) {
  const nodes = json.nodes;
  const ids = new Map(nodes.map((node, i) => [node.name, i]));
  const parents = Array(nodes.length).fill(-1);
  nodes.forEach((node, i) => node.children?.forEach(child => { parents[child] = i; }));
  const order = [];
  function visit(i) {
    order.push(i);
    nodes[i].children?.forEach(visit);
  }
  parents.forEach((parent, i) => { if (parent === -1) visit(i); });
  return {nodes, ids, parents, order};
}

function requireBone(rig, name) {
  const id = rig.ids.get(name);
  if (id === undefined) throw new Error('Missing bone: ' + name);
  return id;
}

function readClip(glb, name) {
  const clip = glb.json.animations.find(a => a.name === name);
  if (!clip) throw new Error('Missing animation: ' + name);
  const tracks = clip.channels.map(({target: bone, sampler}) => {
    const settings = clip.samplers[sampler];
    if (settings.interpolation && !['LINEAR', 'STEP'].includes(settings.interpolation)) {
      throw new Error('Unsupported interpolation in ' + name + ': ' + settings.interpolation);
    }
    const times = readStream(glb, settings.input).map(value => value[0]);
    return {node: bone.node, property: bone.path, times, values: readStream(glb, settings.output), step: settings.interpolation === 'STEP'};
  });
  return {tracks, duration: Math.max(...tracks.map(track => track.times.at(-1)))};
}

function samplePose(rig, clip, time) {
  const rotations = rig.nodes.map(node => node.rotation || [0, 0, 0, 1]);
  const positions = rig.nodes.map(node => node.translation || [0, 0, 0]);
  const world = [];
  for (const track of clip.tracks) {
    if (track.property === 'rotation') rotations[track.node] = interpolate(track, time, true);
    if (track.property === 'translation') positions[track.node] = interpolate(track, time, false);
  }
  for (const bone of rig.order) {
    const parent = world[rig.parents[bone]];
    const scale = rig.nodes[bone].scale || [1, 1, 1];
    if (!parent) {
      world[bone] = {position: positions[bone], rotation: rotations[bone], scale};
      continue;
    }
    const offset = rotate(parent.rotation, positions[bone].map((value, i) => value * parent.scale[i]));
    world[bone] = {
      position: offset.map((value, i) => value + parent.position[i]),
      rotation: normalize(multiply(parent.rotation, rotations[bone])),
      scale: scale.map((value, i) => value * parent.scale[i]),
    };
  }
  return {rotations, positions, world};
}

function interpolate({times, values, step}, time, rotation) {
  let right = times.findIndex(value => value >= time - 0.000001);
  if (right < 0) right = times.length - 1;
  if (right === 0 || time >= times[right] - 0.000001) return values[right];
  const left = right - 1;
  if (step) return values[left];
  const fraction = (time - times[left]) / (times[right] - times[left]);
  const first = values[left];
  const second = values[right];
  const sign = rotation && dot(first, second) < 0 ? -1 : 1;
  const value = first.map((component, i) => component * (1 - fraction) + second[i] * sign * fraction);
  return rotation ? normalize(value) : value;
}

function readStream(glb, index) {
  const accessor = glb.json.accessors[index];
  const view = glb.json.bufferViews[accessor.bufferView];
  const width = {SCALAR: 1, VEC3: 3, VEC4: 4}[accessor.type];
  if (!width || accessor.componentType !== 5126 || accessor.sparse) {
    throw new Error('Expected dense float animation accessor ' + index);
  }
  const start = (view.byteOffset || 0) + (accessor.byteOffset || 0);
  const stride = view.byteStride || width * 4;
  return Array.from({length: accessor.count}, (_, key) =>
    Array.from({length: width}, (_, i) => glb.bin.readFloatLE(start + key * stride + i * 4)));
}

function appendStream(values, type, min, max) {
  const width = {SCALAR: 1, VEC3: 3, VEC4: 4}[type];
  const bytes = Buffer.allocUnsafe(values.length * 4);
  values.forEach((value, i) => bytes.writeFloatLE(value, i * 4));
  const bufferView = target.json.bufferViews.push({buffer: 0, byteOffset: byteLength, byteLength: bytes.length}) - 1;
  chunks.push(bytes);
  byteLength += bytes.length;
  const accessor = {bufferView, componentType: 5126, type, count: values.length / width};
  if (min) Object.assign(accessor, {min, max});
  return target.json.accessors.push(accessor) - 1;
}

function multiply([x, y, z, w], [a, b, c, d]) {
  return [w*a+x*d+y*c-z*b, w*b-x*c+y*d+z*a, w*c+x*b-y*a+z*d, w*d-x*a-y*b-z*c];
}
function inverse([x, y, z, w]) { return [-x, -y, -z, w]; }
function dot(a, b) { return a.reduce((sum, value, i) => sum + value * b[i], 0); }
function normalize(q) { const length = Math.sqrt(dot(q, q)); return q.map(value => value / length); }
function rotate(q, v) { return multiply(multiply(q, [...v, 0]), inverse(q)).slice(0, 3); }

function readGlb(filename) {
  const file = fs.readFileSync(filename);
  if (file.toString('ascii', 0, 4) !== 'glTF' || file.readUInt32LE(4) !== 2) {
    throw new Error('Expected glTF 2: ' + filename);
  }
  const size = file.readUInt32LE(12);
  return {json: JSON.parse(file.toString('utf8', 20, 20 + size)), bin: file.subarray(28 + size)};
}

function writeGlb(filename, json, bin) {
  const raw = Buffer.from(JSON.stringify(json));
  const contents = Buffer.alloc(Math.ceil(raw.length / 4) * 4, 0x20);
  raw.copy(contents);
  const header = Buffer.alloc(20);
  header.write('glTF');
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(28 + contents.length + bin.length, 8);
  header.writeUInt32LE(contents.length, 12);
  header.write('JSON', 16);
  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(bin.length);
  binHeader.write('BIN', 4);
  fs.writeFileSync(filename, Buffer.concat([header, contents, binHeader, bin]));
}
