// Merge glTF primitives that share one skinned vertex stream and material.
// This reduces monster01 from 71 draw surfaces to two without changing vertices or animation.
const fs = require("fs");
const path = require("path");

const source = path.resolve(__dirname, "../assets/monster/monster01/monster01.glb");
const output = path.resolve(__dirname, "../assets/monster/monster01/monster01_optimized.glb");
const glb = fs.readFileSync(source);
if (glb.toString("ascii", 0, 4) !== "glTF" || glb.readUInt32LE(4) !== 2) {
  throw new Error("Expected a glTF 2.0 binary asset");
}
const jsonLength = glb.readUInt32LE(12);
const json = JSON.parse(glb.subarray(20, 20 + jsonLength).toString("utf8"));
const binHeader = 20 + jsonLength;
if (glb.readUInt32LE(binHeader + 4) !== 0x004e4942) {
  throw new Error("Expected a BIN chunk");
}
const binLength = glb.readUInt32LE(binHeader);
const bin = glb.subarray(binHeader + 8, binHeader + 8 + binLength);
const primitives = json.meshes[0].primitives;
const clips = new Map([
  ["Zombie_Idle_RT", "Idle"],
  ["Zombie_Walk_RT", "Walk"],
  ["Zombie_Attack_RT", "Attack"],
  ["Zombie_Reaction_Hit_RT", "Hit"],
  ["Zombie_Death_RT", "Death"],
]);
json.animations = [...clips].map(([sourceName, newName]) => {
  const clip = json.animations.find((animation) => animation.name === sourceName);
  if (!clip) throw new Error(`Missing animation ${sourceName}`);
  return { ...clip, name: newName };
});
const groups = new Map();
let oldTriangleCount = 0;

for (const primitive of primitives) {
  if (primitive.mode !== 4 || primitive.targets) {
    throw new Error("Only triangle primitives without morph targets can be merged");
  }
  const accessor = json.accessors[primitive.indices];
  const view = json.bufferViews[accessor.bufferView];
  if (accessor.componentType !== 5123 || accessor.type !== "SCALAR" || view.byteStride) {
    throw new Error("Expected tightly packed 16-bit indices");
  }
  const key = JSON.stringify({ material: primitive.material, attributes: primitive.attributes });
  if (!groups.has(key)) {
    groups.set(key, { material: primitive.material, attributes: primitive.attributes, indices: [] });
  }
  const offset = view.byteOffset + (accessor.byteOffset || 0);
  for (let i = 0; i < accessor.count; i++) {
    groups.get(key).indices.push(bin.readUInt16LE(offset + i * 2));
  }
  oldTriangleCount += accessor.count / 3;
}

