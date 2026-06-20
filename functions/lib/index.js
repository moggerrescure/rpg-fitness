"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.triggerOpponentBotFallback = exports.fillTeammatesWithBots = exports.onMatchmakingTicketCreated = exports.resolvePvEBattle = exports.equipItem = exports.matchWithOpponent = exports.joinTeam = exports.acceptFriendRequest = exports.sendFriendRequest = exports.processWorldBossCycle = exports.attackWorldBoss = exports.recordClanWarAttack = exports.processClanWarPhases = exports.matchmakeClanWar = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
// -------------------------------------------------------------------
// Helper: Send Push Notification
// -------------------------------------------------------------------
async function sendPushNotification(uid, title, body, data) {
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
    }
    catch (e) {
        console.error(`Failed to send push to ${uid}`, e);
    }
}
// -------------------------------------------------------------------
// 1. HTTP Callable: Matchmake Clan War
// -------------------------------------------------------------------
exports.matchmakeClanWar = functions.https.onCall(async (data, context) => {
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
        const myClanData = myClanDoc.data();
        // Prevent starting if already searching or in war
        if (myClanData.activeWar && myClanData.activeWar.phase !== "none") {
            throw new functions.https.HttpsError("already-exists", "Clan is already in a war or searching.");
        }
        // Try to find another clan that is currently 'searching'
        // Note: Firestore transactions require all reads before writes.
        // Doing a query inside a transaction is allowed in Admin SDK.
        const searchingClansSnapshot = await transaction.get(db.collection("clans")
            .where("activeWar.phase", "==", "searching")
            .limit(1));
        let opponentId = null;
        let opponentName = null;
        // Found a real clan?
        if (!searchingClansSnapshot.empty) {
            const oppDoc = searchingClansSnapshot.docs[0];
            if (oppDoc.id !== clanId) {
                opponentId = oppDoc.id;
                opponentName = oppDoc.data().name;
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
            transaction.update(clanRef, { activeWar: myWar });
            transaction.update(oppRef, { activeWar: oppWar });
            return { success: true, opponentName: opponentName, isBot: false };
        }
        else {
            // NO MATCH: Generate a Shadow Bot immediately
            const botId = "bot_" + Math.random().toString(36).substring(7);
            const botName = "ShadowFiend (Bot)";
            const myWar = {
                phase: "preparation",
                phaseEndsAt: prepEndDate,
                opponentClanId: botId,
                opponentClanName: botName,
                myClanScore: 0,
                opponentClanScore: 0
            };
            // We don't save the bot to the DB to save reads/writes.
            // When processing scores, if opponent is bot, we simulate their score on the fly.
            transaction.update(clanRef, { activeWar: myWar });
            return { success: true, opponentName: botName, isBot: true };
        }
    });
});
// -------------------------------------------------------------------
// 2. PubSub Cron: Process Clan War Phases
// -------------------------------------------------------------------
// Runs every 5 minutes
exports.processClanWarPhases = functions.pubsub.schedule("*/5 * * * *").onRun(async (context) => {
    var _a;
    const now = admin.firestore.Timestamp.now();
    // 1. Find all clans in 'preparation' where phaseEndsAt <= now
    const prepSnapshot = await db.collection("clans")
        .where("activeWar.phase", "==", "preparation")
        .where("activeWar.phaseEndsAt", "<=", now)
        .get();
    const batch = db.batch();
    const clansToNotify = [];
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
            const opponentName = ((_a = clan.activeWar) === null || _a === void 0 ? void 0 : _a.opponentClanName) || "an enemy";
            for (const member of members) {
                if (member.id) {
                    await sendPushNotification(member.id, "Clan War Started! ⚔️", `Your clan is now at war with ${opponentName}! Attack now!`);
                }
            }
        }
    }
    else {
        console.log("No clan wars to transition.");
    }
    return null;
});
// -------------------------------------------------------------------
// 3. HTTP Callable: Record Clan War Attack
// -------------------------------------------------------------------
exports.recordClanWarAttack = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }
    const uid = context.auth.uid;
    const won = data.won;
    const scoreToAdd = won ? 100 : 0;
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    if (!userData || !userData.clanId) {
        throw new functions.https.HttpsError("failed-precondition", "User is not in a clan.");
    }
    const clanId = userData.clanId;
    const clanRef = db.collection("clans").doc(clanId);
    // Use a transaction to safely update member score and total clan score
    const result = await db.runTransaction(async (transaction) => {
        var _a;
        const clanDoc = await transaction.get(clanRef);
        if (!clanDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Clan not found.");
        }
        const clanData = clanDoc.data();
        if (!clanData.activeWar || clanData.activeWar.phase !== "active") {
            throw new functions.https.HttpsError("failed-precondition", "Clan is not currently in an active war.");
        }
        // Increment the overall clan score
        transaction.update(clanRef, {
            "activeWar.myClanScore": admin.firestore.FieldValue.increment(scoreToAdd)
        });
        // Also we should ideally update the specific member's warScoreContributed
        // Since members is an array, we read it, modify the element, and write it back.
        const members = clanData.members || [];
        const memberIndex = members.findIndex((m) => m.id === uid);
        if (memberIndex !== -1) {
            members[memberIndex].warAttacksUsed = (members[memberIndex].warAttacksUsed || 0) + 1;
            if (won) {
                members[memberIndex].warScoreContributed = (members[memberIndex].warScoreContributed || 0) + scoreToAdd;
            }
            transaction.update(clanRef, { members: members });
        }
        return { success: true, scoreAdded: scoreToAdd, opponentClanId: (_a = clanData.activeWar) === null || _a === void 0 ? void 0 : _a.opponentClanId, myName: userData.name || "A rival" };
    });
    if (result.success && result.opponentClanId && !result.opponentClanId.startsWith("bot_")) {
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
    return { success: result.success, scoreAdded: result.scoreAdded };
});
// -------------------------------------------------------------------
// 4. HTTP Callable: Attack World Boss
// -------------------------------------------------------------------
exports.attackWorldBoss = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    const damage = data.damage;
    // Anti-cheat limit: Max 500 damage per call
    if (typeof damage !== "number" || damage <= 0 || damage > 500) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid or excessive damage amount.");
    }
    const bossRef = db.collection("world_bosses").doc("current");
    await db.runTransaction(async (transaction) => {
        const bossDoc = await transaction.get(bossRef);
        if (!bossDoc.exists) {
            throw new functions.https.HttpsError("not-found", "World boss not found.");
        }
        const bossData = bossDoc.data();
        if (!bossData || !bossData.isActive || bossData.currentHealth <= 0) {
            throw new functions.https.HttpsError("failed-precondition", "World boss is dead or inactive.");
        }
        const currentHealth = Math.max(0, bossData.currentHealth - damage);
        const topAttackers = bossData.topAttackers || {};
        const currentDmg = topAttackers[uid] || 0;
        topAttackers[uid] = currentDmg + damage;
        const updates = {
            currentHealth: currentHealth,
            topAttackers: topAttackers
        };
        if (currentHealth <= 0) {
            updates.isActive = false;
        }
        transaction.update(bossRef, updates);
    });
    return { success: true };
});
// -------------------------------------------------------------------
// 4b. PubSub Cron: Process World Boss Cycle
// -------------------------------------------------------------------
exports.processWorldBossCycle = functions.pubsub.schedule("0 * * * *").onRun(async (context) => {
    const bossRef = db.collection("world_bosses").doc("current");
    const bossDoc = await bossRef.get();
    if (!bossDoc.exists) {
        // Create initial boss if none exists
        const defaultBoss = {
            id: "current",
            bossTemplateId: "boss_dragon",
            maxHealth: 10000000,
            currentHealth: 10000000,
            isActive: true,
            startedAt: admin.firestore.Timestamp.now(),
            topAttackers: {}
        };
        await bossRef.set(defaultBoss);
        console.log("Initialized first world boss.");
        return null;
    }
    const bossData = bossDoc.data();
    const now = admin.firestore.Timestamp.now().toMillis();
    const startedAt = bossData.startedAt ? bossData.startedAt.toMillis() : now;
    const isOld = (now - startedAt) > 7 * 24 * 60 * 60 * 1000; // 7 days
    if (!bossData.isActive || bossData.currentHealth <= 0 || isOld) {
        if (bossData.currentHealth <= 0) {
            // Distribute rewards to top attackers
            const topAttackers = bossData.topAttackers || {};
            const batch = db.batch();
            // Limit to top 100 to avoid batch size limits
            const sortedAttackers = Object.entries(topAttackers)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 100);
            sortedAttackers.forEach(([uid, damage], index) => {
                const userRef = db.collection("users").doc(uid);
                let rewardGold = 0;
                let rewardXP = 0;
                if (index === 0) {
                    rewardGold = 5000;
                    rewardXP = 10000;
                }
                else if (index < 10) {
                    rewardGold = 2000;
                    rewardXP = 5000;
                }
                else if (index < 50) {
                    rewardGold = 500;
                    rewardXP = 1500;
                }
                else {
                    rewardGold = 100;
                    rewardXP = 500;
                }
                batch.update(userRef, {
                    gold: admin.firestore.FieldValue.increment(rewardGold),
                    xp: admin.firestore.FieldValue.increment(rewardXP)
                });
            });
            if (sortedAttackers.length > 0) {
                await batch.commit();
                console.log(`Distributed rewards to ${sortedAttackers.length} players for defeating world boss.`);
            }
        }
        // Spawn new boss
        const templates = [
            { id: "boss_goblin", health: 5000000 },
            { id: "boss_orc", health: 15000000 },
            { id: "boss_dragon", health: 30000000 }
        ];
        const randomTemplate = templates[Math.floor(Math.random() * templates.length)];
        const newBoss = {
            id: "current",
            bossTemplateId: randomTemplate.id,
            maxHealth: randomTemplate.health,
            currentHealth: randomTemplate.health,
            isActive: true,
            startedAt: admin.firestore.Timestamp.now(),
            topAttackers: {}
        };
        await bossRef.set(newBoss);
        console.log(`Spawned new world boss: ${randomTemplate.id}`);
    }
    return null;
});
// -------------------------------------------------------------------
// 5. HTTP Callable: Send Friend Request
// -------------------------------------------------------------------
exports.sendFriendRequest = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const myUid = context.auth.uid;
    const targetUid = data.targetUid;
    if (!targetUid || myUid === targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid target user.");
    }
    const targetRef = db.collection("users").doc(targetUid);
    let sentRequest = false;
    await db.runTransaction(async (transaction) => {
        const targetDoc = await transaction.get(targetRef);
        if (!targetDoc.exists)
            throw new functions.https.HttpsError("not-found", "Target not found.");
        const targetData = targetDoc.data();
        if (!targetData)
            return;
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
        const myName = ((_a = myDoc.data()) === null || _a === void 0 ? void 0 : _a.name) || "Someone";
        await sendPushNotification(targetUid, "Friend Request", `${myName} sent you a friend request!`);
    }
    return { success: true };
});
// -------------------------------------------------------------------
// 6. HTTP Callable: Accept Friend Request
// -------------------------------------------------------------------
exports.acceptFriendRequest = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
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
        if (!myDoc.exists || !senderDoc.exists)
            return;
        const myData = myDoc.data() || {};
        const senderData = senderDoc.data() || {};
        const myRequests = myData.friendRequests || [];
        const myFriends = myData.friends || [];
        const senderFriends = senderData.friends || [];
        // Remove from my requests
        const requestIndex = myRequests.indexOf(senderUid);
        if (requestIndex > -1) {
            myRequests.splice(requestIndex, 1);
        }
        // Add to my friends
        if (!myFriends.includes(senderUid)) {
            myFriends.push(senderUid);
        }
        // Add to sender's friends
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
        const myName = ((_a = myDoc.data()) === null || _a === void 0 ? void 0 : _a.name) || "Someone";
        await sendPushNotification(senderUid, "Friend Request Accepted", `${myName} accepted your request!`);
    }
    return { success: true };
});
// -------------------------------------------------------------------
// 7. HTTP Callable: Join Team
// -------------------------------------------------------------------
exports.joinTeam = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const ticketId = data.ticketId;
    const guests = data.guests || [];
    if (!ticketId || !Array.isArray(guests)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
    }
    const ref = db.collection("matchmaking").doc(ticketId);
    let success = false;
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists)
            return;
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingTeammates")
            return;
        const currentTeam = ticket.team || [];
        if (currentTeam.length + guests.length > 3)
            return;
        currentTeam.push(...guests);
        const updates = { team: currentTeam };
        if (currentTeam.length === 3) {
            updates.status = "searchingOpponent";
        }
        transaction.update(ref, updates);
        success = true;
    });
    return { success: success };
});
// -------------------------------------------------------------------
// 8. HTTP Callable: Match With Opponent
// -------------------------------------------------------------------
const crypto_1 = require("crypto");
exports.matchWithOpponent = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const opponentTicketId = data.opponentTicketId;
    // opponent and myTeam are passed by client but we don't need them on the server side for this atomic update
    if (!opponentTicketId) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid opponent.");
    }
    const opponentRef = db.collection("matchmaking").doc(opponentTicketId);
    const newBattleId = (0, crypto_1.randomUUID)();
    let success = false;
    let actualOpponentData = null;
    await db.runTransaction(async (transaction) => {
        const opDoc = await transaction.get(opponentRef);
        if (!opDoc.exists)
            return;
        const currentOpp = opDoc.data();
        if (!currentOpp || currentOpp.status !== "searchingOpponent")
            return;
        actualOpponentData = currentOpp;
        transaction.update(opponentRef, {
            status: "matched",
            battleId: newBattleId
        });
        success = true;
    });
    return { success: success, battleId: newBattleId, opponentData: actualOpponentData };
});
// -------------------------------------------------------------------
// 9. HTTP Callable: Equip Item
// -------------------------------------------------------------------
exports.equipItem = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const itemId = data.itemId;
    const slot = data.slot; // "Weapon" or "Armor"
    if (!itemId || !slot) {
        throw new functions.https.HttpsError("invalid-argument", "Missing itemId or slot.");
    }
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists)
            throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data();
        if (!userData)
            return;
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
        const updates = {};
        if (slot.toLowerCase() === "weapon") {
            updates.equippedWeaponId = itemId;
        }
        else if (slot.toLowerCase() === "armor") {
            updates.equippedArmorId = itemId;
        }
        else if (slot.toLowerCase() === "ring") {
            updates.equippedRingId = itemId;
        }
        else if (slot.toLowerCase() === "amulet") {
            updates.equippedAmuletId = itemId;
        }
        transaction.update(userRef, updates);
    });
    return { success: true };
});
// -------------------------------------------------------------------
// 10. HTTP Callable: Resolve PvE Battle
// -------------------------------------------------------------------
exports.resolvePvEBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const won = data.won;
    const bossLootChance = data.bossLootChance || 0.2; // default 20%
    const bossXp = data.xp || 0;
    const bossGold = data.gold || 0;
    const userRef = db.collection("users").doc(uid);
    let droppedItemId = null;
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists)
            throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data();
        if (!userData)
            return;
        const updates = {};
        // Grant Rewards
        if (won) {
            updates.gold = (userData.gold || 0) + bossGold;
            // Level up logic per class
            const selectedClass = userData.selectedClass || "Archer";
            const progressions = userData.progressions || {};
            let classProg = progressions[selectedClass] || { level: 1, xp: 0, totalReps: 0, storyStage: 1 };
            classProg.xp += bossXp;
            let leveledUp = false;
            let earnedStatPoints = 0;
            while (classProg.xp >= classProg.level * 150) {
                classProg.xp -= classProg.level * 150;
                classProg.level += 1;
                earnedStatPoints += 3;
                leveledUp = true;
            }
            progressions[selectedClass] = classProg;
            updates.progressions = progressions;
            if (leveledUp) {
                updates.statPoints = (userData.statPoints || 0) + earnedStatPoints;
                updates.maxEnergy = (userData.maxEnergy || 100) + (earnedStatPoints / 3) * 5;
                updates.energy = updates.maxEnergy; // Restore energy on level up
                updates.basePower = (userData.basePower || 100) + (earnedStatPoints / 3) * 15;
            }
            // Loot Drop
            if (Math.random() <= bossLootChance) {
                // Simplified loot table based on available shop IDs
                const possibleLoot = [
                    "arm_com_1", "arm_com_2", "arm_com_3", "arm_com_4", "arm_com_5", "arm_com_6", "arm_com_7", "arm_com_8",
                    "arm_rar_1", "arm_rar_2", "arm_rar_3", "arm_rar_4", "arm_rar_5", "arm_rar_6", "arm_rar_7", "arm_rar_8",
                    "arm_epi_1", "arm_epi_2", "arm_epi_3", "arm_epi_4", "arm_epi_5", "arm_epi_6", "arm_epi_7", "arm_epi_8",
                    "arm_leg_1", "arm_leg_2", "arm_leg_3", "arm_leg_4", "arm_leg_5", "arm_leg_6",
                    "arm_myt_1", "arm_myt_2", "arm_myt_3", "arm_myt_4", "arm_myt_5",
                    // Rings
                    "rng_com_1", "rng_rar_1", "rng_epi_1", "rng_leg_1", "rng_myt_1",
                    // Amulets
                    "amu_com_1", "amu_rar_1", "amu_epi_1", "amu_leg_1", "amu_myt_1"
                ];
                // Roll rarity: 60% Common, 25% Rare, 10% Epic, 4% Legendary, 1% Mythical
                const roll = Math.random();
                let rarityFilter = "com";
                if (roll > 0.6 && roll <= 0.85)
                    rarityFilter = "rar";
                else if (roll > 0.85 && roll <= 0.95)
                    rarityFilter = "epi";
                else if (roll > 0.95 && roll <= 0.99)
                    rarityFilter = "leg";
                else if (roll > 0.99)
                    rarityFilter = "myt";
                const filteredLoot = possibleLoot.filter(id => id.includes(rarityFilter));
                if (filteredLoot.length > 0) {
                    droppedItemId = filteredLoot[Math.floor(Math.random() * filteredLoot.length)];
                    const ownedIds = userData.ownedEquipmentIds || [];
                    if (!ownedIds.includes(droppedItemId)) {
                        ownedIds.push(droppedItemId);
                        updates.ownedEquipmentIds = ownedIds;
                    }
                }
            }
        }
        transaction.update(userRef, updates);
    });
    return { success: true, droppedItemId: droppedItemId };
});
// -------------------------------------------------------------------
// 12. Firestore Trigger: On Matchmaking Ticket Created
// -------------------------------------------------------------------
exports.onMatchmakingTicketCreated = functions.firestore
    .document('matchmaking/{ticketId}')
    .onCreate(async (snap, context) => {
    var _a;
    const ticket = snap.data();
    if (ticket.status === "waitingForFriend" && ticket.targetUid && ticket.uid) {
        const senderDoc = await db.collection("users").doc(ticket.uid).get();
        const senderName = ((_a = senderDoc.data()) === null || _a === void 0 ? void 0 : _a.name) || "A friend";
        await sendPushNotification(ticket.targetUid, "Duel Request! ⚔️", `${senderName} challenged you to a duel! Open the app to accept.`);
    }
    else if (ticket.teamType === "team3v3" && ticket.status === "searchingTeammates" && ticket.uid) {
        const senderDoc = await db.collection("users").doc(ticket.uid).get();
        const userData = senderDoc.data();
        const senderName = (userData === null || userData === void 0 ? void 0 : userData.name) || "A clanmate";
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
exports.fillTeammatesWithBots = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const ticketId = data.ticketId;
    if (!ticketId)
        throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");
    const ref = db.collection("matchmaking").doc(ticketId);
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists)
            return;
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingTeammates")
            return;
        const team = ticket.team || [];
        const bots = ["HealerBot", "TankBot", "MageBot"];
        let botIdx = 0;
        while (team.length < 3) {
            const botClass = team.length === 1 ? "healer" : "mage";
            team.push({
                id: `bot_${admin.firestore.Timestamp.now().toMillis()}_${botIdx}`,
                name: bots[botIdx % bots.length] || "Bot",
                characterClass: botClass,
                health: 110,
                maxHealth: 110,
                avatarName: `avatar_${botClass}`,
                reps: 0
            });
            botIdx++;
        }
        transaction.update(ref, {
            team: team,
            status: "searchingOpponent"
        });
    });
    return { success: true };
});
// -------------------------------------------------------------------
// 14. HTTP Callable: Trigger Opponent Bot Fallback
// -------------------------------------------------------------------
exports.triggerOpponentBotFallback = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const ticketId = data.ticketId;
    const type = data.type || "duel1v1";
    if (!ticketId)
        throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");
    const ref = db.collection("matchmaking").doc(ticketId);
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists)
            return;
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingOpponent")
            return;
        const battleId = (0, crypto_1.randomUUID)();
        const opponentTeam = [];
        if (type === "team3v3") {
            const bots = ["ShadowFiend", "DoomBringer", "NightStalker"];
            const classes = ["swordsman", "mage", "archer"];
            for (let i = 0; i < 3; i++) {
                const health = 110 + (i * 10);
                opponentTeam.push({
                    id: `bot_${admin.firestore.Timestamp.now().toMillis()}_${i}`,
                    name: bots[i],
                    characterClass: classes[i],
                    health: health,
                    maxHealth: health,
                    avatarName: `avatar_${classes[i]}`,
                    reps: 0
                });
            }
        }
        else {
            const myCharLevel = ticket.team && ticket.team.length > 0 ? ticket.team[0].maxHealth : 100;
            opponentTeam.push({
                id: `bot_${admin.firestore.Timestamp.now().toMillis()}`,
                name: "Shadow Warrior",
                characterClass: "swordsman",
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
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            combatLog: []
        };
        const battleRef = db.collection("battles").doc(battleId);
        transaction.set(battleRef, newBattle);
        transaction.update(ref, {
            status: "matched",
            battleId: battleId
        });
    });
    return { success: true };
});
//# sourceMappingURL=index.js.map