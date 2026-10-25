// @ts-check
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SRC_DIR = path.resolve(__dirname, "..", "project_template", "src");

function readSrc(relPath) {
  const fullPath = path.join(SRC_DIR, relPath);
  assert.ok(fs.existsSync(fullPath), `Missing expected file: ${relPath}`);
  return fs.readFileSync(fullPath, "utf8");
}

test("All Zombie Awareness v4.0 Luau modules start with --!strict and avoid deprecated globals", () => {
  const files = [
    "shared/Types.luau",
    "shared/ZombieCatalogs.luau",
    "shared/LobbyBuilder.luau",
    "shared/ZombieModelBuilder.luau",
    "server/DataPersistenceService.luau",
    "server/MonetizationService.luau",
    "server/NetworkSecurityService.luau",
    "server/MissionGenService.luau",
    "server/ThreatAndDistrictService.luau",
    "server/AIService.luau",
    "server/CombatAndArsenalService.luau",
    "server/EventSchedulerService.luau",
    "server/init.server.luau",
    "client/CharacterController.client.luau",
    "client/HUDController.client.luau",
  ];

  for (const rel of files) {
    const content = readSrc(rel);
    assert.ok(
      content.startsWith("--!strict"),
      `${rel} must start with --!strict`
    );
    assert.ok(
      !/\bwait\s*\(/.test(content.replace(/task\.wait\s*\(/g, "")),
      `${rel} must use task.wait() instead of legacy wait()`
    );
  }
});

test("ZombieCatalogs.luau defines all 150 units + 2 Mega Brutes, 32 weapons, 6 Rigs, 9 VFX Presets, and 16 Events", () => {
  const catalog = readSrc("shared/ZombieCatalogs.luau");

  // 30 Human units (H-01 to H-30)
  for (let i = 1; i <= 30; i++) {
    const id = `H-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing Human unit ${id}`);
  }

  // 60 Mutant units (M-01 to M-60) + M-BOSS-01
  for (let i = 1; i <= 60; i++) {
    const id = `M-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing Mutant unit ${id}`);
  }
  assert.ok(catalog.includes('"M-BOSS-01"'), "Missing M-BOSS-01 Coloso Mutante Supremo");

  // 60 Zombie units (Z-01 to Z-60) + Z-BOSS-01
  for (let i = 1; i <= 60; i++) {
    const id = `Z-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing Zombie unit ${id}`);
  }
  assert.ok(catalog.includes('"Z-BOSS-01"'), "Missing Z-BOSS-01 Dios Zombi Troll");

  // 32 Weapons (G-01..G-20 and M-01..M-12)
  for (let i = 1; i <= 20; i++) {
    const id = `G-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing ranged/special weapon ${id}`);
  }
  for (let i = 1; i <= 12; i++) {
    const id = `M-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing melee weapon ${id}`);
  }

  // 6 Master Rigs (RIG-01 to RIG-06)
  for (let i = 1; i <= 6; i++) {
    assert.ok(catalog.includes(`"RIG-0${i}"`), `Missing Master Rig RIG-0${i}`);
  }

  // 9 Mathematical VFX Presets
  const presets = [
    "VFX_Muzzle_Ballistic",
    "VFX_Flame_Stream",
    "VFX_Toxic_Acid",
    "VFX_Tesla_Arc",
    "VFX_Hypnosis_Wave",
    "VFX_Hulk_Shockwave",
    "VFX_Melee_Slash_Blood",
    "VFX_Rocket_Barrage",
    "VFX_Weapon_Lv10_Aura",
  ];
  for (const p of presets) {
    assert.ok(catalog.includes(p), `Missing VFX preset ${p}`);
  }

  // 16 Procedural Events (E-01 to E-16)
  for (let i = 1; i <= 16; i++) {
    const id = `E-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${id}"`), `Missing Procedural Event ${id}`);
  }
});

