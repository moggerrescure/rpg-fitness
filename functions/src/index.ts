import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import { onRequest as onRequestV2, onCall as onCallV2, HttpsError as HttpsErrorV2 } from "firebase-functions/v2/https";
import { onDocumentCreated as onDocCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { SHOP_ITEM_COSTS, SHOP_ITEM_SLOTS } from "./shopCatalog";
import {
    WORLD_BOSS_ATTACK_ENERGY,
    WORLD_BOSS_MAX_DAMAGE_PER_CALL,
    WORLD_BOSS_ATTACKS_PER_HOUR,
    applyXpToProgression,
    clampActivityRewards,
    clampPvERewards,
    FITRPG_USER_FIELD_KEYS,
    pvpOutcomeForPlayer,
    rewardsForPvpOutcome,
    rollClanWarWin,
} from "./economyHelpers";
import {
    mergeTeamGuests,
    requireMyTicketId,
} from "./matchmakingHelpers";

admin.initializeApp();
const db = admin.firestore();

/** FitRPG callables — App Check required. Shared Food/Workout endpoints stay separate (v2/onRequest). */
const fitRpgOnCall = (handler: (data: any, context: functions.https.CallableContext) => any | Promise<any>) =>
    functions.runWith({ enforceAppCheck: true }).https.onCall(handler);

function resetMembersWarCounters(members: any[] = []) {
    return members.map((m: any) => ({
        ...m,
        warAttacksUsed: 0,
        warScoreContributed: 0
    }));
}

// -------------------------------------------------------------------
// Helper: Send Push Notification
// -------------------------------------------------------------------
async function sendPushNotification(uid: string, title: string, body: string, data?: any) {
    try {
        const userDoc = await db.collection("users").doc(uid).get();
        const userData = userDoc.data();
        if (userData && userData.fcmToken) {
            await admin.messaging().send({
                token: userData.fcmToken,
                notification: { title, body },
                data: data || {}
            });
            console.log(`Push sent to ${uid}: ${title}`);
        }
    } catch (e) {
        console.error(`Failed to send push to ${uid}`, e);
    }
}

// -------------------------------------------------------------------
// 1. HTTP Callable: Matchmake Clan War
// -------------------------------------------------------------------
export const matchmakeClanWar = fitRpgOnCall(async (data, context) => {
    // Ensure user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const uid = context.auth.uid;

    // Get user's clan
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    if (!userData || !userData.clanId) {
        throw new functions.https.HttpsError("failed-precondition", "User is not in a clan.");
    }

    const clanId = userData.clanId;
    const clanRef = db.collection("clans").doc(clanId);
    
    // We use a transaction to safely try and lock two clans together
    return await db.runTransaction(async (transaction) => {
        const myClanDoc = await transaction.get(clanRef);
        if (!myClanDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Clan not found.");
        }
        
        const myClanData = myClanDoc.data()!;
        
        // Prevent starting if already searching or in an active war cycle
        const existingPhase = myClanData.activeWar?.phase;
        if (existingPhase === "searching" || existingPhase === "preparation" || existingPhase === "active") {
            throw new functions.https.HttpsError("already-exists", "Clan is already in a war or searching.");
        }

        // Try to find another clan that is currently 'searching'
        // Note: Firestore transactions require all reads before writes.
        // Doing a query inside a transaction is allowed in Admin SDK.
        const searchingClansSnapshot = await transaction.get(
            db.collection("clans")
              .where("activeWar.phase", "==", "searching")
              .limit(1)
        );

        let opponentId: string | null = null;
        let opponentName: string | null = null;
        let opponentMembers: any[] = [];

        // Found a real clan?
        if (!searchingClansSnapshot.empty) {
            const oppDoc = searchingClansSnapshot.docs[0];
            if (oppDoc.id !== clanId) {
                opponentId = oppDoc.id;
                opponentName = oppDoc.data().name;
                opponentMembers = oppDoc.data().members || [];
            }
        }

        const now = admin.firestore.Timestamp.now();
        // 24 hours from now for preparation
        const prepEndDate = new admin.firestore.Timestamp(now.seconds + 24 * 3600, now.nanoseconds);

        if (opponentId && opponentName) {
            // MATCH FOUND: Link both clans
            const oppRef = db.collection("clans").doc(opponentId);
            
            const myWar = {
                phase: "preparation",
                phaseEndsAt: prepEndDate,
                opponentClanId: opponentId,
                opponentClanName: opponentName,
                myClanScore: 0,
                opponentClanScore: 0
            };
            
            const oppWar = {
                phase: "preparation",
                phaseEndsAt: prepEndDate,
                opponentClanId: clanId,
                opponentClanName: myClanData.name,
                myClanScore: 0,
                opponentClanScore: 0
            };

            transaction.update(clanRef, {
                activeWar: myWar,
                members: resetMembersWarCounters(myClanData.members || [])
            });
            transaction.update(oppRef, {
                activeWar: oppWar,
                members: resetMembersWarCounters(opponentMembers)
            });

            return { success: true, opponentName: opponentName, isBot: false };
        } else {
            // NO MATCH: enter searching queue (cron pairs clans or assigns bot after ~2 min)
            const searchEndDate = new admin.firestore.Timestamp(now.seconds + 120, now.nanoseconds);

            const myWar = {
                phase: "searching",
                phaseEndsAt: searchEndDate,
                opponentClanId: null,
                opponentClanName: null,
                myClanScore: 0,
                opponentClanScore: 0
            };

            transaction.update(clanRef, { activeWar: myWar });

            return { success: true, opponentName: null, isBot: false, searching: true };
        }
    });
});

// -------------------------------------------------------------------
// 1b. HTTP Callable: Cancel Clan War Search
// -------------------------------------------------------------------
export const cancelClanWarSearch = fitRpgOnCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const uid = context.auth.uid;
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    if (!userData || !userData.clanId) {
        throw new functions.https.HttpsError("failed-precondition", "User is not in a clan.");
    }

    const clanRef = db.collection("clans").doc(userData.clanId);

    await db.runTransaction(async (transaction) => {
        const clanDoc = await transaction.get(clanRef);
        if (!clanDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Clan not found.");
        }
        const clan = clanDoc.data()!;
        if (clan.leaderId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Only the clan leader can cancel search.");
        }
        if (!clan.activeWar || clan.activeWar.phase !== "searching") {
            throw new functions.https.HttpsError("failed-precondition", "Clan is not searching for a war.");
        }
        transaction.update(clanRef, {
            activeWar: admin.firestore.FieldValue.delete()
        });
    });

    return { success: true };
});


