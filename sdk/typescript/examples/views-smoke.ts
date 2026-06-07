/**
 * Read-only smoke test for the per-module SDK view wrappers.
 * Run from sdk/typescript:  npx tsx examples/views-smoke.ts
 */
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import { createAptosClient, SigilClient } from "../src/index.js";

const MODULE = "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6";
const PLAYER = "0xc2e40bb9e047dce8663d6881727c1faf0b24b32195035cf42e07a83b2fdd89af";

const aptos = createAptosClient({
  network: Network.DEVNET,
  fullnode: "https://fullnode.devnet.aptoslabs.com/v1",
});
const sigil = new SigilClient({ aptos, moduleAddress: AccountAddress.from(MODULE) });

async function run(label: string, p: Promise<unknown>) {
  try {
    const r = await p;
    console.log(`  ok  ${label}: ${JSON.stringify(r)}`);
  } catch (e) {
    console.log(`  ERR ${label}: ${e instanceof Error ? e.message : String(e)}`);
  }
}

async function main() {
  console.log("== view-method smoke (devnet) ==");
  await run("gamePlatform.viewGameCount", sigil.gamePlatform.viewGameCount());
  await run("gamePlatform.viewHasGame(0)", sigil.gamePlatform.viewHasGame(0));
  await run("gamePlatform.viewScoreSummary", sigil.gamePlatform.viewScoreSummary({ player: PLAYER, gameId: 0 }));
  await run("leaderboard.viewLeaderboardCount", sigil.leaderboard.viewLeaderboardCount());
  await run("leaderboard.viewLeaderboardConfig(0)", sigil.leaderboard.viewLeaderboardConfig(0));
  await run("leaderboard.viewTopEntriesForGame(0)", sigil.leaderboard.viewTopEntriesForGame(0));
  await run("achievements.viewAchievementCount", sigil.achievements.viewAchievementCount());
  await run("quests.viewIsInitialized", sigil.quests.viewIsInitialized());
  await run("quests.viewQuestCount", sigil.quests.viewQuestCount());
  await run("seasons.viewSeasonCount", sigil.seasons.viewSeasonCount());
  await run("seasons.viewCurrentSeason", sigil.seasons.viewCurrentSeason());
  await run("guilds.viewGuildCount", sigil.guilds.viewGuildCount());
  await run("merge.viewRecipeCount", sigil.merge.viewRecipeCount());
  await run("treasury.viewBalance", sigil.treasury.viewBalance());
  await run("roles.viewIsInitialized", sigil.roles.viewIsInitialized());
  await run("rewards.viewRewardedAchievements", sigil.rewards.viewRewardedAchievements());
  await run("attest.viewIsInitialized", sigil.attest.viewIsInitialized());
  console.log("== done ==");
}

void main();
