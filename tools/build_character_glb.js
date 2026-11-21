// Build the small in-game model from the user's animation library without dependencies.
const fs = require('fs');
const path = require('path');

const source = path.resolve(__dirname, '../assets/char/char01/char01.glb');
const target = path.resolve(__dirname, '../assets/char/char01_game.glb');
const clips = [
  ['Breathing_Idle_RT', 'Idle'],
  ['Walking_RT', 'Walk'],
  ['Fast_Run_RT', 'Run'],
  ['Punch_Jab_RT', 'Attack'],
  ['Punch_Cross_RT', 'AttackAlt'],
  ['Kick_Front_RT', 'Kick'],
  ['Hit_Reaction_RT', 'Hit'],
  ['Death_RT', 'Death'],
];
const align4 = n => (n + 3) & ~3;
const fd = fs.openSync(source, 'r');
try {
  const header = Buffer.alloc(20);
  fs.readSync(fd, header, 0, 20, 0);
  if (header.toString('ascii', 0, 4) !== 'glTF' || header.readUInt32LE(4) !== 2) throw Error('Expected glTF 2 GLB');
  const jsonLength = header.readUInt32LE(12);
  const jsonChunk = Buffer.alloc(jsonLength);
  fs.readSync(fd, jsonChunk, 0, jsonLength, 20);
  const gltf = JSON.parse(jsonChunk.toString('utf8'));
  const sourceBinOffset = 20 + jsonLength + 8;
  const originalViews = gltf.bufferViews;
  const originalAccessors = gltf.accessors;

  gltf.animations = clips.map(([sourceName, name]) => {
    const animation = gltf.animations.find(a => a.name === sourceName);
    if (!animation) throw Error(`Missing animation ${sourceName}`);
    return { ...animation, name };
  });

  const usedAccessors = new Set();
  const keepAccessor = index => { if (index !== undefined) usedAccessors.add(index); };
  for (const mesh of gltf.meshes || []) for (const primitive of mesh.primitives) {
    keepAccessor(primitive.indices);
    Object.values(primitive.attributes || {}).forEach(keepAccessor);
    for (const targetAttributes of primitive.targets || []) Object.values(targetAttributes).forEach(keepAccessor);
  }
  for (const skin of gltf.skins || []) keepAccessor(skin.inverseBindMatrices);
  for (const animation of gltf.animations) for (const sampler of animation.samplers) {
    keepAccessor(sampler.input);
    keepAccessor(sampler.output);
  }
  const accessorIds = [...usedAccessors].sort((a, b) => a - b);
  const accessorMap = new Map(accessorIds.map((id, i) => [id, i]));
  const mapAccessor = id => accessorMap.get(id);
  for (const mesh of gltf.meshes || []) for (const primitive of mesh.primitives) {
    if (primitive.indices !== undefined) primitive.indices = mapAccessor(primitive.indices);
    for (const key of Object.keys(primitive.attributes || {})) primitive.attributes[key] = mapAccessor(primitive.attributes[key]);
    for (const targetAttributes of primitive.targets || []) for (const key of Object.keys(targetAttributes)) targetAttributes[key] = mapAccessor(targetAttributes[key]);
  }
  for (const skin of gltf.skins || []) if (skin.inverseBindMatrices !== undefined) skin.inverseBindMatrices = mapAccessor(skin.inverseBindMatrices);
  for (const animation of gltf.animations) for (const sampler of animation.samplers) {
    sampler.input = mapAccessor(sampler.input);
    sampler.output = mapAccessor(sampler.output);
  }
  gltf.accessors = accessorIds.map(id => ({ ...originalAccessors[id] }));

  const usedViews = new Set();
  for (const accessor of gltf.accessors) {
    if (accessor.bufferView !== undefined) usedViews.add(accessor.bufferView);
    if (accessor.sparse) {
      usedViews.add(accessor.sparse.indices.bufferView);
      usedViews.add(accessor.sparse.values.bufferView);
    }
  }
  for (const image of gltf.images || []) if (image.bufferView !== undefined) usedViews.add(image.bufferView);
  const viewIds = [...usedViews].sort((a, b) => a - b);
  const viewMap = new Map(viewIds.map((id, i) => [id, i]));
  const newViews = viewIds.map(id => ({ ...originalViews[id] }));
  for (const accessor of gltf.accessors) {
    if (accessor.bufferView !== undefined) accessor.bufferView = viewMap.get(accessor.bufferView);
    if (accessor.sparse) {
      accessor.sparse.indices.bufferView = viewMap.get(accessor.sparse.indices.bufferView);
      accessor.sparse.values.bufferView = viewMap.get(accessor.sparse.values.bufferView);
    }
  }
  for (const image of gltf.images || []) if (image.bufferView !== undefined) image.bufferView = viewMap.get(image.bufferView);

  let binLength = 0;
  for (const view of newViews) {
    binLength = align4(binLength);
    view.newOffset = binLength;
    binLength += view.byteLength;
  }
  const bin = Buffer.alloc(align4(binLength));
  for (let i = 0; i < newViews.length; i++) {
    const view = newViews[i];
    const oldView = originalViews[viewIds[i]];
    fs.readSync(fd, bin, view.newOffset, view.byteLength, sourceBinOffset + (oldView.byteOffset || 0));
    view.byteOffset = view.newOffset;
    delete view.newOffset;
  }
  gltf.bufferViews = newViews;
  gltf.buffers = [{ byteLength: binLength }];

  // Player movement owns world position. Keep hip height motion while making clips play in place.
  for (const animation of gltf.animations) {
    const channel = animation.channels.find(c => c.target.node === 1 && c.target.path === 'translation');
    if (!channel) continue;
    const accessor = gltf.accessors[animation.samplers[channel.sampler].output];
    if (accessor.componentType !== 5126 || accessor.type !== 'VEC3') continue;
    const view = newViews[accessor.bufferView];
    const base = view.byteOffset + (accessor.byteOffset || 0);
    const stride = view.byteStride || 12;
    const x = bin.readFloatLE(base);
    const z = bin.readFloatLE(base + 8);
    for (let i = 0; i < accessor.count; i++) {
      bin.writeFloatLE(x, base + i * stride);
      bin.writeFloatLE(z, base + i * stride + 8);
    }
    if (accessor.min) { accessor.min[0] = x; accessor.min[2] = z; }
    if (accessor.max) { accessor.max[0] = x; accessor.max[2] = z; }
  }

  const json = Buffer.from(JSON.stringify(gltf), 'utf8');
  const paddedJson = Buffer.alloc(align4(json.length), 0x20);
  json.copy(paddedJson);
  const outputLength = 12 + 8 + paddedJson.length + 8 + bin.length;
  const output = Buffer.allocUnsafe(outputLength);
  output.write('glTF', 0, 'ascii');
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(outputLength, 8);
  output.writeUInt32LE(paddedJson.length, 12);
  output.write('JSON', 16, 'ascii');
  paddedJson.copy(output, 20);
  const binHeader = 20 + paddedJson.length;
  output.writeUInt32LE(bin.length, binHeader);
  output.write('BIN\0', binHeader + 4, 'ascii');
  bin.copy(output, binHeader + 8);
  fs.writeFileSync(target, output);
  console.log(`${path.basename(target)}: ${(outputLength / 1048576).toFixed(1)} MiB, ${gltf.animations.length} animations`);
} finally {
  fs.closeSync(fd);
}