// -------------------------------------------------------------------
// 2. PubSub Cron: Process Clan War Phases
// -------------------------------------------------------------------
// Runs every 5 minutes
export const processClanWarPhases = functions.pubsub.schedule("*/5 * * * *").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // 0a. Pair searching clans with each other (real PvP)
    const allSearching = await db.collection("clans")
        .where("activeWar.phase", "==", "searching")
        .get();

    const searchingDocs = allSearching.docs.slice();
    const unpaired: typeof searchingDocs = [];
    const pairBatch = db.batch();
    let pairedCount = 0;
    while (searchingDocs.length >= 2) {
        const a = searchingDocs.shift()!;
        const b = searchingDocs.shift()!;
        const prepEndDate = new admin.firestore.Timestamp(now.seconds + 24 * 3600, now.nanoseconds);
        const aName = a.data().name || "Clan";
        const bName = b.data().name || "Clan";
        pairBatch.update(a.ref, {
            activeWar: {
                phase: "preparation",
                phaseEndsAt: prepEndDate,
                opponentClanId: b.id,
                opponentClanName: bName,
                myClanScore: 0,
                opponentClanScore: 0
            },
            members: resetMembersWarCounters(a.data().members || [])
        });
        pairBatch.update(b.ref, {
            activeWar: {
                phase: "preparation",
                phaseEndsAt: prepEndDate,
                opponentClanId: a.id,
                opponentClanName: aName,
                myClanScore: 0,
                opponentClanScore: 0
            },
            members: resetMembersWarCounters(b.data().members || [])
        });
        pairedCount += 2;
    }
    unpaired.push(...searchingDocs);
    if (pairedCount > 0) {
        await pairBatch.commit();
        console.log(`Paired ${pairedCount} clans into clan wars.`);
    }

    // 0b. Searching timeout → assign Shadow Bot and enter preparation
    const searchBatch = db.batch();
    let botAssigned = 0;
    for (const doc of unpaired) {
        const war = doc.data().activeWar;
        const endsAt = war?.phaseEndsAt;
        if (!endsAt || endsAt.toMillis() > now.toMillis()) continue;
        const botId = "bot_" + Math.random().toString(36).substring(7);
        const prepEndDate = new admin.firestore.Timestamp(now.seconds + 24 * 3600, now.nanoseconds);
        searchBatch.update(doc.ref, {
            "activeWar.phase": "preparation",
            "activeWar.phaseEndsAt": prepEndDate,
            "activeWar.opponentClanId": botId,
            "activeWar.opponentClanName": "ShadowFiend (Bot)",
            "activeWar.myClanScore": 0,
            "activeWar.opponentClanScore": 0,
            members: resetMembersWarCounters(doc.data().members || [])
        });
        botAssigned++;
    }
    if (botAssigned > 0) {
        await searchBatch.commit();
        console.log(`Assigned bot opponents to ${botAssigned} clans after search timeout.`);
    }

    // 1. Find all clans in 'preparation' where phaseEndsAt <= now
    const prepSnapshot = await db.collection("clans")
        .where("activeWar.phase", "==", "preparation")
        .where("activeWar.phaseEndsAt", "<=", now)
        .get();

    const batch = db.batch();

    const clansToNotify: any[] = [];

    prepSnapshot.docs.forEach((doc) => {
        // Transition to 'active'
        const activeEndDate = new admin.firestore.Timestamp(now.seconds + 24 * 3600, now.nanoseconds);
        batch.update(doc.ref, {
            "activeWar.phase": "active",
            "activeWar.phaseEndsAt": activeEndDate
        });
        clansToNotify.push(doc.data());
    });

    // 2. Find all clans in 'active' where phaseEndsAt <= now
    const activeSnapshot = await db.collection("clans")
        .where("activeWar.phase", "==", "active")
        .where("activeWar.phaseEndsAt", "<=", now)
        .get();

    activeSnapshot.docs.forEach((doc) => {
        const clanData = doc.data();
        const war = clanData.activeWar;
        
        let myScore = war.myClanScore || 0;
        let oppScore = war.opponentClanScore || 0;

        // If opponent is a bot, simulate their score here if needed,
        // or rely on client-side simulation during the active phase.
        // For server safety, let's just use whatever score is recorded.

        const won = myScore > oppScore;
        const tied = myScore === oppScore;

        // Distribute rewards? (In a full app we'd iterate over clan members)
        const trophyChange = won ? 50 : (tied ? 0 : -25);
        
        batch.update(doc.ref, {
            trophies: admin.firestore.FieldValue.increment(trophyChange),
            activeWar: admin.firestore.FieldValue.delete() // Reset war
        });
    });

    // 3. Find all clans in 'active' to simulate bot scores
    const activeOngoingSnapshot = await db.collection("clans")
        .where("activeWar.phase", "==", "active")
        .get();
        
    activeOngoingSnapshot.docs.forEach((doc) => {
        const clanData = doc.data();
        const war = clanData.activeWar;
        
        if (war && war.opponentClanId && war.opponentClanId.startsWith("bot_")) {
            // It's a bot opponent. Give them random points (e.g. 10 to 50 every 5 minutes)
            const randomPoints = Math.floor(Math.random() * 41) + 10;
            batch.update(doc.ref, {
                "activeWar.opponentClanScore": admin.firestore.FieldValue.increment(randomPoints)
            });
        }
    });

    if (prepSnapshot.size > 0 || activeSnapshot.size > 0 || activeOngoingSnapshot.size > 0) {
        await batch.commit();
        console.log(`Processed ${prepSnapshot.size} preparation transitions, ${activeSnapshot.size} active completions, and updated bots in ${activeOngoingSnapshot.size} clans.`);
        
        // Send push notifications for clans that transitioned to 'active'
        for (const clan of clansToNotify) {
            const members = clan.members || [];
            const opponentName = clan.activeWar?.opponentClanName || "an enemy";
            for (const member of members) {
                if (member.id) {
                    await sendPushNotification(member.id, "Clan War Started! ⚔️", `Your clan is now at war with ${opponentName}! Attack now!`);
                }
            }
        }
    } else {
        console.log("No clan wars to transition.");
    }
    
    return null;
});

// -------------------------------------------------------------------
// 3. HTTP Callable: Record Clan War Attack
// -------------------------------------------------------------------
export const recordClanWarAttack = fitRpgOnCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const uid = context.auth.uid;
    // Ignore client `won` — server rolls outcome from power.

    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    if (!userData || !userData.clanId) {
        throw new functions.https.HttpsError("failed-precondition", "User is not in a clan.");
    }

    const won = rollClanWarWin(userData.basePower || 100);
    const scoreToAdd = won ? 100 : 0;

    const clanId = userData.clanId;
    const clanRef = db.collection("clans").doc(clanId);

    const result = await db.runTransaction(async (transaction) => {
        const clanDoc = await transaction.get(clanRef);
        if (!clanDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Clan not found.");
        }

        const clanData = clanDoc.data()!;
        if (!clanData.activeWar || clanData.activeWar.phase !== "active") {
            throw new functions.https.HttpsError("failed-precondition", "Clan is not currently in an active war.");
        }

        const members = clanData.members || [];
        const memberIndex = members.findIndex((m: any) => m.id === uid);
        if (memberIndex === -1) {
            throw new functions.https.HttpsError("permission-denied", "Not a clan member.");
        }
        if ((members[memberIndex].warAttacksUsed || 0) >= 3) {
            throw new functions.https.HttpsError("resource-exhausted", "Attack limit reached for this war.");
        }

        const opponentClanId = clanData.activeWar.opponentClanId || null;
        let oppRef: admin.firestore.DocumentReference | null = null;
        let oppDoc: admin.firestore.DocumentSnapshot | null = null;
        if (opponentClanId && !String(opponentClanId).startsWith("bot_")) {
            oppRef = db.collection("clans").doc(opponentClanId);
            oppDoc = await transaction.get(oppRef);
        }

        members[memberIndex].warAttacksUsed = (members[memberIndex].warAttacksUsed || 0) + 1;
        if (won) {
            members[memberIndex].warScoreContributed = (members[memberIndex].warScoreContributed || 0) + scoreToAdd;
        }

        transaction.update(clanRef, {
            "activeWar.myClanScore": admin.firestore.FieldValue.increment(scoreToAdd),
            members: members
        });

        if (oppRef && oppDoc && oppDoc.exists && scoreToAdd > 0) {
            transaction.update(oppRef, {
                "activeWar.opponentClanScore": admin.firestore.FieldValue.increment(scoreToAdd)
            });
        }

        // Single reward path: grant war attack rewards server-side (client must not award).
        const userRef = db.collection("users").doc(uid);
        const xpGain = won ? 80 : 25;
        const goldGain = won ? 40 : 10;
        const selectedClass = userData.selectedClass || "Archer";
        const { updates: progUpdates } = applyXpToProgression(
            userData.progressions || {},
            selectedClass,
            xpGain,
            userData
        );
        const cls = selectedClass;
        const trophies = { ...(userData.classTrophies || {}) };
        const deltaT = won ? 20 : -10;
        trophies[cls] = Math.max(0, (trophies[cls] || 0) + deltaT);
        transaction.update(userRef, {
            ...progUpdates,
            gold: admin.firestore.FieldValue.increment(goldGain),
            classTrophies: trophies,
            pvpTrophies: trophies[cls] || 0,
        });

        return { success: true, scoreAdded: scoreToAdd, won, opponentClanId, myName: userData.name || userData.username || "A rival" };
    });

    if (result.success && result.won && result.opponentClanId && !result.opponentClanId.startsWith("bot_")) {
        const oppClanDoc = await db.collection("clans").doc(result.opponentClanId).get();
        if (oppClanDoc.exists) {
            const oppClan = oppClanDoc.data() || {};
            if (oppClan && oppClan.members) {
                for (const member of oppClan.members) {
                    if (member.id) {
                        await sendPushNotification(member.id, "Clan Under Attack! 🚨", `${result.myName} just scored points against your clan!`);
                    }
                }
            }
        }
    }

    return { success: result.success, scoreAdded: result.scoreAdded, won: result.won };
});

// -------------------------------------------------------------------
// 4. HTTP Callable: Attack World Boss
// -------------------------------------------------------------------
export const attackWorldBoss = fitRpgOnCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }

    const uid = context.auth.uid;
    const damage = data.damage;

    if (typeof damage !== "number" || damage <= 0 || damage > WORLD_BOSS_MAX_DAMAGE_PER_CALL) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid or excessive damage amount.");
    }

    const bossRef = db.collection("world_bosses").doc("current");
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (transaction) => {
        const bossDoc = await transaction.get(bossRef);
        const userDoc = await transaction.get(userRef);
        if (!bossDoc.exists) {
            throw new functions.https.HttpsError("not-found", "World boss not found.");
        }
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found.");
        }

        const bossData = bossDoc.data()!;
        const userData = userDoc.data()!;
        if (!bossData.isActive || bossData.currentHealth <= 0) {
            throw new functions.https.HttpsError("failed-precondition", "World boss is dead or inactive.");
        }

        const nowMs = Date.now();
        const windowStart = userData.worldBossAttackWindowStart
            ? (userData.worldBossAttackWindowStart.toMillis
                ? userData.worldBossAttackWindowStart.toMillis()
                : Number(userData.worldBossAttackWindowStart))
            : 0;
        let attackCount = userData.worldBossAttackCount || 0;
        if (!windowStart || nowMs - windowStart > 60 * 60 * 1000) {
            attackCount = 0;
        }
        if (attackCount >= WORLD_BOSS_ATTACKS_PER_HOUR) {
            throw new functions.https.HttpsError("resource-exhausted", "World boss attack rate limit reached.");
        }

        const energy = userData.energy || 0;
        if (energy < WORLD_BOSS_ATTACK_ENERGY) {
            throw new functions.https.HttpsError("failed-precondition", "Not enough energy.");
        }

        const currentHealth = Math.max(0, bossData.currentHealth - damage);
        const topAttackers = { ...(bossData.topAttackers || {}) };
        topAttackers[uid] = (topAttackers[uid] || 0) + damage;

        const bossUpdates: any = {
            currentHealth,
            topAttackers,
        };
        if (currentHealth <= 0) {
            bossUpdates.isActive = false;
        }
        transaction.update(bossRef, bossUpdates);

        transaction.update(userRef, {
            energy: energy - WORLD_BOSS_ATTACK_ENERGY,
            worldBossAttackCount: attackCount + 1,
            worldBossAttackWindowStart: attackCount === 0
                ? admin.firestore.Timestamp.now()
                : (userData.worldBossAttackWindowStart || admin.firestore.Timestamp.now()),
        });
    });

    return { success: true, energySpent: WORLD_BOSS_ATTACK_ENERGY };
});

