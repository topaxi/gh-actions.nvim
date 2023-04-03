#!/usr/bin/env node

const path = require('path');
const fs = require('fs/promises');

const versions = {
  'lua-yaml': 'fad13b985340431ad401d7ef84d290b6dc1c76f7',
};

async function main() {
  const yamllua = await fetch(
    `https://raw.githubusercontent.com/topaxi/lua-yaml/${versions['lua-yaml']}/yaml.lua`
  ).then((r) => r.text());

  await fs.writeFile(
    path.join(__dirname, '../lua/gh-actions-vendor/yaml.lua'),
    yamllua
  );
}

main().catch(console.error);