test("DataPersistenceService.luau enforces User_{UserId} Session Locking, 180s buffer, and Tactical Backpack extraction", () => {
  const persistence = readSrc("server/DataPersistenceService.luau");
  assert.ok(persistence.includes('"PlayerData"'), "Must use DataStore PlayerData");
  assert.ok(persistence.includes('"User_"'), "Must use key prefix User_{UserId}");
  assert.ok(persistence.includes("AUTOSAVE_INTERVAL_SEC = 180"), "Must flush periodically every 180s");
  assert.ok(persistence.includes("extractBackpackToSafeVault"), "Must implement Tactical Backpack extraction");
  assert.ok(persistence.includes("applyDeathPenalty"), "Must implement 50% unsecured loot death penalty");
  assert.ok(persistence.includes("flushCriticalTransaction"), "Must flush immediately on critical transactions");
});

test("MissionGenService.luau, LobbyBuilder.luau, and ThreatAndDistrictService.luau implement 6-stage seed pipeline, Z0 architectural lobby, and +5/min threat loop", () => {
  const missionGen = readSrc("server/MissionGenService.luau");
  const lobbyBuilder = readSrc("shared/LobbyBuilder.luau");
  const threatSvc = readSrc("server/ThreatAndDistrictService.luau");

  assert.ok(missionGen.includes("VoxelTerrainBuilder.GenerateFBM"), "Must use VoxelTerrainBuilder.GenerateFBM");
  assert.ok(missionGen.includes("VoxelTerrainBuilder.CarveRoadPath"), "Must use VoxelTerrainBuilder.CarveRoadPath");
  assert.ok(missionGen.includes("WorldAssembler.PlaceGrounded"), "Must ground prefabs via WorldAssembler.PlaceGrounded");
  assert.ok(missionGen.includes("LobbyBuilder.buildCompleteSafeHavenZ0"), "Must delegate Z0 lobby to LobbyBuilder.buildCompleteSafeHavenZ0");
  assert.ok(missionGen.includes("RAASE_BreachWall"), "Must tag 400 HP breachable walls");
  assert.ok(missionGen.includes("ModelStreamingMode.Persistent"), "Must set Persistent streaming on Special Zones");

  assert.ok(lobbyBuilder.includes("Z0_SafeHaven_Persistent"), "Must create Z0_SafeHaven_Persistent");
  assert.ok(lobbyBuilder.includes("A01_CentroDeMando"), "Must build A-01 Command Center");
  assert.ok(lobbyBuilder.includes("A02_ArmeriaYBoveda"), "Must build A-02/A-08 Armory & Vault");
  assert.ok(lobbyBuilder.includes("A06_LaboratorioConciencia"), "Must build A-06 Consciousness Lab");
  assert.ok(lobbyBuilder.includes("A05_CuartelMercenarios"), "Must build A-05 Mercenary Barracks");
  assert.ok(lobbyBuilder.includes("A07_SalaDeMapas"), "Must build A-07 Map Room");
  assert.ok(lobbyBuilder.includes("A21_InvernaderoHidroponico"), "Must build A-21 Hydroponic Greenhouse");
  assert.ok(lobbyBuilder.includes("A23_HelipuertoDeExtraccion"), "Must build A-23 Helipad");
  assert.ok(lobbyBuilder.includes("CentralPlaza_TelemetryPylon"), "Must build Central Plaza Telemetry Pylon");
  assert.ok(!lobbyBuilder.includes("Enum.NormalId.South") && !lobbyBuilder.includes("Enum.NormalId.North"), "Must only use valid Enum.NormalId faces");

  assert.ok(threatSvc.includes("assignSpecialistToDistrict"), "Must allow assigning specialists to districts");
  assert.ok(threatSvc.includes("liberateDistrict"), "Must permanently liberate district at Threat 0");
  assert.ok(threatSvc.includes("rollLootRarity"), "Must implement zone-scaled loot rarity roller");
});