// -------------------------------------------------------------------
// 4b. PubSub Cron: Process World Boss Cycle
// -------------------------------------------------------------------
export const processWorldBossCycle = functions.pubsub.schedule("0 * * * *").onRun(async (context) => {
    const bossRef = db.collection("world_bosses").doc("current");

    // Settlement lock via transaction to prevent double rewards from overlapping cron runs.
    const settlement = await db.runTransaction(async (transaction) => {
        const bossDoc = await transaction.get(bossRef);
        if (!bossDoc.exists) {
            const defaultBoss = {
                id: "current",
                bossTemplateId: "boss_dragon",
                maxHealth: 10000000,
                currentHealth: 10000000,
                isActive: true,
                startedAt: admin.firestore.Timestamp.now(),
                topAttackers: {},
                rewardsSettled: false,
            };
            transaction.set(bossRef, defaultBoss);
            return { action: "initialized" as const };
        }

        const bossData = bossDoc.data()!;
        const now = admin.firestore.Timestamp.now().toMillis();
        const startedAt = bossData.startedAt ? bossData.startedAt.toMillis() : now;
        const isOld = (now - startedAt) > 7 * 24 * 60 * 60 * 1000;

        if (bossData.isActive && bossData.currentHealth > 0 && !isOld) {
            return { action: "noop" as const };
        }

        if (bossData.currentHealth <= 0 && !bossData.rewardsSettled) {
            transaction.update(bossRef, { rewardsSettled: true, isActive: false });
            return {
                action: "reward" as const,
                topAttackers: bossData.topAttackers || {},
            };
        }

        // Spawn replacement (defeated+settled, expired, or inactive)
        const templates = [
            { id: "boss_goblin", health: 5000000 },
            { id: "boss_orc", health: 15000000 },
            { id: "boss_dragon", health: 30000000 },
        ];
        const randomTemplate = templates[Math.floor(Math.random() * templates.length)];
        transaction.set(bossRef, {
            id: "current",
            bossTemplateId: randomTemplate.id,
            maxHealth: randomTemplate.health,
            currentHealth: randomTemplate.health,
            isActive: true,
            startedAt: admin.firestore.Timestamp.now(),
            topAttackers: {},
            rewardsSettled: false,
        });
        return { action: "spawned" as const, templateId: randomTemplate.id };
    });

    if (settlement.action === "reward") {
        const topAttackers = settlement.topAttackers || {};
        const sortedAttackers = Object.entries(topAttackers)
            .sort((a: any, b: any) => b[1] - a[1])
            .slice(0, 100);

        const batch = db.batch();
        sortedAttackers.forEach(([uid], index) => {
            const userRef = db.collection("users").doc(uid);
            let rewardGold = 100;
            let rewardXP = 500;
            if (index === 0) { rewardGold = 5000; rewardXP = 10000; }
            else if (index < 10) { rewardGold = 2000; rewardXP = 5000; }
            else if (index < 50) { rewardGold = 500; rewardXP = 1500; }

            batch.set(userRef, {
                gold: admin.firestore.FieldValue.increment(rewardGold),
                pendingWorldBossXp: admin.firestore.FieldValue.increment(rewardXP),
            }, { merge: true });
        });

        if (sortedAttackers.length > 0) {
            await batch.commit();
            console.log(`Distributed rewards to ${sortedAttackers.length} players for defeating world boss.`);
        }

        // Spawn next boss after settlement
        const templates = [
            { id: "boss_goblin", health: 5000000 },
            { id: "boss_orc", health: 15000000 },
            { id: "boss_dragon", health: 30000000 },
        ];
        const randomTemplate = templates[Math.floor(Math.random() * templates.length)];
        await bossRef.set({
            id: "current",
            bossTemplateId: randomTemplate.id,
            maxHealth: randomTemplate.health,
            currentHealth: randomTemplate.health,
            isActive: true,
            startedAt: admin.firestore.Timestamp.now(),
            topAttackers: {},
            rewardsSettled: false,
        });
        console.log(`Spawned new world boss: ${randomTemplate.id}`);
    } else if (settlement.action === "spawned") {
        console.log(`Spawned new world boss: ${settlement.templateId}`);
    } else if (settlement.action === "initialized") {
        console.log("Initialized first world boss.");
    }

    return null;
});

// -------------------------------------------------------------------
// 5. HTTP Callable: Send Friend Request
// -------------------------------------------------------------------
export const sendFriendRequest = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const myUid = context.auth.uid;
    const targetUid = data.targetUid;
    
    if (!targetUid || myUid === targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid target user.");
    }

    const targetRef = db.collection("users").doc(targetUid);
    
    let sentRequest = false;
    await db.runTransaction(async (transaction) => {
        const targetDoc = await transaction.get(targetRef);
        if (!targetDoc.exists) throw new functions.https.HttpsError("not-found", "Target not found.");
        
        const targetData = targetDoc.data();
        if (!targetData) return;
        
        const friends = targetData.friends || [];
        const friendRequests = targetData.friendRequests || [];
        
        if (!friends.includes(myUid) && !friendRequests.includes(myUid)) {
            friendRequests.push(myUid);
            transaction.update(targetRef, { friendRequests: friendRequests });
            sentRequest = true;
        }
    });

    if (sentRequest) {
        const myDoc = await db.collection("users").doc(myUid).get();
        const myName = myDoc.data()?.username || myDoc.data()?.name || "Someone";
        await sendPushNotification(targetUid, "Friend Request", `${myName} sent you a friend request!`);
    }
    
    return { success: true };
});

// -------------------------------------------------------------------
// 5b. HTTP Callable: Search Players (by username prefix or UID)
// -------------------------------------------------------------------
export const searchPlayers = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const query: string = (data.query || "").trim();
    if (query.length < 2) return { players: [] };
    
    const myUid = context.auth.uid;
    const results: any[] = [];
    
    // If query looks like a UID (20+ chars), try exact doc lookup
    if (query.length >= 20) {
        try {
            const directDoc = await db.collection("users").doc(query).get();
            if (directDoc.exists && directDoc.id !== myUid) {
                results.push({ id: directDoc.id, ...directDoc.data() });
                return { players: results };
            }
        } catch (_) { /* ignore */ }
    }
    
    // Username prefix search using usernameLower field
    const lowerQuery = query.toLowerCase();
    const snap = await db.collection("users")
        .where("usernameLower", ">=", lowerQuery)
        .where("usernameLower", "<", lowerQuery + "\uf8ff")
        .limit(20)
        .get();
    
    for (const doc of snap.docs) {
        if (doc.id !== myUid) {
            results.push({ id: doc.id, ...doc.data() });
        }
    }
    
    // Fallback: exact case-insensitive username match
    if (results.length === 0) {
        const exactSnap = await db.collection("users")
            .where("username", "==", query)
            .limit(5)
            .get();
        for (const doc of exactSnap.docs) {
            if (doc.id !== myUid) {
                results.push({ id: doc.id, ...doc.data() });
            }
        }
    }
    
    return { players: results };
});

// -------------------------------------------------------------------
// 5c. HTTP Callable: Invite Friend to 3v3 Team
// -------------------------------------------------------------------
export const inviteToTeam3v3 = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const myUid = context.auth.uid;
    const ticketId: string = data.ticketId;
    const targetUid: string = data.targetUid;
    
    if (!ticketId || !targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "ticketId and targetUid required.");
    }
    
    const ticketRef = db.collection("matchmaking").doc(ticketId);
    const ticketDoc = await ticketRef.get();
    
    if (!ticketDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Lobby ticket not found.");
    }
    
    const ticketData = ticketDoc.data() || {};
    if (ticketData.uid !== myUid) {
        throw new functions.https.HttpsError("permission-denied", "Only the lobby host can invite.");
    }
    
    const currentTeam: any[] = ticketData.team || [];
    const pendingInvites: string[] = ticketData.pendingInvites || [];
    
    if (currentTeam.length + pendingInvites.length >= 3) {
        return { success: false, reason: "Team slots full" };
    }
    
    if (!pendingInvites.includes(targetUid)) {
        pendingInvites.push(targetUid);
        await ticketRef.update({ pendingInvites });
    }
    
    const myDoc = await db.collection("users").doc(myUid).get();
    const myName = myDoc.data()?.username || myDoc.data()?.name || "Someone";
    await sendPushNotification(targetUid, "3v3 Team Invite!", `${myName} invited you to join their 3v3 team!`);
    
    return { success: true };
});

