const fs = require('fs');
let code = fs.readFileSync('functions/src/index.ts', 'utf8');

// 1. Add opponent clan push to recordClanWarAttack
const recordAttackTarget = `
        return { success: true, scoreAdded: scoreToAdd };
    });
});`;
const recordAttackReplace = `
        return { success: true, scoreAdded: scoreToAdd, opponentClanId: clanData.activeWar?.opponentClanId, myName: userData.name || "A rival" };
    });

    if (result.success && result.opponentClanId && !result.opponentClanId.startsWith("bot_")) {
        const oppClanDoc = await db.collection("clans").doc(result.opponentClanId).get();
        if (oppClanDoc.exists) {
            const oppClan = oppClanDoc.data();
            if (oppClan && oppClan.members) {
                for (const member of oppClan.members) {
                    if (member.id) {
                        await sendPushNotification(member.id, "Clan Under Attack! 🚨", \`\${result.myName} just scored points against your clan!\`);
                    }
                }
            }
        }
    }

    return { success: result.success, scoreAdded: result.scoreAdded };
});`;
code = code.replace(recordAttackTarget, recordAttackReplace);

// 2. Add 3v3 invite push to onMatchmakingTicketCreated
const onMatchTarget = `
        if (ticket.status === "waitingForFriend" && ticket.targetUid && ticket.uid) {
            const senderDoc = await db.collection("users").doc(ticket.uid).get();
            const senderName = senderDoc.data()?.name || "A friend";
            
            await sendPushNotification(
                ticket.targetUid, 
                "Duel Request! ⚔️", 
                \`\${senderName} challenged you to a duel! Open the app to accept.\`
            );
        }
        return null;`;
const onMatchReplace = `
        if (ticket.status === "waitingForFriend" && ticket.targetUid && ticket.uid) {
            const senderDoc = await db.collection("users").doc(ticket.uid).get();
            const senderName = senderDoc.data()?.name || "A friend";
            
            await sendPushNotification(
                ticket.targetUid, 
                "Duel Request! ⚔️", 
                \`\${senderName} challenged you to a duel! Open the app to accept.\`
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
                                await sendPushNotification(member.id, "3v3 Team Up! 🛡️", \`\${senderName} is looking for teammates for 3v3 Arena!\`);
                            }
                        }
                    }
                }
            }
        }
        return null;`;
code = code.replace(onMatchTarget, onMatchReplace);

fs.writeFileSync('functions/src/index.ts', code);
console.log("Updated index.ts");
