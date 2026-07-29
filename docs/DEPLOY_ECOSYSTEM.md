# FitRPG Deploy Checklist

Short checklist before deploying Firebase changes.

## Cloud Functions

- **Never deploy functions without shared exports present.** After stash merges, verify `functions/src/index.ts` still exports everything the client calls (`vertexProxy`, social, clan war, economy callables, etc.). A partial deploy can drop live endpoints.
- **Prefer targeted deploys:** `firebase deploy --only functions:matchmakeClanWar,functions:declineFriendRequest` instead of redeploying the whole bundle when only a few functions changed.
- **Test with the emulator when possible:** `firebase emulators:start --only functions,firestore` and point the iOS app or integration scripts at the emulator host before production deploy.

## Firestore Rules

- **Never deploy rules without merging `yoga_*` from the Yoga1 branch.** Rule sets diverge easily; a deploy from main alone can break yoga collections or leave them unprotected.
- Diff rules against Yoga1 before any rules deploy.

## General

- Do not run full ecosystem deploys from a dirty worktree without reviewing `git diff functions/` and `firestore.rules`.
- After deploy, smoke-test: friends (accept/decline), clan war start/score, equip item, world boss read path.