// -------------------------------------------------------------------
// 6. HTTP Callable: Accept Friend Request
// -------------------------------------------------------------------
export const acceptFriendRequest = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const myUid = context.auth.uid;
    const senderUid = data.senderUid;
    
    if (!senderUid || myUid === senderUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid sender.");
    }

    const myRef = db.collection("users").doc(myUid);
    const senderRef = db.collection("users").doc(senderUid);
    
    let accepted = false;
    await db.runTransaction(async (transaction) => {
        const myDoc = await transaction.get(myRef);
        const senderDoc = await transaction.get(senderRef);
        
        if (!myDoc.exists || !senderDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found.");
        }
        
        const myData = myDoc.data() || {};
        const senderData = senderDoc.data() || {};
        
        const myRequests = [...(myData.friendRequests || [])];
        const myFriends = [...(myData.friends || [])];
        const senderFriends = [...(senderData.friends || [])];
        
        const requestIndex = myRequests.indexOf(senderUid);
        if (requestIndex === -1) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "No pending friend request from this user."
            );
        }
        myRequests.splice(requestIndex, 1);
        
        if (!myFriends.includes(senderUid)) {
            myFriends.push(senderUid);
        }
        if (!senderFriends.includes(myUid)) {
            senderFriends.push(myUid);
        }
        
        transaction.update(myRef, {
            friendRequests: myRequests,
            friends: myFriends
        });
        
        transaction.update(senderRef, {
            friends: senderFriends
        });
        accepted = true;
    });

    if (accepted) {
        const myDoc = await db.collection("users").doc(myUid).get();
        const myName = myDoc.data()?.name || myDoc.data()?.username || "Someone";
        await sendPushNotification(senderUid, "Friend Request Accepted", `${myName} accepted your request!`);
    }
    
    return { success: true };
});

// -------------------------------------------------------------------
// 6b. HTTP Callable: Decline Friend Request
// -------------------------------------------------------------------
export const declineFriendRequest = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const myUid = context.auth.uid;
    const senderUid = data.senderUid;

    if (!senderUid || myUid === senderUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid sender.");
    }

    const myRef = db.collection("users").doc(myUid);
    const senderRef = db.collection("users").doc(senderUid);

    await db.runTransaction(async (transaction) => {
        const myDoc = await transaction.get(myRef);
        const senderDoc = await transaction.get(senderRef);

        if (!myDoc.exists || !senderDoc.exists) return;

        const myData = myDoc.data() || {};
        const myRequests: string[] = myData.friendRequests || [];
        const requestIndex = myRequests.indexOf(senderUid);
        if (requestIndex > -1) {
            myRequests.splice(requestIndex, 1);
            transaction.update(myRef, { friendRequests: myRequests });
        }
    });

    return { success: true };
});

// -------------------------------------------------------------------
// 6c. HTTP Callable: Accept Friend Duel
// -------------------------------------------------------------------
export const acceptFriendDuel = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const ticketId = data.ticketId;
    const acceptor = data.acceptor; // { id, name, characterClass, health, maxHealth, avatarName, reps? }

    if (!ticketId || !acceptor || acceptor.id !== uid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid duel accept payload.");
    }

    const ticketRef = db.collection("matchmaking").doc(ticketId);

    const result = await db.runTransaction(async (transaction) => {
        const ticketDoc = await transaction.get(ticketRef);
        if (!ticketDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Duel challenge not found.");
        }
        const ticket = ticketDoc.data()!;
        if (ticket.status !== "waitingForFriend") {
            throw new functions.https.HttpsError("failed-precondition", "Challenge is no longer available.");
        }
        if (ticket.targetUid !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Not the challenged player.");
        }
        const battleId = ticket.battleId;
        if (!battleId) {
            throw new functions.https.HttpsError("failed-precondition", "Challenge missing battle.");
        }

        const battleRef = db.collection("battles").doc(battleId);
        const battleDoc = await transaction.get(battleRef);
        if (!battleDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Battle not found.");
        }

        const acceptorPlayer = {
            id: acceptor.id,
            name: acceptor.name || "Player",
            characterClass: acceptor.characterClass || "Swordsman",
            health: Number(acceptor.health) || 110,
            maxHealth: Number(acceptor.maxHealth) || 110,
            avatarName: acceptor.avatarName || "avatar_swordsman",
            reps: 0
        };

        transaction.update(battleRef, {
            opponentTeam: [acceptorPlayer],
            status: "active",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        transaction.update(ticketRef, {
            status: "matched"
        });

        const challenger = (ticket.team && ticket.team[0]) || {
            id: ticket.uid,
            name: ticket.playerName,
            characterClass: ticket.playerClass,
            health: 100 + (ticket.playerLevel || 1) * 10,
            maxHealth: 100 + (ticket.playerLevel || 1) * 10,
            avatarName: ticket.playerAvatar,
            reps: 0
        };

        return { battleId, challenger, acceptor: acceptorPlayer };
    });

    return { success: true, ...result };
});

// -------------------------------------------------------------------
// 6d. HTTP Callable: Decline Friend Duel
// -------------------------------------------------------------------
export const declineFriendDuel = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const ticketId = data.ticketId;
    if (!ticketId) throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");

    const ticketRef = db.collection("matchmaking").doc(ticketId);
    await db.runTransaction(async (transaction) => {
        const ticketDoc = await transaction.get(ticketRef);
        if (!ticketDoc.exists) return;
        const ticket = ticketDoc.data()!;
        if (ticket.targetUid !== uid && ticket.uid !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Not part of this duel.");
        }
        if (ticket.battleId) {
            const battleRef = db.collection("battles").doc(ticket.battleId);
            transaction.set(battleRef, {
                status: "completed",
                winnerId: "declined"
            }, { merge: true });
        }
        transaction.delete(ticketRef);
    });

    return { success: true };
});

// -------------------------------------------------------------------
// 7. HTTP Callable: Join Team (queue join + 3v3 lobby invite accept)
// -------------------------------------------------------------------
export const joinTeam = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const ticketId = data.ticketId;
    const guests = data.guests || [];
    
    if (!ticketId || !Array.isArray(guests) || guests.length === 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
    }

    const callerIsGuest = guests.some((g: any) => g && g.id === uid);
    if (!callerIsGuest) {
        throw new functions.https.HttpsError("permission-denied", "Caller must be included in guests.");
    }

    const ref = db.collection("matchmaking").doc(ticketId);
    
    let success = false;
    let battleId: string | null = null;
    let joinedPlayer: any = null;
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingTeammates") return;

        const pending: string[] = ticket.pendingInvites || [];
        const isLobby = typeof ticket.battleId === "string" && ticket.battleId.length > 0;
        // Private 3v3 lobby: only pending invitees may join via this CF.
        if (isLobby && !pending.includes(uid)) {
            return;
        }
        
        const merged = mergeTeamGuests(ticket.team || [], guests, 3);
        if (!merged.ok) return;
        
        const updates: any = { team: merged.team };
        if (pending.includes(uid)) {
            updates.pendingInvites = admin.firestore.FieldValue.arrayRemove(uid);
        }
        // Open queue promotes at 3; lobby stays searchingTeammates until host starts.
        if (!isLobby && merged.team.length === 3) {
            updates.status = "searchingOpponent";
        }
        
        transaction.update(ref, updates);
        battleId = isLobby ? ticket.battleId : null;
        joinedPlayer = guests.find((g: any) => g && g.id === uid) || null;
        success = true;
    });

    // Sync acceptor onto lobby battle doc outside ticket transaction
    if (success && battleId && joinedPlayer) {
        try {
            await db.collection("battles").doc(battleId).update({
                localTeam: admin.firestore.FieldValue.arrayUnion(joinedPlayer),
            });
        } catch (e) {
            console.warn("joinTeam battle sync failed:", e);
        }
    }
    
    return { success: success, battleId };
});

// -------------------------------------------------------------------
// 8. HTTP Callable: Match With Opponent
// -------------------------------------------------------------------

export const matchWithOpponent = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const ticketCheck = requireMyTicketId(data.myTicketId, data.opponentTicketId);
    if (!ticketCheck.ok) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            ticketCheck.reason === "missing_my_ticket"
                ? "myTicketId required — create your ticket before matching."
                : "Invalid opponent."
        );
    }
    const opponentTicketId = ticketCheck.opponentTicketId!;
    const myTicketId = ticketCheck.myTicketId!;

    const opponentRef = db.collection("matchmaking").doc(opponentTicketId);
    const myRef = db.collection("matchmaking").doc(myTicketId);
    
    let success = false;
    let actualOpponentData: any = null;
    let resolvedBattleId = "";
    await db.runTransaction(async (transaction) => {
        const [opDoc, myDoc] = await Promise.all([
            transaction.get(opponentRef),
            transaction.get(myRef)
        ]);
        if (!opDoc.exists || !myDoc.exists) return;
        
        const currentOpp = opDoc.data();
        const myTicket = myDoc.data();
        if (!currentOpp || currentOpp.status !== "searchingOpponent") return;
        if (!myTicket || myTicket.status !== "searchingOpponent") return;
        if (myTicket.uid !== uid) return;
        
        actualOpponentData = currentOpp;
        resolvedBattleId = currentOpp.battleId || myTicket.battleId || randomUUID();
        
        transaction.update(opponentRef, {
            status: "matched",
            battleId: resolvedBattleId
        });
        transaction.update(myRef, {
            status: "matched",
            battleId: resolvedBattleId
        });
        success = true;
    });
    
    return { success: success, battleId: resolvedBattleId, opponentData: actualOpponentData };
});

