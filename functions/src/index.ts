import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

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
  if (tokens.length > 0) {
    await messaging.sendEachForMulticast({
      tokens,
      notification: { title: notice.title, body: notice.body },
      data: { type: notice.type },
      android: { priority: "high" },
    });
  }
}

async function notifyAdmins(notice: Notice): Promise<void> {
  const admins = await db.collection("admins").where("enabled", "==", true).get();
  await Promise.all(admins.docs.map((admin) => notifyUser(admin.id, notice)));
}

export const notifyAdminOnNewProfile = onDocumentCreated({ document: "users/{uid}", region: "asia-south1" }, async (event) => {
  const name = String(event.data?.get("displayName") ?? "Новый пользователь").slice(0, 80);
  const role = String(event.data?.get("role") ?? "пользователь");
  await notifyAdmins({ title: "Новая регистрация USTA.KZ", body: `${name} · ${role}`, type: "new_user" });
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
