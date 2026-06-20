const fs = require('fs');
let code = fs.readFileSync('functions/src/index.ts', 'utf8');

const target = `
    // Use a transaction to safely update member score and total clan score
    return await db.runTransaction(async (transaction) => {
        const clanDoc = await transaction.get(clanRef);`;
const replace = `
    // Use a transaction to safely update member score and total clan score
    const result = await db.runTransaction(async (transaction) => {
        const clanDoc = await transaction.get(clanRef);`;
code = code.replace(target, replace);

fs.writeFileSync('functions/src/index.ts', code);
console.log("Fixed result");