// -------------------------------------------------------------------
// 8b. HTTP Callable: Purchase Shop Item
// -------------------------------------------------------------------
export const purchaseItem = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const itemId = data.itemId as string;
    if (!itemId || !(itemId in SHOP_ITEM_COSTS)) {
        throw new functions.https.HttpsError("invalid-argument", "Unknown shop item.");
    }

    const cost = SHOP_ITEM_COSTS[itemId];
    const slot = (SHOP_ITEM_SLOTS[itemId] || "weapon").toLowerCase();
    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data() || {};
        const owned: string[] = userData.ownedEquipmentIds || [];
        if (owned.includes(itemId)) {
            return { success: true, alreadyOwned: true, gold: userData.gold || 0 };
        }
        const gold = userData.gold || 0;
        if (gold < cost) {
            throw new functions.https.HttpsError("failed-precondition", "Not enough gold.");
        }
        owned.push(itemId);
        const updates: any = {
            gold: gold - cost,
            ownedEquipmentIds: owned
        };
        if (slot === "weapon" && !userData.equippedWeaponId) updates.equippedWeaponId = itemId;
        if (slot === "armor" && !userData.equippedArmorId) updates.equippedArmorId = itemId;
        if (slot === "ring" && !userData.equippedRingId) updates.equippedRingId = itemId;
        if (slot === "amulet" && !userData.equippedAmuletId) updates.equippedAmuletId = itemId;
        transaction.update(userRef, updates);
        return { success: true, alreadyOwned: false, gold: gold - cost, cost };
    });

    return result;
});

// -------------------------------------------------------------------
// 9. HTTP Callable: Equip Item
// -------------------------------------------------------------------
export const equipItem = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const itemId = data.itemId;
    const slot = data.slot; // "Weapon" or "Armor"
    
    if (!itemId || !slot) {
        throw new functions.https.HttpsError("invalid-argument", "Missing itemId or slot.");
    }
    
    const userRef = db.collection("users").doc(uid);
    
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        const userData = userDoc.data();
        if (!userData) return;
        
        const ownedIds = userData.ownedEquipmentIds || [];
        // Optional: Ensure the user actually owns the item.
        // Even starter gear should be explicitly in ownedEquipmentIds,
        // but to be safe, we allow any equip request IF the user owns it.
        // Wait, starter armors are dynamically loaded based on selectedClass.
        // We will just enforce that the user's `ownedEquipmentIds` contains it,
        // or it's one of the basic starters (e.g. w_arch_1).
        
        // Let's just trust that the client added starter weapons to ownedEquipmentIds upon creation.
        // Actually, if we look at ClassSelectionVM, it sets equippedWeaponId but doesn't put them in ownedEquipmentIds?
        // Wait, we need to be careful not to lock users out of their starter gear.
        // Let's just update the equipped ID. The client UI does the ownership check.
        // If we want to be strict:
        const isStarter = ["w_arch_1", "w_mage_1", "w_swor_1", "w_heal_1", "a_arch_1", "a_mage_1", "a_swor_1", "a_heal_1"].includes(itemId);
        if (!isStarter && !ownedIds.includes(itemId)) {
             throw new functions.https.HttpsError("failed-precondition", "User does not own this item.");
        }
        
        const updates: any = {};
        if (slot.toLowerCase() === "weapon") {
            updates.equippedWeaponId = itemId;
        } else if (slot.toLowerCase() === "armor") {
            updates.equippedArmorId = itemId;
        } else if (slot.toLowerCase() === "ring") {
            updates.equippedRingId = itemId;
        } else if (slot.toLowerCase() === "amulet") {
            updates.equippedAmuletId = itemId;
        }
        
        transaction.update(userRef, updates);
    });
    
    return { success: true };
});

// -------------------------------------------------------------------
// 10. HTTP Callable: Resolve PvE Battle
// -------------------------------------------------------------------
export const resolvePvEBattle = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const won = data.won === true;
    const bossLootChance = Math.min(Math.max(Number(data.bossLootChance) || 0.2, 0), 0.35);
    const { xp: bossXp, gold: bossGold } = clampPvERewards(data.xp, data.gold);
    
    const userRef = db.collection("users").doc(uid);
    let droppedItemId: string | null = null;
    
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        const userData = userDoc.data();
        if (!userData) return;

        // Rate limit: max 30 PvE resolves / hour
        const nowMs = Date.now();
        const windowStart = userData.pveResolveWindowStart?.toMillis
            ? userData.pveResolveWindowStart.toMillis()
            : Number(userData.pveResolveWindowStart || 0);
        let resolveCount = userData.pveResolveCount || 0;
        if (!windowStart || nowMs - windowStart > 60 * 60 * 1000) {
            resolveCount = 0;
        }
        if (resolveCount >= 30) {
            throw new functions.https.HttpsError("resource-exhausted", "PvE resolve rate limit reached.");
        }

        const updates: any = {
            pveResolveCount: resolveCount + 1,
            pveResolveWindowStart: resolveCount === 0
                ? admin.firestore.Timestamp.now()
                : (userData.pveResolveWindowStart || admin.firestore.Timestamp.now()),
        };
        
        if (won) {
            updates.gold = admin.firestore.FieldValue.increment(bossGold);
            
            const selectedClass = userData.selectedClass || "Archer";
            const { updates: progUpdates } = applyXpToProgression(
                userData.progressions || {},
                selectedClass,
                bossXp,
                userData
            );
            Object.assign(updates, progUpdates);
            
            if (Math.random() <= bossLootChance) {
                const possibleLoot = [
                    "arm_com_1", "arm_com_2", "arm_com_3", "arm_com_4", "arm_com_5", "arm_com_6", "arm_com_7", "arm_com_8",
                    "arm_rar_1", "arm_rar_2", "arm_rar_3", "arm_rar_4", "arm_rar_5", "arm_rar_6", "arm_rar_7", "arm_rar_8",
                    "arm_epi_1", "arm_epi_2", "arm_epi_3", "arm_epi_4", "arm_epi_5", "arm_epi_6", "arm_epi_7", "arm_epi_8",
                    "arm_leg_1", "arm_leg_2", "arm_leg_3", "arm_leg_4", "arm_leg_5", "arm_leg_6",
                    "arm_myt_1", "arm_myt_2", "arm_myt_3", "arm_myt_4", "arm_myt_5",
                    "rng_com_1", "rng_rar_1", "rng_epi_1", "rng_leg_1", "rng_myt_1",
                    "amu_com_1", "amu_rar_1", "amu_epi_1", "amu_leg_1", "amu_myt_1"
                ];
                
                const roll = Math.random();
                let rarityFilter = "com";
                if (roll > 0.6 && roll <= 0.85) rarityFilter = "rar";
                else if (roll > 0.85 && roll <= 0.95) rarityFilter = "epi";
                else if (roll > 0.95 && roll <= 0.99) rarityFilter = "leg";
                else if (roll > 0.99) rarityFilter = "myt";
                
                const filteredLoot = possibleLoot.filter(id => id.includes(rarityFilter));
                if (filteredLoot.length > 0) {
                    droppedItemId = filteredLoot[Math.floor(Math.random() * filteredLoot.length)];
                    
                    const ownedIds = [...(userData.ownedEquipmentIds || [])];
                    if (droppedItemId && !ownedIds.includes(droppedItemId)) {
                        ownedIds.push(droppedItemId);
                        updates.ownedEquipmentIds = ownedIds;
                    }
                }
            }
        }
        
        transaction.update(userRef, updates);
    });
    
    return { success: true, droppedItemId: droppedItemId, won, xp: won ? bossXp : 0, gold: won ? bossGold : 0 };
});

