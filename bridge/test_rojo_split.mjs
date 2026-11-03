import test from "node:test";
import assert from "node:assert/strict";
import { lstatSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = fileURLToPath(new URL("../project_template/", import.meta.url));
const compositions = [
  {
    id: "zombie", name: "ZombieAwareness", port: 34872,
    services: ["AIService", "CombatAndArsenalService", "DataPersistenceService",
      "EventSchedulerService", "MissionGenService", "MonetizationService",
      "NetworkSecurityService", "ThreatAndDistrictService"],
    clients: ["CharacterController", "HUDController"],
    shared: ["Janitor", "LobbyBuilder", "ProceduralAnimator", "Types", "VFXAndJuiceEngine",
      "VoxelTerrainBuilder", "WorldAssembler", "ZombieCatalogs", "ZombieModelBuilder"],
  },
  {
    id: "slime", name: "SlimePit", port: 34874,
    services: ["NetworkSecurityService", "SlimeCoreService"],
    clients: ["SlimeClientController", "SlimeHUDController"],
    shared: ["GameLifecycle", "ProceduralAnimator", "SlimeCatalogs", "SlimeCoreMath", "SlimeEventContract", "SlimeFrameworkTemplate",
      "SlimeUpdatesRegistry", "SlimeVisualAndAnimEngine", "SlimeVisualRegistry", "Types", "VFXAndJuiceEngine"],
  },
];

function readProject(id) {
  return JSON.parse(readFileSync(path.join(projectRoot, `${id}.project.json`), "utf8"));
}

function childNames(node) {
  return Object.keys(node).filter((key) => !key.startsWith("$")).sort();
}

function verifyFileMappings(node, collected = []) {
  assert.equal(typeof node, "object");
  if (node.$path !== undefined) {
    assert.equal(typeof node.$path, "string");
    assert.equal(path.isAbsolute(node.$path), false, "Mappings must be portable");
    const file = path.resolve(projectRoot, node.$path);
    const relative = path.relative(realpathSync(projectRoot), realpathSync(file));
    assert.ok(relative && !relative.startsWith("..") && !path.isAbsolute(relative),
      `Mapping escapes project_template: ${node.$path}`);
    assert.ok(lstatSync(file).isFile(), `Use explicit files, not directory imports: ${node.$path}`);
    assert.ok(file.endsWith(".luau"), `Unexpected mapped file: ${node.$path}`);
    assert.equal(node.$className, undefined,
      `Rojo infers the class from file paths; an explicit class requires a directory: ${node.$path}`);
    collected.push(node.$path);
  }
  for (const name of childNames(node)) verifyFileMappings(node[name], collected);
  return collected;
}

function mappedInstances(node, prefix = [], output = new Map()) {
  if (node.$path) output.set(prefix.join("."), node.$path);
  for (const name of childNames(node)) mappedInstances(node[name], [...prefix, name], output);
  return output;
}

// Structural coverage of the import forms currently used by these modules,
// not a Luau parser or runtime. New unsupported forms fail instead of being skipped.
function requireArguments(source) {
  const text = source.replace(/--\[\[[\s\S]*?\]\]/g, "").replace(/^\s*--.*$/gm, "");
  const args = [];
  for (let i = text.indexOf("require("); i !== -1; i = text.indexOf("require(", i)) {
    let depth = 0;
    let end = i;
    for (; end < text.length; end++) {
      if (text[end] === "(") depth++;
      else if (text[end] === ")" && --depth === 0) { end++; break; }
    }
    assert.equal(depth, 0, "Unbalanced require expression");
    args.push(text.slice(i + 8, end - 1).trim());
    i = end;
  }
  return args;
}

function importedInstance(arg, instancePath) {
  const instance = instancePath.split(".");
  let match;
  if ((match = arg.match(/^script:WaitForChild\("([^"]+)"\)/))) return [...instance, match[1]].join(".");
  if ((match = arg.match(/^script\.Parent\.([A-Za-z0-9_]+)$/))) return [...instance.slice(0, -1), match[1]].join(".");
  if ((match = arg.match(/^script\.Parent:WaitForChild\("([^"]+)"\)/))) return [...instance.slice(0, -1), match[1]].join(".");
  if ((match = arg.match(/^ReplicatedStorage:WaitForChild\("([^"]+)"\):WaitForChild\("([^"]+)"\)/))) {
    return ["ReplicatedStorage", match[1], match[2]].join(".");
  }
  if ((match = arg.match(/^(?:sharedFolder|SharedFolder):(?:WaitForChild|FindFirstChild)\("([^"]+)"\)/))) {
    return ["ReplicatedStorage", "RAASE_Shared", match[1]].join(".");
  }
  assert.fail(`Unsupported require expression in ${instancePath}: ${arg}`);
}

function verifyImportClosure(project, services) {
  const instances = mappedInstances(project.tree);
  for (const [instance, file] of instances) {
    const source = readFileSync(path.join(projectRoot, file), "utf8");
    for (const arg of requireArguments(source)) {
      const dependency = importedInstance(arg, instance);
      assert.ok(instances.has(dependency), `${file} imports an unmapped module: ${dependency}`);
    }
  }
  const bootstrap = readFileSync(path.join(projectRoot,
    project.tree.ServerScriptService.RAASE_Server.$path), "utf8");
  const bootImports = requireArguments(bootstrap).map((arg) => arg.match(/"([^"]+)"/)?.[1]).sort();
  assert.deepEqual(bootImports, services, "Bootstrap must load exactly the mapped services");
  for (const [, service, method] of bootstrap.matchAll(/\b(\w+Service)\.(\w+)\(/g)) {
    const file = instances.get(`ServerScriptService.RAASE_Server.${service}`);
    assert.ok(file, `Bootstrap calls unmapped service ${service}`);
    assert.match(readFileSync(path.join(projectRoot, file), "utf8"),
      new RegExp(`function ${service}\\.${method}\\(`), `${service}.${method} must exist`);
  }
}

for (const expected of compositions) {
  test(`${expected.name} includes only its own services and controllers`, (t) => {
    const project = readProject(expected.id);
    assert.equal(project.name, expected.name);
    assert.equal(project.serveAddress, "127.0.0.1");
    assert.equal(project.servePort, expected.port);
    assert.equal(project.tree.$className, "DataModel");
    assert.deepEqual(childNames(project.tree), ["ReplicatedStorage", "ServerScriptService", "StarterPlayer"]);
    assert.deepEqual(childNames(project.tree.ServerScriptService), ["RAASE_Server"]);
    assert.deepEqual(childNames(project.tree.ReplicatedStorage), ["RAASE_Shared"]);
    assert.deepEqual(childNames(project.tree.StarterPlayer), ["StarterPlayerScripts"]);
    assert.deepEqual(childNames(project.tree.StarterPlayer.StarterPlayerScripts), ["RAASE_Client"]);

    const server = project.tree.ServerScriptService.RAASE_Server;
    const shared = project.tree.ReplicatedStorage.RAASE_Shared;
    const client = project.tree.StarterPlayer.StarterPlayerScripts.RAASE_Client;
    assert.equal(server.$className, undefined, "File-backed bootstraps must use Rojo class inference");
    assert.equal(server.$path, `src/bootstrap/${expected.id}.server.luau`);
    assert.deepEqual(childNames(server), expected.services);
    assert.deepEqual(childNames(shared), expected.shared);
    assert.deepEqual(childNames(client), expected.clients);
    for (const node of [server, shared, client]) assert.equal(node.$ignoreUnknownInstances, false);
    for (const node of [shared, client]) {
      assert.equal(node.$className, "Folder");
      assert.equal(node.$path, undefined, "Do not implicitly import the mixed legacy directory");
    }
    for (const name of expected.services) assert.equal(server[name].$path, `src/server/${name}.luau`);
    for (const name of expected.shared) assert.equal(shared[name].$path, `src/shared/${name}.luau`);
    for (const name of expected.clients) assert.equal(client[name].$path, `src/client/${name}.client.luau`);
    const files = verifyFileMappings(project.tree);
    assert.equal(new Set(files).size, files.length, "No duplicate source mappings");
    assert.equal(files.length, 1 + expected.services.length + expected.clients.length + expected.shared.length);
    verifyImportClosure(project, expected.services);
    t.diagnostic(`${expected.services.length} services, ${expected.clients.length} controllers, ${expected.shared.length} shared modules, one bootstrap`);
  });
}

test("the two local Rojo servers use different ports", () => {
  const ports = compositions.map(({ id }) => readProject(id).servePort);
  assert.equal(new Set(ports).size, compositions.length);
});

test("the legacy project mappings remain available unchanged", () => {
  const legacy = readProject("default");
  assert.equal(legacy.name, "robloxia-experience");
  assert.equal(legacy.tree.ServerScriptService.RAASE_Server.$path, "src/server");
  assert.equal(legacy.tree.ReplicatedStorage.RAASE_Shared.$path, "src/shared");
  assert.equal(legacy.tree.StarterPlayer.StarterPlayerScripts.RAASE_Client.$path, "src/client");
});
