const fs = require('fs');
const data = JSON.parse(fs.readFileSync('firebase.json', 'utf8'));
if (data.firestore) {
  data.firestore.indexes = "firestore.indexes.json";
} else {
  data.firestore = { rules: "firestore.rules", indexes: "firestore.indexes.json" };
}
fs.writeFileSync('firebase.json', JSON.stringify(data, null, 2));