// -------------------------------------------------------------------
// 10b. HTTP Callable: Resolve PvP Battle (server-authoritative rewards)
// -------------------------------------------------------------------
export const resolvePvPBattle = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const battleId = data.battleId;
    if (!battleId || typeof battleId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "battleId required.");
    }

    const battleRef = db.collection("battles").doc(battleId);
    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
        const battleDoc = await transaction.get(battleRef);
        const userDoc = await transaction.get(userRef);
        if (!battleDoc.exists) throw new functions.https.HttpsError("not-found", "Battle not found.");
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const battle = battleDoc.data()!;
        const userData = userDoc.data()!;

        const localIds = (battle.localTeam || []).map((p: any) => p.id);
        const oppIds = (battle.opponentTeam || []).map((p: any) => p.id);
        if (!localIds.includes(uid) && !oppIds.includes(uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not a battle participant.");
        }

        const settled = battle.rewardsSettled || {};
        if (settled[uid]) {
            return { alreadySettled: true, outcome: settled[uid] };
        }

        if (battle.status !== "Finished" && battle.status !== "completed" && battle.status !== "Completed") {
            // Allow settlement when winnerId already present (host wrote completion)
            if (!battle.winnerId) {
                throw new functions.https.HttpsError("failed-precondition", "Battle not completed yet.");
            }
        }

        const outcome = pvpOutcomeForPlayer(battle.winnerId, uid);
        const rewards = rewardsForPvpOutcome(outcome);
        const selectedClass = userData.selectedClass || "Archer";
        const { updates: progUpdates } = applyXpToProgression(
            userData.progressions || {},
            selectedClass,
            rewards.xp,
            userData
        );

        const trophies = { ...(userData.classTrophies || {}) };
        trophies[selectedClass] = Math.max(0, (trophies[selectedClass] || 0) + rewards.trophies);

        const userUpdates: any = {
            ...progUpdates,
            gold: admin.firestore.FieldValue.increment(rewards.gold),
            classTrophies: trophies,
            pvpTrophies: trophies[selectedClass] || 0,
        };
        if (outcome === "win") {
            userUpdates.pvpWins = admin.firestore.FieldValue.increment(1);
        }

        settled[uid] = outcome;
        transaction.update(battleRef, {
            status: "Finished",
            rewardsSettled: settled,
        });
        transaction.update(userRef, userUpdates);

        return { alreadySettled: false, outcome, rewards };
    });

    return { success: true, ...result };
});

// -------------------------------------------------------------------
// 10c. HTTP Callable: Award capped activity rewards (training / quests / health)
// -------------------------------------------------------------------
export const awardActivityRewards = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const reason = String(data.reason || "activity").slice(0, 40);
    const { xp, gold } = clampActivityRewards(data.xp, data.gold);
    if (xp <= 0 && gold <= 0) {
        return { success: true, xp: 0, gold: 0 };
    }

    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data()!;

        const nowMs = Date.now();
        const windowStart = userData.activityRewardWindowStart?.toMillis
            ? userData.activityRewardWindowStart.toMillis()
            : Number(userData.activityRewardWindowStart || 0);
        let count = userData.activityRewardCount || 0;
        if (!windowStart || nowMs - windowStart > 60 * 60 * 1000) {
            count = 0;
        }
        if (count >= 120) {
            throw new functions.https.HttpsError("resource-exhausted", "Activity reward rate limit reached.");
        }

        const selectedClass = userData.selectedClass || "Archer";
        const updates: any = {
            activityRewardCount: count + 1,
            activityRewardWindowStart: count === 0
                ? admin.firestore.Timestamp.now()
                : (userData.activityRewardWindowStart || admin.firestore.Timestamp.now()),
            lastActivityRewardReason: reason,
        };
        if (gold > 0) {
            updates.gold = admin.firestore.FieldValue.increment(gold);
        }
        if (xp > 0) {
            const { updates: progUpdates } = applyXpToProgression(
                userData.progressions || {},
                selectedClass,
                xp,
                userData
            );
            Object.assign(updates, progUpdates);
        }
        transaction.update(userRef, updates);
    });

    return { success: true, xp, gold };
});

// -------------------------------------------------------------------
// 10d. HTTP Callable: FitRPG-scoped account cleanup (NO recursive users/{uid})
// -------------------------------------------------------------------
export const cleanupFitRPGAccount = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // Leave clan membership if present
    const clanId = userData.clanId;
    if (clanId) {
        const clanRef = db.collection("clans").doc(clanId);
        await db.runTransaction(async (transaction) => {
            const clanDoc = await transaction.get(clanRef);
            if (!clanDoc.exists) return;
            const clan = clanDoc.data()!;
            const members = (clan.members || []).filter((m: any) => m.id !== uid);
            if (clan.leaderId === uid) {
                if (members.length === 0) {
                    transaction.delete(clanRef);
                } else {
                    transaction.update(clanRef, {
                        leaderId: members[0].id,
                        members: members.map((m: any, i: number) =>
                            i === 0 ? { ...m, role: "leader" } : m
                        ),
                    });
                }
            } else {
                transaction.update(clanRef, { members });
            }
        });
    }

    // Strip FitRPG fields only — preserve sibling-app data on the same doc
    const deletions: Record<string, admin.firestore.FieldValue> = {};
    for (const key of FITRPG_USER_FIELD_KEYS) {
        deletions[key] = admin.firestore.FieldValue.delete();
    }
    deletions["pendingWorldBossXp"] = admin.firestore.FieldValue.delete();
    deletions["worldBossAttackCount"] = admin.firestore.FieldValue.delete();
    deletions["worldBossAttackWindowStart"] = admin.firestore.FieldValue.delete();
    deletions["pveResolveCount"] = admin.firestore.FieldValue.delete();
    deletions["pveResolveWindowStart"] = admin.firestore.FieldValue.delete();
    deletions["activityRewardCount"] = admin.firestore.FieldValue.delete();
    deletions["activityRewardWindowStart"] = admin.firestore.FieldValue.delete();
    deletions["lastActivityRewardReason"] = admin.firestore.FieldValue.delete();
    deletions["fitrpgDeletedAt"] = admin.firestore.FieldValue.serverTimestamp();

    if (userDoc.exists) {
        await userRef.update(deletions);
    }

    // Delete FitRPG notifications subcollection only
    const notifs = await userRef.collection("notifications").listDocuments();
    for (let i = 0; i < notifs.length; i += 400) {
        const batch = db.batch();
        notifs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
        await batch.commit();
    }

    // Cancel open matchmaking tickets owned by user
    const tickets = await db.collection("matchmaking").where("uid", "==", uid).limit(50).get();
    if (!tickets.empty) {
        const batch = db.batch();
        tickets.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
    }

    return { success: true, scoped: true };
});

// -------------------------------------------------------------------
// 12. Firestore Trigger: On Matchmaking Ticket Created
// -------------------------------------------------------------------
export const onMatchmakingTicketCreated = functions.firestore
    .document('matchmaking/{ticketId}')
    .onCreate(async (snap, context) => {
        const ticket = snap.data();
        if (ticket.status === "waitingForFriend" && ticket.targetUid && ticket.uid) {
            const senderDoc = await db.collection("users").doc(ticket.uid).get();
            const senderName = senderDoc.data()?.name || "A friend";
            
            await sendPushNotification(
                ticket.targetUid, 
                "Duel Request! ⚔️", 
                `${senderName} challenged you to a duel! Open the app to accept.`
            );
        } else if (ticket.teamType === "team3v3" && ticket.status === "searchingTeammates" && ticket.uid) {
            const senderDoc = await db.collection("users").doc(ticket.uid).get();
            const userData = senderDoc.data();
            const senderName = userData?.name || "A clanmate";
            
            if (userData && userData.clanId) {
                const clanDoc = await db.collection("clans").doc(userData.clanId).get();
                if (clanDoc.exists) {
                    const clan = clanDoc.data();
                    if (clan && clan.members) {
                        for (const member of clan.members) {
                            if (member.id && member.id !== ticket.uid) {
                                await sendPushNotification(member.id, "3v3 Team Up! 🛡️", `${senderName} is looking for teammates for 3v3 Arena!`);
                            }
                        }
                    }
                }
            }
        }
        return null;
    });

// -------------------------------------------------------------------
// 13. HTTP Callable: Fill Teammates With Bots
// -------------------------------------------------------------------
export const fillTeammatesWithBots = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const ticketId = data.ticketId;
    if (!ticketId) throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");

    const ref = db.collection("matchmaking").doc(ticketId);
    
    let lobbyBattleId: string | null = null;
    let updated = false;
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket) return;
        if (ticket.uid !== uid) return;
        if (ticket.status !== "searchingTeammates") return;
        lobbyBattleId = ticket.battleId || null;
        
        const team = ticket.team || [];
        const bots = ["HealerBot", "TankBot", "MageBot"];
        
        let botIdx = 0;
        while (team.length < 3) {
            const botClass = team.length === 1 ? "Healer" : "Mage";
            const botClassLower = botClass.toLowerCase();
            team.push({
                id: `bot_${admin.firestore.Timestamp.now().toMillis()}_${botIdx}`,
                name: bots[botIdx % bots.length] || "Bot",
                characterClass: botClass,
                health: 110,
                maxHealth: 110,
                avatarName: `avatar_${botClassLower}`,
                reps: 0
            });
            botIdx++;
        }
        
        transaction.update(ref, {
            team: team,
            status: "searchingOpponent"
        });

        if (lobbyBattleId) {
            const battleRef = db.collection("battles").doc(lobbyBattleId);
            transaction.update(battleRef, {
                localTeam: team,
                status: "Searching..."
            });
        }
        updated = true;
    });

    if (!updated) {
        throw new functions.https.HttpsError("permission-denied", "Not ticket host or invalid ticket state.");
    }
    
    return { success: true };
});

// -------------------------------------------------------------------
// 14. HTTP Callable: Trigger Opponent Bot Fallback
// -------------------------------------------------------------------

