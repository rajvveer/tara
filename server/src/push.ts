import { readFileSync } from "node:fs";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import type { Prisma } from "@prisma/client";
import { config } from "./config.js";
import { prisma } from "./db.js";

function messaging() {
  const credentials = config.FIREBASE_SERVICE_ACCOUNT_JSON
    || (config.FIREBASE_SERVICE_ACCOUNT_FILE ? readFileSync(config.FIREBASE_SERVICE_ACCOUNT_FILE, "utf8") : "");
  if (!credentials) return null;
  if (!getApps().length) {
    const account = JSON.parse(credentials) as Record<string, string>;
    if (account.private_key) account.private_key = account.private_key.replace(/\\n/g, "\n");
    initializeApp({ credential: cert(account) });
  }
  return getMessaging();
}

function stringData(data: Prisma.JsonValue | null) {
  if (!data || Array.isArray(data) || typeof data !== "object") return undefined;
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, typeof value === "string" ? value : JSON.stringify(value)]));
}

export async function dispatchDueNotifications(now = new Date()) {
  const client = messaging();
  if (!client) return 0;
  const notifications = await prisma.notification.findMany({
    where: { sentAt: null, scheduledAt: { lte: now }, user: { notificationPrefs: { is: { pushEnabled: true } } } },
    include: { user: { select: { pushDevices: { where: { enabled: true }, select: { token: true } } } } },
    orderBy: { scheduledAt: "asc" },
    take: 100,
  });
  let sent = 0;
  for (const notification of notifications) {
    const tokens = notification.user.pushDevices.map((device) => device.token);
    if (!tokens.length) continue;
    const result = await client.sendEachForMulticast({
      tokens,
      notification: { title: notification.title, body: notification.body },
      data: { notificationId: notification.id, type: notification.type, ...stringData(notification.data) },
    });
    const invalid = result.responses.flatMap((item, index) => {
      const code = item.error?.code ?? "";
      return code.includes("registration-token-not-registered") || code.includes("invalid-registration-token") ? [tokens[index]!] : [];
    });
    if (invalid.length) await prisma.pushDevice.updateMany({ where: { token: { in: invalid } }, data: { enabled: false } });
    if (result.successCount > 0) {
      await prisma.notification.update({ where: { id: notification.id }, data: { sentAt: now } });
      sent++;
    }
  }
  return sent;
}
