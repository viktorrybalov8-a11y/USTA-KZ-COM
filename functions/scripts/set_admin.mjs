import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const [action, uid] = process.argv.slice(2);
if (!['grant', 'revoke'].includes(action) || !uid) {
  console.error('Usage: node scripts/set_admin.mjs <grant|revoke> <firebase-user-uid>');
  process.exit(2);
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const firestore = getFirestore();
const user = await auth.getUser(uid);
const claims = { ...user.customClaims };

if (action === 'grant') {
  claims.admin = true;
  await auth.setCustomUserClaims(uid, claims);
  await firestore.collection('admins').doc(uid).set({ enabled: true }, { merge: true });
} else {
  delete claims.admin;
  await auth.setCustomUserClaims(uid, claims);
  await firestore.collection('admins').doc(uid).delete();
}

console.log(`Admin access ${action === 'grant' ? 'granted to' : 'revoked from'} ${uid}. The user must sign in again to refresh the token.`);