export const triggerOpponentBotFallback = fitRpgOnCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const ticketId = data.ticketId;
    const type = data.type || "duel1v1";
    if (!ticketId) throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");

    const ref = db.collection("matchmaking").doc(ticketId);
    
    let finalBattleId = "";
    const finalBattleData = await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket || ticket.uid !== uid) return;
        if (!ticket || ticket.status !== "searchingOpponent") return;
        
        const battleId = ticket.battleId || randomUUID();
        finalBattleId = battleId;
        const opponentTeam: any[] = [];
        
        if (type === "team3v3") {
            const bots = ["ShadowFiend", "DoomBringer", "NightStalker"];
            const classes = ["Swordsman", "Mage", "Archer"];
            for (let i = 0; i < 3; i++) {
                const health = 110 + (i * 10);
                const classLower = classes[i].toLowerCase();
                opponentTeam.push({
                    id: `bot_${admin.firestore.Timestamp.now().toMillis()}_${i}`,
                    name: bots[i],
                    characterClass: classes[i],
                    health: health,
                    maxHealth: health,
                    avatarName: `avatar_${classLower}`,
                    reps: 0
                });
            }
        } else {
            const myCharLevel = ticket.team && ticket.team.length > 0 ? ticket.team[0].maxHealth : 100;
            opponentTeam.push({
                id: `bot_${admin.firestore.Timestamp.now().toMillis()}`,
                name: "Shadow Warrior",
                characterClass: "Swordsman",
                health: myCharLevel,
                maxHealth: myCharLevel,
                avatarName: "avatar_swordsman",
                reps: 0
            });
        }
        
        const newBattle = {
            id: battleId,
            type: ticket.teamType || type,
            status: "active",
            localTeam: ticket.team || [],
            opponentTeam: opponentTeam,
            secondsRemaining: 60,
            combatLog: []
        };
        
        const battleRef = db.collection("battles").doc(battleId);
        const existingBattle = await transaction.get(battleRef);
        if (existingBattle.exists) {
            transaction.update(battleRef, {
                type: newBattle.type,
                status: newBattle.status,
                localTeam: newBattle.localTeam,
                opponentTeam: newBattle.opponentTeam,
                secondsRemaining: newBattle.secondsRemaining,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            transaction.set(battleRef, { ...newBattle, createdAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        
        transaction.update(ref, {
            status: "matched",
            battleId: battleId
        });
        
        return { ...newBattle, createdAt: new Date() };
    });

    if (!finalBattleId || !finalBattleData) {
        throw new functions.https.HttpsError("permission-denied", "Not ticket host or invalid ticket state.");
    }
    
    return { success: true, battleId: finalBattleId, battleData: finalBattleData };
});

// -------------------------------------------------------------------
// 15. HTTP Callable: Get Leaderboards
// -------------------------------------------------------------------
export const getLeaderboards = fitRpgOnCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    }

    const requestedTypes: string[] = data.types || ["global", "pvp_1v1"];
    const result: Record<string, any[]> = {};

    const allowedClasses = ["Archer", "Mage", "Swordsman", "Healer"];

    for (const type of requestedTypes) {
        try {
            if (type === "pvp_1v1") {
                // 1v1 leaderboard: sort by pvpTrophies (current-class trophies, updated on every battle)
                const snap = await db.collection("users")
                    .orderBy("pvpTrophies", "desc")
                    .limit(50)
                    .get();
                result[type] = snap.docs.map(d => ({ id: d.id, ...d.data() }));
            } else if (type === "global") {
                // Global leaderboard: sort by currentLevel (stored field, synced every login)
                const snap = await db.collection("users")
                    .orderBy("currentLevel", "desc")
                    .limit(50)
                    .get();
                result[type] = snap.docs.map(d => ({ id: d.id, ...d.data() }));
            } else if (type === "clans") {
                const snap = await db.collection("clans")
                    .orderBy("trophies", "desc")
                    .limit(30)
                    .get();
                result[type] = snap.docs.map(d => ({ id: d.id, ...d.data() }));
            } else if (allowedClasses.includes(type)) {
                // Per-class leaderboard: rank by classTrophies[type].
                // We fetch top 200 by currentLevel then sort in memory by the class-specific trophies.
                // This avoids composite index requirements and is accurate for typical player counts.
                const snap = await db.collection("users")
                    .orderBy("currentLevel", "desc")
                    .limit(200)
                    .get();

                const allPlayers = snap.docs.map(d => ({ id: d.id, ...d.data() } as any));

                // Sort by classTrophies[type] descending
                allPlayers.sort((a: any, b: any) => {
                    const aTrophies = (a.classTrophies && a.classTrophies[type]) ? a.classTrophies[type] : 0;
                    const bTrophies = (b.classTrophies && b.classTrophies[type]) ? b.classTrophies[type] : 0;
                    return bTrophies - aTrophies;
                });

                // Only include players who have played as this class (level > 1 or has trophies)
                const filtered = allPlayers.filter((p: any) => {
                    const progressions = p.progressions || {};
                    const classProg = progressions[type] || {};
                    const classLevel = classProg.level || 1;
                    const trophies = (p.classTrophies && p.classTrophies[type]) ? p.classTrophies[type] : 0;
                    return classLevel > 1 || trophies > 0 || p.selectedClass === type;
                });

                result[type] = filtered.slice(0, 30);
            }
        } catch (err) {
            console.error(`Failed to fetch leaderboard type=${type}:`, err);
            result[type] = [];
        }
    }

    return result;
});

// =============================================================================
// SHARED AI PROXY FUNCTIONS
// (FoodTracker + WorkoutTracker AI endpoints)
// Re-added here because rpg-fitness deploys to the same Firebase project
// (serzhanovich-ecosystem-ce700) and was wiping these functions on each deploy.
// =============================================================================

const GEMINI_API_KEY_SECRET = defineSecret("GEMINI_API_KEY");
const PEXELS_API_KEY_SECRET = defineSecret("PEXELS_API_KEY");

const AI_SERVICE_ACCOUNT = "firebase-adminsdk-fbsvc@serzhanovich-ecosystem-ce700.iam.gserviceaccount.com";
const GEMINI_MODEL = "gemini-2.5-flash-lite";
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 150;
const AUTO_BLOCK_REPORT_THRESHOLD_AI = 3;

const SAFETY_SETTINGS_USER = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_LOW_AND_ABOVE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
];

const SAFETY_SETTINGS_MODERATOR = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
];

class RateLimitError extends Error {
  retryAfterSeconds: number;
  limit: number;
  constructor(retryAfterSeconds: number, limit: number) {
    super("rate_limited");
    this.retryAfterSeconds = retryAfterSeconds;
    this.limit = limit;
  }
}

