import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import type { UserRecord } from "firebase-admin/auth";
import { randomBytes } from "node:crypto";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

type Notice = { title: string; body: string; type: string };

async function notifyUser(uid: string, notice: Notice): Promise<void> {
  await db.collection("notifications").doc(uid).collection("items").add({
    ...notice,
    createdAt: Timestamp.now(),
    readAt: null,
  });
  const devices = await db.collection("users").doc(uid).collection("devices").get();
  const tokens = [...new Set(devices.docs.map((doc) => doc.get("token")).filter((token): token is string => typeof token === "string" && token.length > 20))];
  // FCM accepts at most 500 registration tokens in one multicast request.
  for (let offset = 0; offset < tokens.length; offset += 500) {
    const batch = tokens.slice(offset, offset + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: batch,
      notification: { title: notice.title, body: notice.body },
      data: { type: notice.type },
      android: { priority: "high" },
    });
    const stale = response.responses.flatMap((result, index) => {
      const code = result.error?.code;
      return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token"
        ? [batch[index]]
        : [];
    });
    if (stale.length > 0) {
      const staleSet = new Set(stale);
      const staleDocs = devices.docs.filter((doc) => staleSet.has(String(doc.get("token"))));
      await Promise.all(staleDocs.map((doc) => doc.ref.delete()));
    }
  }
}

async function notifyAdmins(notice: Notice): Promise<void> {
  const admins = await db.collection("admins").where("enabled", "==", true).get();
  await Promise.all(admins.docs.map((admin) => notifyUser(admin.id, notice)));
}

async function notifyTopic(topic: string, notice: Notice): Promise<void> {
  await messaging.send({
    topic,
    notification: { title: notice.title, body: notice.body },
    data: { type: notice.type },
    android: { priority: "normal" },
  });
}

export const notifyAdminOnNewProfile = onDocumentCreated({ document: "users/{uid}", region: "asia-south1" }, async (event) => {
  const name = String(event.data?.get("displayName") ?? "Новый пользователь").slice(0, 80);
  const role = String(event.data?.get("role") ?? "пользователь");
  await Promise.all([
    notifyAdmins({ title: "Новая регистрация USTA.KZ", body: `${name} · ${role}`, type: "new_user" }),
    notifyTopic("usta_all", {
      title: "Новый участник USTA.KZ",
      body: "К сообществу USTA.KZ присоединился новый пользователь.",
      type: "new_user",
    }),
  ]);
});

export const notifyUsersOnNewJob = onDocumentCreated({ document: "jobs/{jobId}", region: "asia-south1" }, async (event) => {
  const data = event.data?.data();
  if (!data || data.status !== "published") return;
  const title = String(data.title ?? "Новый заказ").slice(0, 70);
  const city = String(data.city ?? "Казахстан").slice(0, 80);
  await messaging.send({
    topic: "usta_all",
    notification: { title: `Новый заказ · ${city}`, body: title },
    data: { type: "new_job", jobId: event.params.jobId },
    android: { priority: "normal" },
  });
});

export const notifyConversationRecipient = onDocumentCreated({ document: "conversations/{conversationId}/messages/{messageId}", region: "asia-south1" }, async (event) => {
  const message = event.data?.data();
  if (!message) return;
  const conversation = await db.collection("conversations").doc(event.params.conversationId).get();
  const participants = conversation.get("participants") as unknown;
  if (!Array.isArray(participants)) return;
  const senderId = String(message.senderId ?? "");
  const recipientIds = participants.filter((uid): uid is string => typeof uid === "string" && uid !== senderId);
  const body = String(message.text ?? "Новое сообщение").slice(0, 120);
  await Promise.all(recipientIds.map((uid) => notifyUser(uid, { title: "Новое сообщение USTA.KZ", body, type: "new_message" })));
});

export const notifyAdminOnServiceRequest = onDocumentCreated({ document: "serviceRequests/{requestId}", region: "asia-south1" }, async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const title = data.type === "business" ? "Заявка USTA Business" : "Заявка на рекламу";
  await notifyAdmins({ title, body: `Новая заявка от ${String(data.phone ?? "пользователя")}`, type: "service_request" });
});

export const notifyOwnerOnRequestStatus = onDocumentUpdated({ document: "serviceRequests/{requestId}", region: "asia-south1" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  const uid = String(after.ownerUid ?? "");
  if (!uid) return;
  const statusLabels: Record<string, string> = {
    in_progress: "В работе",
    done: "Обработана",
    rejected: "Отклонена",
    new: "Новая",
  };
  await notifyUser(uid, {
    title: "Статус вашей заявки изменился",
    body: `Заявка: ${statusLabels[String(after.status)] ?? "Обновлена"}`,
    type: "service_request_status",
  });
});


/**
 * Owner-only manager invitations. Managers can process service requests but cannot
 * invite users or change access. Email/password authentication and email verification
 * remain enforced by the separate administrator app.
 */
export const manageAdminAccess = onCall({ region: "asia-south1" }, async (request) => {
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "Only the USTA owner can manage admin access.");
  }

  const action = String(request.data?.action ?? "");
  const auth = getAuth();

  if (action === "list") {
    const snapshot = await db.collection("admins").where("role", "==", "manager").get();
    return {
      managers: snapshot.docs
        .filter((doc) => doc.get("enabled") === true)
        .map((doc) => ({ uid: doc.id, email: String(doc.get("email") ?? "") })),
    };
  }

  if (action === "invite") {
    const email = String(request.data?.email ?? "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }

    let user: UserRecord;
    let created = false;
    try {
      user = await auth.getUserByEmail(email);
    } catch (error) {
      if ((error as { code?: string }).code !== "auth/user-not-found") throw error;
      user = await auth.createUser({
        email,
        emailVerified: false,
        password: randomBytes(32).toString("base64url"),
        disabled: false,
      });
      created = true;
    }

    if (user.customClaims?.admin === true) {
      throw new HttpsError("already-exists", "This account already has full administrator access.");
    }

    await auth.setCustomUserClaims(user.uid, { ...user.customClaims, manager: true });
    await db.collection("admins").doc(user.uid).set({
      email,
      role: "manager",
      enabled: true,
      updatedAt: Timestamp.now(),
    }, { merge: true });

    return { uid: user.uid, email, created };
  }

  if (action === "revoke") {
    const uid = String(request.data?.uid ?? "").trim();
    if (!uid || uid.length > 128) {
      throw new HttpsError("invalid-argument", "A valid user id is required.");
    }
    const user = await auth.getUser(uid);
    if (user.customClaims?.admin === true) {
      throw new HttpsError("failed-precondition", "Full administrator access cannot be revoked as manager access.");
    }
    const claims = { ...user.customClaims };
    delete claims.manager;
    await auth.setCustomUserClaims(uid, claims);
    await db.collection("admins").doc(uid).set({
      enabled: false,
      role: "manager",
      updatedAt: Timestamp.now(),
    }, { merge: true });
    await auth.revokeRefreshTokens(uid);
    return { uid, revoked: true };
  }

  throw new HttpsError("invalid-argument", "Unknown manager access action.");
});
