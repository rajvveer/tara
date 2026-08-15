import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ findUnique: vi.fn(), executeTool: vi.fn() }));

vi.mock("../src/config.js", () => ({
  config: { GROQ_API_KEY: "test-groq-key" },
}));
vi.mock("../src/db.js", () => ({
  prisma: { user: { findUnique: mocks.findUnique } },
}));
vi.mock("../src/coach-tools.js", () => ({
  coachTools: [{
    type: "function",
    function: {
      name: "update_task",
      description: "Update a task",
      parameters: { type: "object", properties: {} },
    },
  }],
  executeCoachTool: mocks.executeTool,
}));

import { chatTurnSchema, streamCoachReply } from "../src/chat.js";

const accountContext = {
  name: "Mira Patel",
  mainObjective: "Run a first 5K",
  timezone: "Asia/Kolkata",
  preferences: { preferredDays: ["Mon", "Wed", "Fri"] },
  goals: [{
    title: "First 5K",
    description: "Build running consistency",
    whyItMatters: "Feel energetic",
    category: "Fitness",
    status: "ACTIVE",
    targetDate: new Date("2026-10-01T00:00:00.000Z"),
    weeklyTarget: 3,
    preferredDays: ["Mon", "Wed", "Fri"],
    preferredTime: "Morning",
    milestones: [],
    actions: [],
  }],
};

beforeEach(() => mocks.findUnique.mockResolvedValue(accountContext));
afterEach(() => {
  vi.unstubAllGlobals();
  vi.clearAllMocks();
});

describe("personalized coach", () => {
  it("streams reply deltas and supplies private goal context server-side", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response([
      'data: {"choices":[{"delta":{"content":"Take a "}}]}',
      "",
      "data: this malformed provider line is ignored",
      "",
      'data: {"choices":[{"delta":{"content":"10-minute walk."}}]}',
      "",
      "data: [DONE]",
      "",
    ].join("\n"), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    const deltas: string[] = [];

    const reply = await streamCoachReply("user-1", {
      message: "What should I do next?",
      history: [{ role: "assistant", content: "Let's make today manageable." }],
    }, (text) => deltas.push(text));

    expect(reply).toBe("Take a 10-minute walk.");
    expect(deltas).toEqual(["Take a ", "10-minute walk."]);
    expect(mocks.findUnique).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "user-1" },
    }));
    const request = fetchMock.mock.calls[0]?.[1] as RequestInit;
    const body = JSON.parse(String(request.body));
    expect(body).toMatchObject({
      model: "openai/gpt-oss-120b",
      stream: true,
      reasoning_effort: "low",
    });
    expect(body.messages[0].content).toContain("First 5K");
    expect(body.messages[0].content).toContain("You are Tara");
    expect(body.messages[0].content).toContain("GitHub-Flavored Markdown");
    expect(body.messages.at(-1)).toEqual({
      role: "user",
      content: "What should I do next?",
    });
  });

  it("bounds conversation history", () => {
    expect(chatTurnSchema.safeParse({
      message: "Hello",
      history: Array.from({ length: 13 }, () => ({
        role: "user",
        content: "Earlier message",
      })),
    }).success).toBe(false);
  });

  it("executes streamed tool calls and reports data changes", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response([
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1","function":{"name":"update_task","arguments":"{\\"taskId\\":\\"action-1\\","}}]}}]}',
        "",
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"status\\":\\"COMPLETED\\"}"}}]}}]}',
        "",
        "data: [DONE]",
        "",
      ].join("\n"), { status: 200 }))
      .mockResolvedValueOnce(new Response([
        'data: {"choices":[{"delta":{"content":"Done — task completed."}}]}',
        "",
        "data: [DONE]",
        "",
      ].join("\n"), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    mocks.executeTool.mockResolvedValue({
      content: { task: { title: "Take a walk", status: "COMPLETED" } },
      changed: true,
    });
    const deltas: string[] = [];
    const changed = vi.fn();

    const reply = await streamCoachReply("user-1", {
      message: "Mark my walk complete",
      history: [],
    }, (text) => deltas.push(text), changed);

    expect(reply).toBe("Done — task completed.");
    expect(deltas).toEqual(["Done — task completed."]);
    expect(mocks.executeTool).toHaveBeenCalledWith(
      "user-1",
      "update_task",
      '{"taskId":"action-1","status":"COMPLETED"}',
      "Mark my walk complete",
    );
    expect(changed).toHaveBeenCalledOnce();
    const finalBody = JSON.parse(String((fetchMock.mock.calls[1]?.[1] as RequestInit).body));
    expect(finalBody.messages).toEqual(expect.arrayContaining([
      expect.objectContaining({ role: "tool", tool_call_id: "call-1" }),
    ]));
  });
});
