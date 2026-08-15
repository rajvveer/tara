import { randomUUID } from "node:crypto";
import { createRequire } from "node:module";
import express from "express";
import cors from "cors";
import { rateLimit } from "express-rate-limit";
import swaggerUi from "swagger-ui-express";
import { config } from "./config.js";
import { prisma } from "./db.js";
import { ApiError, errorHandler, notFound } from "./errors.js";
import { openapi } from "./openapi.js";
import router from "./routes.js";

const helmet = createRequire(import.meta.url)("helmet") as (options?: object) => express.RequestHandler;

export const app = express();

app.disable("x-powered-by");
app.set("trust proxy", 1);
app.use((request, response, next) => {
  request.id = request.get("x-request-id")?.slice(0, 100) ?? randomUUID();
  response.setHeader("x-request-id", request.id);
  next();
});
app.use(helmet({ contentSecurityPolicy: config.NODE_ENV === "production" ? undefined : false }));
app.use(cors({
  origin(origin, callback) {
    if (!origin || config.corsOrigins.includes("*") || config.corsOrigins.includes(origin)) callback(null, true);
    else callback(new ApiError(403, "ORIGIN_NOT_ALLOWED", "This origin is not allowed."));
  },
  allowedHeaders: ["Authorization", "Content-Type", "X-Request-Id"],
  methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
}));
// Voice turns contain up to 25 seconds of base64 PCM audio. All other JSON stays small.
app.use("/api/v1/voice/onboarding/turn", express.json({ limit: "1400kb" }));
app.use(express.json({ limit: "100kb" }));

app.get("/health", async (_request, response) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    response.json({ data: { status: "ok", database: "connected", timestamp: new Date().toISOString() } });
  } catch {
    response.status(503).json({ data: { status: "degraded", database: "unavailable", timestamp: new Date().toISOString() } });
  }
});
app.get("/api/openapi.json", (_request, response) => response.json(openapi));
app.use("/api/docs", swaggerUi.serve, swaggerUi.setup(openapi, { customSiteTitle: "GoalSpring API" }));

app.use("/api/v1/auth", rateLimit({ windowMs: 15 * 60_000, limit: 100, standardHeaders: "draft-8", legacyHeaders: false }));
app.use("/api/v1/voice", rateLimit({ windowMs: 60_000, limit: 15, standardHeaders: "draft-8", legacyHeaders: false }));
app.use("/api/v1", router);
app.use(notFound);
app.use(errorHandler);