async function enforceAIRateLimit(uid: string): Promise<void> {
  const firestoreDb = admin.firestore();
  const configSnap = await firestoreDb.collection("config").doc("ai_settings").get();
  const configData = configSnap.data() || {};
  const aiWeeklyLimit = typeof configData["weeklyLimit"] === "number"
    ? configData["weeklyLimit"] as number
    : DEFAULT_AI_WEEKLY_LIMIT;
  const ref = firestoreDb.collection("ai_usage").doc(uid);

  await firestoreDb.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStart = now;
    let count = 0;

    if (snap.exists) {
      const data = snap.data() || {};
      const ws = typeof data["windowStart"] === "number" ? data["windowStart"] as number : 0;
      if (now - ws < AI_WINDOW_MS) {
        windowStart = ws;
        count = (data["count"] as number) || 0;
      }
    }

    if (count >= aiWeeklyLimit) {
      const retryAfterSeconds = Math.ceil((windowStart + AI_WINDOW_MS - now) / 1000);
      throw new RateLimitError(retryAfterSeconds, aiWeeklyLimit);
    }

    tx.set(ref, {
      windowStart,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

async function geminiApiFetch(body: Record<string, unknown>, apiKey: string): Promise<Record<string, unknown>> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  if (!resp.ok) throw new Error(`Gemini error ${resp.status}: ${text}`);
  return JSON.parse(text) as Record<string, unknown>;
}

function normalizeImageKey(keywords: unknown, title: string): string {
  let parts: string[] = Array.isArray(keywords)
    ? (keywords as unknown[]).map((k) => String(k).toLowerCase().trim()).filter(Boolean)
    : [];
  if (parts.length === 0 && title) {
    parts = String(title).toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length >= 3);
  }
  parts = [...new Set(parts)].sort();
  return parts.slice(0, 4).join("-") || "food-meal";
}

// ── 1. vertexProxy ─────────────────────────────────────────────────────────
export const vertexProxy = onRequestV2(
  {
    region: "us-central1",
    serviceAccount: AI_SERVICE_ACCOUNT,
    secrets: [GEMINI_API_KEY_SECRET],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (req, res) => {
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "Missing App Check token" });
      return;
    }
    try {
      await getAppCheck().verifyToken(appCheckToken);
    } catch {
      res.status(401).json({ error: "Invalid App Check token" });
      return;
    }

    const authHeader = req.header("Authorization") || "";
    const m = authHeader.match(/^Bearer (.+)$/i);
    if (!m) {
      res.status(401).json({ error: "Missing Firebase ID token" });
      return;
    }
    let uid: string;
    try {
      const decoded = await getAuth().verifyIdToken(m[1]);
      uid = decoded.uid;
    } catch {
      res.status(401).json({ error: "Invalid Firebase ID token" });
      return;
    }

    try {
      await enforceAIRateLimit(uid);
    } catch (e) {
      if (e instanceof RateLimitError) {
        try {
          await admin.firestore().collection("limit_hits").add({
            uid,
            limit: e.limit,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (logErr) {
          console.error("Failed to log limit hit:", logErr);
        }
        res.set("Retry-After", String(e.retryAfterSeconds));
        res.status(429).json({
          error: "weekly_limit_reached",
          message: `You've reached your weekly limit of ${e.limit} AI requests.`,
          retryAfter: e.retryAfterSeconds,
        });
        return;
      }
      console.error("Rate limit check failed:", e);
      res.status(500).json({ error: "Rate limit check failed" });
      return;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const body = (req.body || {}) as any;
    body.safetySettings = SAFETY_SETTINGS_USER;

    const streaming = req.query["stream"] === "true";
    const method = streaming ? "streamGenerateContent" : "generateContent";
    const sse = streaming ? "&alt=sse" : "";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:${method}?key=${GEMINI_API_KEY_SECRET.value()}${sse}`;

    const upstream = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!streaming) {
      const data = await upstream.text();
      if (!upstream.ok) console.error(`Vertex API Error: ${upstream.status} - ${data}`);
      res.status(upstream.status).set("Content-Type", "application/json").send(data);
      return;
    }

    if (!upstream.ok) console.error(`Vertex API Error (Streaming): ${upstream.status}`);
    res.status(upstream.status).set("Content-Type", "text/event-stream");
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const reader = (upstream.body as any).getReader();
    const decoder = new TextDecoder();
    for (;;) {
      const { done, value } = await reader.read() as { done: boolean; value: Uint8Array };
      if (done) break;
      res.write(decoder.decode(value, { stream: true }));
    }
    res.end();
  }
);

// ── 2. imageProxy ──────────────────────────────────────────────────────────
export const imageProxy = onRequestV2(
  {
    region: "us-central1",
    serviceAccount: AI_SERVICE_ACCOUNT,
    secrets: [PEXELS_API_KEY_SECRET],
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (req, res) => {
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "Missing App Check token" });
      return;
    }
    try {
      await getAppCheck().verifyToken(appCheckToken);
    } catch {
      res.status(401).json({ error: "Invalid App Check token" });
      return;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const body = (req.body || {}) as any;
    const keywords: unknown = body.keywords;
    const title: string = body.title || "";
    const key = normalizeImageKey(keywords, title);

    const firestoreDb = admin.firestore();
    const ref = firestoreDb.collection("meal_images").doc(key);

    try {
      const snap = await ref.get();
      const snapData = snap.data();
      if (snap.exists && snapData && snapData["url"]) {
        res.status(200).json({ url: snapData["url"], cached: true });
        return;
      }
    } catch (e) {
      console.error("meal_images read error:", e);
    }

    const query = Array.isArray(keywords) && (keywords as unknown[]).length
      ? (keywords as unknown[]).join(" ")
      : title || "food meal";
    try {
      const pexUrl = "https://api.pexels.com/v1/search?per_page=1&orientation=landscape&query=" +
        encodeURIComponent(query);
      const r = await fetch(pexUrl, { headers: { "Authorization": PEXELS_API_KEY_SECRET.value() } });
      if (!r.ok) {
        console.error("PEXELS ERROR", r.status, (await r.text()).slice(0, 200));
        res.status(200).json({ url: null });
        return;
      }
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const data = await r.json() as any;
      const photoUrl: string | null = data?.photos?.[0]?.src?.large || null;
      console.log("PEXELS OK", { query, total: data?.total_results, photoUrl });

      if (photoUrl) {
        await ref.set({
          url: photoUrl,
          query,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      res.status(200).json({ url: photoUrl });
    } catch (e) {
      console.error("pexels error:", e);
      res.status(200).json({ url: null });
    }
  }
);

// ── 3. deleteAccount (Food/Workout shared) ───────────────────────────────────
// WARNING: recursiveDelete(users/{uid}) wipes sibling apps. FitRPG MUST use
// cleanupFitRPGAccount + client Auth.user.delete() instead of this callable.
export const deleteAccount = onCallV2(
  {
    region: "us-central1",
    serviceAccount: AI_SERVICE_ACCOUNT,
    enforceAppCheck: true,
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsErrorV2("unauthenticated", "You must be signed in to delete your account.");
    }

    const firestoreDb = admin.firestore();
    const sharedSnap = await firestoreDb.collection("shared_workouts")
      .where("creatorUid", "==", uid).get();
    const reportsSnap = await firestoreDb.collection("reports")
      .where("reporterUid", "==", uid).get();

    const refs = [
      ...sharedSnap.docs.map((d) => d.ref),
      ...reportsSnap.docs.map((d) => d.ref),
    ];
    for (let i = 0; i < refs.length; i += 450) {
      const batch = firestoreDb.batch();
      refs.slice(i, i + 450).forEach((r) => batch.delete(r));
      await batch.commit();
    }

    await firestoreDb.recursiveDelete(firestoreDb.collection("users").doc(uid));
    return { ok: true };
  }
);

// ── 4. moderateSharedWorkout ────────────────────────────────────────────────
export const moderateSharedWorkout = onDocCreated(
  {
    document: "shared_workouts/{workoutId}",
    region: "us-central1",
    serviceAccount: AI_SERVICE_ACCOUNT,
    secrets: [GEMINI_API_KEY_SECRET],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = snap.data() as any || {};
    const ref = snap.ref;

    const title = String(data.title || "").slice(0, 300);
    const description = String(data.description || "").slice(0, 2000);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const exercises: any[] = Array.isArray(data.exercises) ? data.exercises.slice(0, 50) : [];
    const exerciseTexts = exercises
      .map((e) => {
        const name = String(e?.name || "").slice(0, 200);
        const notes = String(e?.notes || "").slice(0, 500);
        return notes ? `${name} — ${notes}` : name;
      })
      .filter(Boolean)
      .join("\n");

    const systemPrompt = `You are a strict content moderator for a fitness app.\nDecide if user-submitted workout text is acceptable on a public platform that may be used by minors.\nBLOCK any of:\n- Sexual content, suggestive language, or pornography\n- Hate speech, slurs, harassment of any group\n- Threats, violence promotion, self-harm encouragement\n- Illegal activity, drug promotion (including PEDs as instructions), spam, advertising\n- Personal data (phone numbers, emails, home addresses)\n- Off-topic content unrelated to fitness/workouts\nAPPROVE otherwise.\nRespond ONLY with JSON: {"decision":"approved"|"blocked","reason":"short reason"}.`;
    const userPayload = `TITLE: ${title}\nDESCRIPTION: ${description}\nEXERCISES:\n${exerciseTexts}`;

    let decision = "blocked";
    let reason = "Moderation service error";

    try {
      const body: Record<string, unknown> = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: userPayload }] }],
        generationConfig: {
          temperature: 0.0,
          maxOutputTokens: 100,
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              decision: { type: "string", enum: ["approved", "blocked"] },
              reason: { type: "string" },
            },
            required: ["decision", "reason"],
          },
        },
        safetySettings: SAFETY_SETTINGS_MODERATOR,
      };
      const resp = await geminiApiFetch(body, GEMINI_API_KEY_SECRET.value());
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const textRaw = (resp as any)?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
      const parsed = JSON.parse(textRaw) as { decision?: string; reason?: string };
      if (parsed.decision === "approved" || parsed.decision === "blocked") {
        decision = parsed.decision;
        reason = String(parsed.reason || "").slice(0, 500);
      }
    } catch (e) {
      console.error("Moderation error:", e);
      decision = "blocked";
      reason = "Moderation service error";
    }

    await ref.update({
      status: decision,
      moderationReason: reason,
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`Moderated workout ${event.params.workoutId}: ${decision} — ${reason}`);
  }
);

// ── 5. onReportCreated ─────────────────────────────────────────────────────
export const onReportCreated = onDocCreated(
  {
    document: "reports/{reportId}",
    region: "us-central1",
    serviceAccount: AI_SERVICE_ACCOUNT,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const data = snap.data() as any || {};
    const workoutId: unknown = data.workoutId;
    if (!workoutId || typeof workoutId !== "string") {
      console.warn("Report has no workoutId:", event.params.reportId);
      return;
    }

    const firestoreDb = admin.firestore();
    const workoutRef = firestoreDb.collection("shared_workouts").doc(workoutId);

    try {
      await firestoreDb.runTransaction(async (tx) => {
        const doc = await tx.get(workoutRef);
        if (!doc.exists) {
          console.warn(`Reported workout ${workoutId} does not exist`);
          return;
        }
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const current = doc.data() as any || {};
        const newCount = ((current.reportCount as number) || 0) + 1;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const updates: any = { reportCount: newCount };
        if (newCount >= AUTO_BLOCK_REPORT_THRESHOLD_AI && current.status !== "blocked") {
          updates.status = "blocked";
          updates.moderationReason = `Auto-blocked after ${newCount} user reports`;
          updates.moderatedAt = admin.firestore.FieldValue.serverTimestamp();
        }
        tx.update(workoutRef, updates);
      });
      console.log(`Report ${event.params.reportId} processed for workout ${workoutId}`);
    } catch (e) {
      console.error("Report processing error:", e);
    }
  }
);
