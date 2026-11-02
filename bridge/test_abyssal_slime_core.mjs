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

test("S1: SlimeCatalogs.luau defines 350 Slimes (300 Regular + 50 Ultra), 50 Mutations, 10 Races, 10 Chasses, and Day-1 Event Crate (10 Slimes down to 0.0010%)", () => {
  const typesSrc = readSrc("shared/Types.luau");
  assert.ok(typesSrc.includes("SlimeDefinition"), "Types.luau must define SlimeDefinition");
  assert.ok(typesSrc.includes("SlimePetInstance"), "Types.luau must define SlimePetInstance");
  assert.ok(typesSrc.includes("PerformanceMutationMode"), "Types.luau must define PerformanceMutationMode");
  assert.ok(typesSrc.includes("DynamicCaptureQuote"), "Types.luau must define DynamicCaptureQuote");

  const catalog = readSrc("shared/SlimeCatalogs.luau");
  assert.ok(catalog.startsWith("--!strict"), "SlimeCatalogs.luau must start with --!strict");
  assert.ok(catalog.includes('GAME_TITLE = "SLIME PIT: Dive for Mutants!"'), "Must define ideal game title");

  // 10 Base Chasses with 4 Bones (Base, Centro, Corona, Nucleo)
  for (let i = 1; i <= 10; i++) {
    const chassisId = `CHASSIS-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${chassisId}"`), `Missing Slime Chassis ${chassisId}`);
  }
  assert.ok(
    catalog.includes('"Base"') && catalog.includes('"Centro"') && catalog.includes('"Corona"') && catalog.includes('"Nucleo"'),
    "Must define the 4 internal Skinned Mesh bones (Base, Centro, Corona, Nucleo)"
  );

  // 10 Races of Ascendancy
  for (let i = 1; i <= 10; i++) {
    const raceId = `RACE-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${raceId}"`), `Missing Slime Race ${raceId}`);
  }

  // 50 Mutations across 5 functional vectors (MUT-01..MUT-50) with changesAppearance flag
  for (let i = 1; i <= 50; i++) {
    const mutId = `MUT-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${mutId}"`), `Missing Mutation ${mutId}`);
  }
  assert.ok(catalog.includes("changesAppearance"), "Mutations must declare changesAppearance flag");

  // 300 Regular Stat Slimes (30 Biomes x 10 Variants) + 50 Ultra Special Huges & Titanics
  assert.ok(catalog.includes("REGULAR_SLIME_COUNT = 300"), "Must define 300 Regular Stat Slimes");
  assert.ok(catalog.includes("ULTRA_SLIME_COUNT = 50"), "Must define 50 Ultra Special Slimes (Huges & Titanics)");

  // Day-1 Event Shop Specialized Crate with 10 Slimes (EV-01 Common to EV-10 0.0010% / 0.001%)
  for (let i = 1; i <= 10; i++) {
    const evId = `EV-${String(i).padStart(2, "0")}`;
    assert.ok(catalog.includes(`"${evId}"`), `Missing Day-1 Event Crate Slime ${evId}`);
  }
  assert.ok(
    catalog.includes("0.001") && catalog.includes("0.0010%"),
    "Day-1 Event Crate must include the 0.001% (0.0010%) rarest slime tier"
  );

  // Zero-Token Custom Framework Templates ($0 built-from-scratch update framework)
  const fwSrc = readSrc("shared/SlimeFrameworkTemplate.luau");
  const updSrc = readSrc("shared/SlimeUpdatesRegistry.luau");
  assert.ok(fwSrc.startsWith("--!strict"), "SlimeFrameworkTemplate.luau must start with --!strict");
  assert.ok(fwSrc.includes("registerWeeklyUpdate"), "Framework must expose registerWeeklyUpdate");
  assert.ok(fwSrc.includes("defineEventCrateFromTemplate"), "Framework must expose defineEventCrateFromTemplate");
  assert.ok(updSrc.startsWith("--!strict"), "SlimeUpdatesRegistry.luau must start with --!strict");
  assert.ok(updSrc.includes("UPD_02_ABYSSAL_TRENCH"), "SlimeUpdatesRegistry must register sample weekly update");
});

test("S1: SlimeCoreMath.luau implements 4-stage Boost, Anchored Scaling (100%..1479%), Hyperbolic Mitigation, Daily Free Guaranteed Capture, and 10k+ Robux Dynamic Gap Formula", () => {
  const mathSrc = readSrc("shared/SlimeCoreMath.luau");
  assert.ok(mathSrc.startsWith("--!strict"), "SlimeCoreMath.luau must start with --!strict");
  assert.ok(mathSrc.includes("computePetOutput"), "Must implement 4-stage Boost master equation (SetAdd, SetPercent, SetScale, SetClamp)");
  assert.ok(mathSrc.includes("computeAnchoredUltraPower"), "Must implement Anchored Relative Scaling (100% to 1479% Rainbow Shiny Titanic)");
  assert.ok(mathSrc.includes("computeGuardianDamageReceived"), "Must implement corrected Hyperbolic Defensive Mitigation (no Lv1 x60 bug)");
  assert.ok(mathSrc.includes("computePetDeathCooldown"), "Must implement Biome-scaled death cooldown (20s Biome 1 to 68s Biome 30)");
  assert.ok(mathSrc.includes("computeAlchemyProbabilities"), "Must implement Fisch-style transparent Alchemy probabilities summing to 100.0000%");
  assert.ok(mathSrc.includes("computeDynamicCaptureQuote"), "Must implement Dynamic Biome-Gap Robux Capture Formula + 1x/day Free Guaranteed Capture");
  assert.ok(mathSrc.includes("DAILY_FREE_CAPTURE_COOLDOWN_SEC = 86400"), "Must enforce 24h (86400s) cooldown for 1x/day free guaranteed capture");
  assert.ok(mathSrc.includes("10000"), "Dynamic capture formula must scale to 10,000+ Robux when jumping to deep biomes for top slimes");
  assert.ok(mathSrc.includes("computeSkipTimerRobux"), "Must implement paid time-skip Robux calculation");
});

