import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { onRequest as onRequestV2, onCall as onCallV2, HttpsError as HttpsErrorV2 } from "firebase-functions/v2/https";
import { onDocumentCreated as onDocCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";

admin.initializeApp();
const db = admin.firestore();

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
export const matchmakeClanWar = functions.https.onCall(async (data, context) => {
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
        
        // Prevent starting if already searching or in war
        if (myClanData.activeWar && myClanData.activeWar.phase !== "none") {
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
        } else {
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
export const processClanWarPhases = functions.pubsub.schedule("*/5 * * * *").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

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
export const recordClanWarAttack = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const uid = context.auth.uid;
    const won = data.won as boolean;
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
        const clanDoc = await transaction.get(clanRef);
        if (!clanDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Clan not found.");
        }

        const clanData = clanDoc.data()!;
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
        const memberIndex = members.findIndex((m: any) => m.id === uid);
        if (memberIndex !== -1) {
            members[memberIndex].warAttacksUsed = (members[memberIndex].warAttacksUsed || 0) + 1;
            if (won) {
                members[memberIndex].warScoreContributed = (members[memberIndex].warScoreContributed || 0) + scoreToAdd;
            }
            transaction.update(clanRef, { members: members });
        }

        return { success: true, scoreAdded: scoreToAdd, opponentClanId: clanData.activeWar?.opponentClanId, myName: userData.name || "A rival" };
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
export const attackWorldBoss = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    
    const uid = context.auth.uid;
    const damage = data.damage;
    
    // Anti-cheat limit: Max 5000 damage per call (covers a full 60s raid session)
    if (typeof damage !== "number" || damage <= 0 || damage > 5000) {
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
        
        const updates: any = {
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
export const processWorldBossCycle = functions.pubsub.schedule("0 * * * *").onRun(async (context) => {
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

    const bossData = bossDoc.data()!;
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
                .sort((a: any, b: any) => b[1] - a[1])
                .slice(0, 100);

            sortedAttackers.forEach(([uid, damage], index) => {
                const userRef = db.collection("users").doc(uid);
                let rewardGold = 0;
                let rewardXP = 0;
                
                if (index === 0) { rewardGold = 5000; rewardXP = 10000; }
                else if (index < 10) { rewardGold = 2000; rewardXP = 5000; }
                else if (index < 50) { rewardGold = 500; rewardXP = 1500; }
                else { rewardGold = 100; rewardXP = 500; }

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
export const sendFriendRequest = functions.https.onCall(async (data, context) => {
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
export const searchPlayers = functions.https.onCall(async (data, context) => {
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
export const inviteToTeam3v3 = functions.https.onCall(async (data, context) => {
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
export const acceptFriendRequest = functions.https.onCall(async (data, context) => {
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
        
        if (!myDoc.exists || !senderDoc.exists) return;
        
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
        const myName = myDoc.data()?.name || "Someone";
        await sendPushNotification(senderUid, "Friend Request Accepted", `${myName} accepted your request!`);
    }
    
    return { success: true };
});

// -------------------------------------------------------------------
// 6b. HTTP Callable: Decline Friend Request
// -------------------------------------------------------------------
export const declineFriendRequest = functions.https.onCall(async (data, context) => {
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
// 7. HTTP Callable: Join Team
// -------------------------------------------------------------------
export const joinTeam = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const ticketId = data.ticketId;
    const guests = data.guests || [];
    
    if (!ticketId || !Array.isArray(guests)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
    }

    const ref = db.collection("matchmaking").doc(ticketId);
    
    let success = false;
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingTeammates") return;
        
        const currentTeam = ticket.team || [];
        if (currentTeam.length + guests.length > 3) return;
        
        currentTeam.push(...guests);
        
        const updates: any = { team: currentTeam };
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
import { randomUUID } from "crypto";

export const matchWithOpponent = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const opponentTicketId = data.opponentTicketId;
    // opponent and myTeam are passed by client but we don't need them on the server side for this atomic update
    
    if (!opponentTicketId) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid opponent.");
    }

    const opponentRef = db.collection("matchmaking").doc(opponentTicketId);
    const newBattleId = randomUUID();
    
    let success = false;
    let actualOpponentData: any = null;
    await db.runTransaction(async (transaction) => {
        const opDoc = await transaction.get(opponentRef);
        if (!opDoc.exists) return;
        
        const currentOpp = opDoc.data();
        if (!currentOpp || currentOpp.status !== "searchingOpponent") return;
        
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
export const equipItem = functions.https.onCall(async (data, context) => {
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
export const resolvePvEBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const won = data.won;
    const bossLootChance = data.bossLootChance || 0.2; // default 20%
    const bossXp = data.xp || 0;
    const bossGold = data.gold || 0;
    
    const userRef = db.collection("users").doc(uid);
    let droppedItemId: string | null = null;
    
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        const userData = userDoc.data();
        if (!userData) return;
        
        const updates: any = {};
        
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
                if (roll > 0.6 && roll <= 0.85) rarityFilter = "rar";
                else if (roll > 0.85 && roll <= 0.95) rarityFilter = "epi";
                else if (roll > 0.95 && roll <= 0.99) rarityFilter = "leg";
                else if (roll > 0.99) rarityFilter = "myt";
                
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
export const fillTeammatesWithBots = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const ticketId = data.ticketId;
    if (!ticketId) throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");

    const ref = db.collection("matchmaking").doc(ticketId);
    
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingTeammates") return;
        
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
    });
    
    return { success: true };
});

// -------------------------------------------------------------------
// 14. HTTP Callable: Trigger Opponent Bot Fallback
// -------------------------------------------------------------------

export const triggerOpponentBotFallback = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const ticketId = data.ticketId;
    const type = data.type || "duel1v1";
    if (!ticketId) throw new functions.https.HttpsError("invalid-argument", "Missing ticketId.");

    const ref = db.collection("matchmaking").doc(ticketId);
    
    let finalBattleId = "";
    const finalBattleData = await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(ref);
        if (!doc.exists) return;
        
        const ticket = doc.data();
        if (!ticket || ticket.status !== "searchingOpponent") return;
        
        const battleId = randomUUID();
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
        transaction.set(battleRef, { ...newBattle, createdAt: admin.firestore.FieldValue.serverTimestamp() });
        
        transaction.update(ref, {
            status: "matched",
            battleId: battleId
        });
        
        return { ...newBattle, createdAt: new Date() };
    });
    
    return { success: true, battleId: finalBattleId, battleData: finalBattleData };
});

// -------------------------------------------------------------------
// 15. HTTP Callable: Get Leaderboards
// -------------------------------------------------------------------
export const getLeaderboards = functions.https.onCall(async (data, context) => {
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

// ── 3. deleteAccount ────────────────────────────────────────────────────────
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