const chunks = [bin];
let binaryLength = bin.length;
const merged = [];
for (const group of groups.values()) {
  const padding = (4 - (binaryLength % 4)) % 4;
  if (padding) {
    chunks.push(Buffer.alloc(padding));
    binaryLength += padding;
  }
  const indices = Buffer.alloc(group.indices.length * 2);
  group.indices.forEach((index, i) => indices.writeUInt16LE(index, i * 2));
  const viewIndex = json.bufferViews.length;
  json.bufferViews.push({ buffer: 0, byteOffset: binaryLength, byteLength: indices.length, target: 34963 });
  const accessorIndex = json.accessors.length;
  json.accessors.push({
    bufferView: viewIndex,
    componentType: 5123,
    count: group.indices.length,
    min: [Math.min(...group.indices)],
    max: [Math.max(...group.indices)],
    type: "SCALAR",
  });
  merged.push({ mode: 4, attributes: group.attributes, indices: accessorIndex, material: group.material });
  chunks.push(indices);
  binaryLength += indices.length;
}
json.meshes[0].primitives = merged;
json.buffers[0].byteLength = binaryLength;
const finalBinPadding = (4 - (binaryLength % 4)) % 4;
if (finalBinPadding) chunks.push(Buffer.alloc(finalBinPadding));
let finalBin = Buffer.concat(chunks);
// The source also contains 22 unused animation clips. Repack the referenced
// buffer views so their keyframes and the original 71 index buffers are omitted.
const usedAccessors = new Set();
for (const mesh of json.meshes) {
  for (const primitive of mesh.primitives) {
    usedAccessors.add(primitive.indices);
    Object.values(primitive.attributes).forEach((index) => usedAccessors.add(index));
  }
}
for (const skin of json.skins || []) {
  if (skin.inverseBindMatrices !== undefined) usedAccessors.add(skin.inverseBindMatrices);
}
for (const animation of json.animations) {
  for (const sampler of animation.samplers) {
    usedAccessors.add(sampler.input);
    usedAccessors.add(sampler.output);
  }
}
const accessorRemap = new Map();
const retainedAccessors = [];
for (const oldIndex of [...usedAccessors].sort((a, b) => a - b)) {
  const accessor = { ...json.accessors[oldIndex] };
  if (accessor.sparse) throw new Error("Sparse accessors are not supported");
  accessorRemap.set(oldIndex, retainedAccessors.length);
  retainedAccessors.push(accessor);
}
const usedViews = new Set(retainedAccessors.map((accessor) => accessor.bufferView));
for (const image of json.images || []) {
  if (image.bufferView !== undefined) usedViews.add(image.bufferView);
}
const viewRemap = new Map();
const retainedViews = [];
const packedViews = [];
let packedLength = 0;
for (const oldIndex of [...usedViews].sort((a, b) => a - b)) {
  const view = json.bufferViews[oldIndex];
  const padding = (4 - (packedLength % 4)) % 4;
  if (padding) {
    packedViews.push(Buffer.alloc(padding));
    packedLength += padding;
  }
  viewRemap.set(oldIndex, retainedViews.length);
  retainedViews.push({ ...view, byteOffset: packedLength });
  packedViews.push(finalBin.subarray(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength));
  packedLength += view.byteLength;
}
for (const accessor of retainedAccessors) accessor.bufferView = viewRemap.get(accessor.bufferView);
for (const image of json.images || []) {
  if (image.bufferView !== undefined) image.bufferView = viewRemap.get(image.bufferView);
}
for (const mesh of json.meshes) {
  for (const primitive of mesh.primitives) {
    primitive.indices = accessorRemap.get(primitive.indices);
    for (const attribute of Object.keys(primitive.attributes)) {
      primitive.attributes[attribute] = accessorRemap.get(primitive.attributes[attribute]);
    }
  }
}
for (const skin of json.skins || []) {
  if (skin.inverseBindMatrices !== undefined) skin.inverseBindMatrices = accessorRemap.get(skin.inverseBindMatrices);
}
for (const animation of json.animations) {
  for (const sampler of animation.samplers) {
    sampler.input = accessorRemap.get(sampler.input);
    sampler.output = accessorRemap.get(sampler.output);
  }
}
json.accessors = retainedAccessors;
json.bufferViews = retainedViews;
json.buffers[0].byteLength = packedLength;
const packedPadding = (4 - (packedLength % 4)) % 4;
if (packedPadding) packedViews.push(Buffer.alloc(packedPadding));
finalBin = Buffer.concat(packedViews);
const jsonBuffer = Buffer.from(JSON.stringify(json));
const jsonPadding = (4 - (jsonBuffer.length % 4)) % 4;
const finalJson = Buffer.concat([jsonBuffer, Buffer.alloc(jsonPadding, 0x20)]);
const header = Buffer.alloc(12);
header.write("glTF", 0, "ascii");
header.writeUInt32LE(2, 4);
header.writeUInt32LE(12 + 8 + finalJson.length + 8 + finalBin.length, 8);
const jsonHeader = Buffer.alloc(8);
jsonHeader.writeUInt32LE(finalJson.length, 0);
jsonHeader.writeUInt32LE(0x4e4f534a, 4);
const binaryHeader = Buffer.alloc(8);
binaryHeader.writeUInt32LE(finalBin.length, 0);
binaryHeader.writeUInt32LE(0x004e4942, 4);
fs.writeFileSync(output, Buffer.concat([header, jsonHeader, finalJson, binaryHeader, finalBin]));
const newTriangleCount = merged.reduce((count, primitive) => count + json.accessors[primitive.indices].count / 3, 0);
if (newTriangleCount !== oldTriangleCount) throw new Error("Triangle count changed");
console.log(`${path.basename(output)}: ${primitives.length} -> ${merged.length} surfaces, ${newTriangleCount} triangles, ${json.animations.length} clips`);