test("AIService.luau implements 180-NPC Object Pooling, 20-unit Perception Batching, 4-ComputeAsync Queue, and ServerBossMutex", () => {
  const ai = readSrc("server/AIService.luau");
  assert.ok(ai.includes("MAX_NPCS_NORMAL = 180"), "Must enforce 180 active NPC budget");
  assert.ok(ai.includes("MAX_NPCS_THROTTLED = 120"), "Must contract to 120 NPCs below 30 Hz");
  assert.ok(ai.includes("PERCEPTION_BATCH_NORMAL = 20"), "Must batch perception at 20 units/frame");
  assert.ok(ai.includes("MAX_CONCURRENT_PATHFINDING = 4"), "Must cap concurrent ComputeAsync at 4");
  assert.ok(ai.includes("Pool_Human"), "Must maintain Pool_Human");
  assert.ok(ai.includes("Pool_Mutant_Green"), "Must maintain Pool_Mutant_Green");
  assert.ok(ai.includes("Pool_Mutant_Anthro"), "Must maintain Pool_Mutant_Anthro");
  assert.ok(ai.includes("Pool_Zombie_Base"), "Must maintain Pool_Zombie_Base");
  assert.ok(ai.includes("Pool_Brute"), "Must maintain Pool_Brute");
  assert.ok(ai.includes("serverBossMutex"), "Must enforce ServerBossMutex");
  assert.ok(ai.includes("0.99"), "Must freeze opposite crucible at 99% while a Mega Brute is active");
});

test("CombatAndArsenalService.luau and Client Controllers implement G-20 validation, Lv1-10 upgrades, 80% salvage, and RAASE 3.0 Master Modules", () => {
  const combat = readSrc("server/CombatAndArsenalService.luau");
  const charCtrl = readSrc("client/CharacterController.client.luau");
  const hudCtrl = readSrc("client/HUDController.client.luau");

  assert.ok(combat.includes("G20_MAX_DISTANCE_STUDS = 60"), "Must validate 60 studs max distance for G-20");
  assert.ok(combat.includes("G20_CHANNEL_DURATION_SEC = 2.0"), "Must validate 2.0s channeling for G-20");
  assert.ok(combat.includes("salvageWeaponUpgrades"), "Must support 80% weapon upgrade salvage");
  assert.ok(combat.includes("damageBreachWall"), "Must handle 400 HP breachable walls");

  assert.ok(charCtrl.includes("ProceduralAnimator.AttachIK"), "Must use ProceduralAnimator.AttachIK");
  assert.ok(charCtrl.includes("ProceduralAnimator.CreateSpring2D"), "Must use ProceduralAnimator.CreateSpring2D");
  assert.ok(charCtrl.includes("VFXAndJuiceEngine.CastEffect"), "Must use VFXAndJuiceEngine.CastEffect");
  assert.ok(charCtrl.includes("WindupVFX") && charCtrl.includes("HitFrame") && charCtrl.includes("RecoveryCancel"), "Must bind all 3 AnimationEvents");

  assert.ok(hudCtrl.includes("MAPA DE CONCIENCIA"), "HUD must render the Consciousness Map");
  assert.ok(hudCtrl.includes("CRISOLES ZvM"), "HUD must render West/East Crucibles and Mutex status");

  const zombieBuilder = readSrc("shared/ZombieModelBuilder.luau");
  assert.ok(zombieBuilder.includes("buildZombieModel"), "ZombieModelBuilder must expose buildZombieModel");
  assert.ok(zombieBuilder.includes("buildZombieShowcaseGallery"), "ZombieModelBuilder must expose buildZombieShowcaseGallery");
  assert.ok(zombieBuilder.includes("WeakPoint_Head") && zombieBuilder.includes("WeakPoint_Chest") && zombieBuilder.includes("WeakPoint_Back"), "Z-BOSS-01 must define all 3 official WeakPoints");
});
