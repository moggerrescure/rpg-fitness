const fs = require('fs');
let code = fs.readFileSync('functions/src/index.ts', 'utf8');

code = code.replace(
    /if \(oppClan && oppClan\.members\)/g,
    "if (oppClan && oppClan.members)"
);

code = code.replace(
    /const oppClan = oppClanDoc\.data\(\);/g,
    "const oppClan = oppClanDoc.data() || {};"
);

fs.writeFileSync('functions/src/index.ts', code);
console.log("Fixed undefined oppClan");