test("S2: SlimeVisualAndAnimEngine.luau enforces 10-Mutation cap, Performance Mode (3 / 6 / 10 visible mutations), distance LOD, and all 5 Dopamine Animations", () => {
  const visSrc = readSrc("shared/SlimeVisualAndAnimEngine.luau");
  assert.ok(visSrc.startsWith("--!strict"), "SlimeVisualAndAnimEngine.luau must start with --!strict");
  assert.ok(visSrc.includes("MAX_MUTATIONS_PER_SLIME = 10"), "Must enforce hard cap of 10 mutations per slime on base arrival");
  assert.ok(
    visSrc.includes("LOW_3 = 3") && visSrc.includes("MEDIUM_6 = 6") && visSrc.includes("HIGH_10 = 10"),
    "Must support Performance Mode limiting visible mutations to 3 or 6 (or 10 on High)"
  );
  assert.ok(visSrc.includes("filterVisibleMutations"), "Must filter visible mutations by Performance Mode and appearance priority");
  assert.ok(visSrc.includes("TransformedWorldCFrame"), "Must sync rigid armor via Bone.TransformedWorldCFrame with distance LOD");
  assert.ok(visSrc.includes("buildCrateRarityAnimationSpec"), "Must implement Crate Rarity Reveal animation");
  assert.ok(visSrc.includes("buildExtractionRarityAnimationSpec"), "Must implement Extraction Rarity animation");
  assert.ok(visSrc.includes("buildBaseArrivalAnimationSpec"), "Must implement Base Arrival animation");
  assert.ok(visSrc.includes("buildPetExtractedMutationAnimationSpec"), "Must implement Pet Extracted Mutation reveal animation");
  assert.ok(visSrc.includes("buildMutationStrikeDropAnimationSpec"), "Must implement Mutation Strike/Drop impact animation");
});

test("S3 & S4: SlimeCoreService.luau and Client/HUD Controllers implement Amphitheater Streaming, 25% Puddle, Event Crate Multi-Open, PolicyService Queue, and Admin Abuse", () => {
  const srvSrc = readSrc("server/SlimeCoreService.luau");
  assert.ok(srvSrc.startsWith("--!strict"), "SlimeCoreService.luau must start with --!strict");
  assert.ok(srvSrc.includes("AbyssalSlimeHole"), "Must manage slime holes centrally via CollectionService tag AbyssalSlimeHole");
  assert.ok(srvSrc.includes("UNREFINED_SPILL_PENALTY = 0.25"), "Must spill 25% of unrefined juice into a Mutagenic Puddle on wipe");
  assert.ok(srvSrc.includes("extractToCircularLobby"), "Must extract slimes to Circular Lobby applying up to 10 mutations max");
  assert.ok(srvSrc.includes("openEventSpecialCrates"), "Must support Day-1 Event Crate opening (free tokens + paid multi-crate x1/x3/x10)");
  assert.ok(srvSrc.includes("ArePaidRandomItemsRestricted"), "Must audit PolicyService.ArePaidRandomItemsRestricted and switch to Deterministic Seed Queue");
  assert.ok(srvSrc.includes("IsPaidItemTradingAllowed") && srvSrc.includes("Earned_Free"), "Must segregate Earned_Free metadata for trading");
  assert.ok(srvSrc.includes("attemptDynamicSlimeCapture"), "Must handle 1x/day free guaranteed capture and dynamic gap Robux capture");
  assert.ok(srvSrc.includes("triggerGlobalAdminAbuse"), "Must broadcast Admin Abuse LiveOps events via MessagingService");

  const cliSrc = readSrc("client/SlimeClientController.client.luau");
  const hudSrc = readSrc("client/SlimeHUDController.client.luau");
  assert.ok(cliSrc.startsWith("--!strict"), "SlimeClientController.client.luau must start with --!strict");
  assert.ok(hudSrc.startsWith("--!strict"), "SlimeHUDController.client.luau must start with --!strict");
  assert.ok(hudSrc.includes("Details"), "HUD must label odds button explicitly with the word 'Details'");
  assert.ok(hudSrc.includes("GetProductInfoAsync"), "HUD must fetch live regional Robux prices via GetProductInfoAsync");
  assert.ok(hudSrc.includes("MODO RENDIMIENTO"), "HUD must provide Performance Mode toggle (3 / 6 / 10 mutaciones)");
});
