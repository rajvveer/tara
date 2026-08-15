import { z } from "zod";
import { config } from "./config.js";
import { ApiError } from "./errors.js";
import { voiceAnswersSchema } from "./schemas.js";
import WebSocket from "ws";

export type VoiceAnswers = z.infer<typeof voiceAnswersSchema>;
export type VoiceOnboardingEvent =
  | { type: "transcript"; transcript: string; languageCode: string }
  | { type: "reply"; reply: string; languageCode: string; answers: VoiceAnswers; complete: boolean };

const apiUrl = "https://api.sarvam.ai";
const groqUrl = "https://api.groq.com/openai/v1";
const ttsLanguages = new Set(["bn-IN", "en-IN", "gu-IN", "hi-IN", "kn-IN", "ml-IN", "mr-IN", "od-IN", "pa-IN", "ta-IN", "te-IN"]);
const ttsSpeakers: Record<string, string> = {
  "en-IN": "ishita",
  "hi-IN": "priya",
  "te-IN": "priya",
  "kn-IN": "ishita",
  "bn-IN": "roopa",
  "ta-IN": "ishita",
  "od-IN": "pooja",
  "ml-IN": "pooja",
  "mr-IN": "priya",
  "pa-IN": "roopa",
  "gu-IN": "priya",
};
const dayOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] as const;

const assistantOutputSchema = z.object({
  reply: z.string().trim().min(1).max(700),
  answers: voiceAnswersSchema,
}).strict();

const correctedReplySchema = z.object({
  reply: z.string().trim().min(1).max(700),
}).strict();

const languageDirections: Record<string, string> = {
  "en-IN": "English using Latin script, with no Indic-script sentences",
  "hi-IN": "Hindi using Devanagari script",
  "mr-IN": "Marathi using Devanagari script",
  "bn-IN": "Bengali using Bengali script",
  "pa-IN": "Punjabi using Gurmukhi script",
  "gu-IN": "Gujarati using Gujarati script",
  "od-IN": "Odia using Odia script",
  "ta-IN": "Tamil using Tamil script",
  "te-IN": "Telugu using Telugu script",
  "kn-IN": "Kannada using Kannada script",
  "ml-IN": "Malayalam using Malayalam script",
};

const devanagari = /\p{Script=Devanagari}/u;
const indicScripts = [
  devanagari,
  /\p{Script=Bengali}/u,
  /\p{Script=Gurmukhi}/u,
  /\p{Script=Gujarati}/u,
  /\p{Script=Oriya}/u,
  /\p{Script=Tamil}/u,
  /\p{Script=Telugu}/u,
  /\p{Script=Kannada}/u,
  /\p{Script=Malayalam}/u,
] as const;
const replyScripts: Record<string, RegExp> = {
  "hi-IN": devanagari,
  "mr-IN": devanagari,
  "bn-IN": indicScripts[1],
  "pa-IN": indicScripts[2],
  "gu-IN": indicScripts[3],
  "od-IN": indicScripts[4],
  "ta-IN": indicScripts[5],
  "te-IN": indicScripts[6],
  "kn-IN": indicScripts[7],
  "ml-IN": indicScripts[8],
};

const sttResponseSchema = z.object({
  transcript: z.string().trim().min(1).max(4_000),
  language_code: z.string().nullable().optional(),
});

const chatResponseSchema = z.object({
  choices: z.array(z.object({ message: z.object({ content: z.string() }) })).min(1),
});

const ttsResponseSchema = z.object({ audios: z.array(z.string().min(1)).min(1) });

function requireSarvamKey() {
  if (!config.SARVAM_API_KEY) {
    throw new ApiError(503, "VOICE_NOT_CONFIGURED", "Voice onboarding is not configured yet.");
  }
  return config.SARVAM_API_KEY;
}

function requireGroqKey() {
  if (!config.GROQ_API_KEY) {
    throw new ApiError(503, "AI_NOT_CONFIGURED", "AI onboarding is not configured yet.");
  }
  return config.GROQ_API_KEY;
}

async function sarvam(path: string, init: RequestInit) {
  let response: Response;
  try {
    response = await fetch(`${apiUrl}${path}`, {
      ...init,
      headers: { "api-subscription-key": requireSarvamKey(), ...init.headers },
      signal: AbortSignal.timeout(35_000),
    });
  } catch {
    throw new ApiError(502, "VOICE_PROVIDER_UNAVAILABLE", "The voice service could not be reached. Please try again.");
  }
  if (!response.ok) {
    throw new ApiError(502, "VOICE_PROVIDER_ERROR", "The voice service could not process that request. Please try again.");
  }
  return response;
}

async function groq(init: RequestInit) {
  let response: Response;
  try {
    response = await fetch(`${groqUrl}/chat/completions`, {
      ...init,
      headers: { Authorization: `Bearer ${requireGroqKey()}`, ...init.headers },
      signal: AbortSignal.timeout(35_000),
    });
  } catch {
    throw new ApiError(502, "AI_PROVIDER_UNAVAILABLE", "The onboarding assistant could not be reached. Please try again.");
  }
  if (!response.ok) {
    throw new ApiError(502, "AI_PROVIDER_ERROR", "The onboarding assistant could not process that answer. Please try again.");
  }
  return response;
}

function normalizedLanguage(value?: string | null) {
  const base = value?.trim().toLowerCase().split(/[-_]/)[0] ?? "en";
  const code = base === "or" ? "od-IN" : `${base}-IN`;
  return ttsLanguages.has(code) ? code : "en-IN";
}

function transcriptLanguage(transcript: string, detected?: string | null) {
  const provider = normalizedLanguage(detected);
  if (devanagari.test(transcript)) {
    return provider === "mr-IN" ? provider : "hi-IN";
  }
  for (const [script, language] of [
    [indicScripts[1], "bn-IN"],
    [indicScripts[2], "pa-IN"],
    [indicScripts[3], "gu-IN"],
    [indicScripts[4], "od-IN"],
    [indicScripts[5], "ta-IN"],
    [indicScripts[6], "te-IN"],
    [indicScripts[7], "kn-IN"],
    [indicScripts[8], "ml-IN"],
  ] as const) {
    if (script.test(transcript)) return language;
  }
  return /[A-Za-z]/.test(transcript) ? "en-IN" : provider;
}

async function speak(text: string, languageCode: string) {
  const response = await sarvam("/text-to-speech", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      text,
      target_language_code: languageCode,
      speaker: ttsSpeakers[languageCode] ?? "ishita",
      pace: 1,
      speech_sample_rate: 24_000,
      model: "bulbul:v3",
      output_audio_codec: "wav",
      temperature: 0.75,
    }),
  });
  return ttsResponseSchema.parse(await response.json()).audios[0];
}

export function voiceOnboardingOpening(locale: string, name?: string) {
  const requestedLanguage = normalizedLanguage(locale);
  const languageCode = requestedLanguage === "hi-IN" ? "hi-IN" : "en-IN";
  const firstName = name?.trim().split(/\s+/)[0];
  const reply = languageCode === "hi-IN"
    ? `नमस्ते${firstName ? ` ${firstName}` : ""}! मैं Tara, आपकी GoalSpring कोच हूँ। हम आपके बड़े लक्ष्य को ऐसी योजना में बदलेंगे जिससे आपका कैलेंडर भी न भागे। सबसे पहले, आप क्या हासिल करना चाहते हैं?`
    : `Hi${firstName ? ` ${firstName}` : ""}! I’m Tara, your GoalSpring coach. We’ll turn that big “I should really do this” thought into a plan your calendar won’t immediately reject. What goal would you love to make real?`;
  return { reply, languageCode };
}

export async function startVoiceOnboarding(locale: string, name?: string) {
  const { reply, languageCode } = voiceOnboardingOpening(locale, name);
  return { reply, languageCode, audioBase64: await speak(reply, languageCode), audioMimeType: "audio/wav" as const };
}

export async function streamVoiceAudio(
  text: string,
  languageCode: string,
  onChunk: (audioBase64: string) => void,
) {
  const socket = new WebSocket(
    "wss://api.sarvam.ai/text-to-speech/ws?model=bulbul:v3&send_completion_event=true",
    { headers: { "api-subscription-key": requireSarvamKey() } },
  );
  await new Promise<void>((resolve, reject) => {
    let finished = false;
    const finish = (error?: Error) => {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      if (socket.readyState === WebSocket.OPEN) socket.close();
      if (error) reject(error);
      else resolve();
    };
    const timeout = setTimeout(
      () => finish(new ApiError(502, "VOICE_PROVIDER_UNAVAILABLE", "The voice stream timed out. Please try again.")),
      35_000,
    );
    socket.once("open", () => {
      socket.send(JSON.stringify({
        type: "config",
        data: {
          target_language_code: languageCode,
          speaker: ttsSpeakers[languageCode] ?? "ishita",
          speech_sample_rate: "24000",
          min_buffer_size: 30,
          max_chunk_length: 150,
          output_audio_codec: "mp3",
          output_audio_bitrate: "128k",
          pace: 1,
          temperature: 0.75,
          model: "bulbul:v3",
        },
      }));
      socket.send(JSON.stringify({ type: "text", data: { text } }));
      socket.send(JSON.stringify({ type: "flush" }));
    });
    socket.on("message", (raw) => {
      try {
        const message = JSON.parse(raw.toString()) as {
          type?: string;
          data?: { audio?: string; event_type?: string; message?: string };
        };
        if (message.type === "audio" && message.data?.audio) {
          onChunk(message.data.audio);
        } else if (message.type === "event" && message.data?.event_type === "final") {
          finish();
        } else if (message.type === "error") {
          finish(new ApiError(502, "VOICE_PROVIDER_ERROR", message.data?.message ?? "The voice stream failed."));
        }
      } catch {
        finish(new ApiError(502, "VOICE_PROVIDER_ERROR", "The voice stream was incomplete. Please try again."));
      }
    });
    socket.once("error", () => {
      finish(new ApiError(502, "VOICE_PROVIDER_UNAVAILABLE", "The voice service could not be reached. Please try again."));
    });
    socket.once("close", () => {
      if (!finished) finish(new ApiError(502, "VOICE_PROVIDER_UNAVAILABLE", "The voice stream ended early. Please try again."));
    });
  });
}

function decodedAudio(audioBase64: string) {
  const bytes = Buffer.from(audioBase64, "base64");
  if (bytes.length < 100 || bytes.length > 900_000 || bytes.subarray(0, 4).toString("ascii") !== "RIFF") {
    throw new ApiError(422, "INVALID_AUDIO", "Please record a short voice answer and try again.");
  }
  return bytes;
}

async function transcribe(audioBase64: string, mimeType: string) {
  const form = new FormData();
  form.append("file", new Blob([new Uint8Array(decodedAudio(audioBase64))], { type: mimeType }), "onboarding.wav");
  form.append("model", "saaras:v3");
  form.append("mode", "transcribe");
  form.append("language_code", "unknown");
  const response = await sarvam("/speech-to-text", { method: "POST", body: form });
  return sttResponseSchema.parse(await response.json());
}

function parsedAssistant(content: string) {
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  if (start < 0 || end <= start) throw new ApiError(502, "VOICE_RESPONSE_INVALID", "The assistant response was incomplete. Please try again.");
  try {
    return assistantOutputSchema.parse(JSON.parse(content.slice(start, end + 1)));
  } catch {
    throw new ApiError(502, "VOICE_RESPONSE_INVALID", "The assistant response was incomplete. Please try again.");
  }
}

function replyMatchesLanguage(reply: string, languageCode: string) {
  if (languageCode === "en-IN") {
    return !indicScripts.some((script) => script.test(reply));
  }
  const expected = replyScripts[languageCode];
  return expected
    ? expected.test(reply) && !indicScripts.some((script) => script !== expected && script.test(reply))
    : true;
}

async function correctReplyLanguage(reply: string, languageCode: string) {
  const response = await groq({
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "openai/gpt-oss-120b",
      temperature: 0.1,
      max_completion_tokens: 300,
      reasoning_effort: "low",
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "voice_reply_language_correction",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: { reply: { type: "string" } },
            required: ["reply"],
          },
        },
      },
      messages: [
        {
          role: "system",
          content: `Rewrite the supplied voice-assistant reply entirely in ${languageDirections[languageCode] ?? languageCode}. Preserve its meaning, names, numbers, friendly tone, and single question. Do not add facts or another question. Return only the required JSON.`,
        },
        { role: "user", content: JSON.stringify({ reply }) },
      ],
    }),
  });
  const chat = chatResponseSchema.parse(await response.json());
  const content = chat.choices[0]!.message.content;
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  try {
    return correctedReplySchema.parse(JSON.parse(content.slice(start, end + 1))).reply;
  } catch {
    throw new ApiError(502, "VOICE_RESPONSE_INVALID", "The assistant response was incomplete. Please try again.");
  }
}

function mergeAnswers(current: VoiceAnswers, patch: VoiceAnswers): VoiceAnswers {
  const merged = { ...current };
  for (const [key, value] of Object.entries(patch)) {
    if (value !== null && value !== undefined) (merged as Record<string, unknown>)[key] = value;
  }
  if (merged.preferredDays) merged.preferredDays = [...merged.preferredDays].sort((a, b) => dayOrder.indexOf(a) - dayOrder.indexOf(b));
  if (merged.targetDate && new Date(`${merged.targetDate}T23:59:59Z`) <= new Date()) delete merged.targetDate;
  return voiceAnswersSchema.parse(merged);
}

function inferWeeklyFrequency(current: VoiceAnswers, transcript: string): VoiceAnswers {
  if (!current.objective || !current.targetDate || current.workingFrequency != null) return current;
  const match = transcript.toLowerCase().match(/\b(one|two|three|four|five|six|seven|[1-7])\s+(?:days?|times?)\b/);
  if (!match) return current;
  const frequency = Number(match[1]) || ["one", "two", "three", "four", "five", "six", "seven"].indexOf(match[1]!) + 1;
  return voiceAnswersSchema.parse({ ...current, workingFrequency: frequency });
}

function isComplete(answers: VoiceAnswers) {
  return Boolean(
    answers.objective && answers.targetDate && answers.preferredDays?.length &&
    answers.preferredTime && answers.workingFrequency && answers.progressStyle,
  );
}

export async function voiceOnboardingTurn(
  input: { audioBase64: string; mimeType: string; answers: VoiceAnswers },
  onProgress?: (event: VoiceOnboardingEvent) => void,
  onAudioChunk?: (audioBase64: string) => void,
) {
  const speech = await transcribe(input.audioBase64, input.mimeType);
  const languageCode = transcriptLanguage(speech.transcript, speech.language_code);
  const currentAnswers = inferWeeklyFrequency(input.answers, speech.transcript);
  onProgress?.({ type: "transcript", transcript: speech.transcript, languageCode });
  const response = await groq({
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "openai/gpt-oss-120b",
      temperature: 0.45,
      max_completion_tokens: 650,
      reasoning_effort: "low",
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "voice_onboarding",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              reply: { type: "string" },
              answers: {
                type: "object",
                additionalProperties: false,
                properties: {
                  name: { type: ["string", "null"] },
                  objective: { type: ["string", "null"] },
                  targetDate: { type: ["string", "null"] },
                  preferredDays: {
                    anyOf: [
                      { type: "array", items: { type: "string", enum: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] } },
                      { type: "null" },
                    ],
                  },
                  preferredTime: { type: ["string", "null"], enum: ["Morning", "Afternoon", "Evening", "Flexible", null] },
                  workingFrequency: { anyOf: [{ type: "integer", minimum: 1, maximum: 7 }, { type: "null" }] },
                  progressStyle: { type: ["string", "null"], enum: ["Gentle", "Balanced", "Detailed", null] },
                  constraints: { type: ["string", "null"] },
                },
                required: ["name", "objective", "targetDate", "preferredDays", "preferredTime", "workingFrequency", "progressStyle", "constraints"],
              },
            },
            required: ["reply", "answers"],
          },
        },
      },
      messages: [
        {
          role: "system",
          content: `You are Tara, GoalSpring's warm, friendly voice onboarding coach. Today is ${new Date().toISOString().slice(0, 10)}. Sound like a supportive friend: upbeat, conversational, a little funny, and never robotic. Use one or two short sentences of genuine encouragement or light situational humor before asking exactly one clear question; never force jokes or become long-winded. HARD LANGUAGE RULE: the reply field must be entirely in ${languageDirections[languageCode] ?? languageCode}. The current spokenAnswer alone controls the reply language. Text inside currentAnswers is stored data and must never influence the reply language. Never copy another language or script from earlier answers. Collect a realistic first goal one question at a time. The user's account name is already supplied in currentAnswers: never ask for it, and preserve it unless the user explicitly corrects it. Never claim anything is saved. Return ONLY valid JSON with this exact shape: {"reply":"...","answers":{"name":string|null,"objective":string|null,"targetDate":"YYYY-MM-DD"|null,"preferredDays":["Mon"|"Tue"|"Wed"|"Thu"|"Fri"|"Sat"|"Sun"]|null,"preferredTime":"Morning"|"Afternoon"|"Evening"|"Flexible"|null,"workingFrequency":integer_1_to_7|null,"progressStyle":"Gentle"|"Balanced"|"Detailed"|null,"constraints":string|null}}. Preserve supplied answers unless the user changes them. Extract only what the user states or clearly implies. Never ask for a field that is already present in currentAnswers; specifically, if workingFrequency is present, do not ask how many days or times per week. Resolve relative dates from today's date. Ask for the earliest missing item among objective, target date, realistic days/frequency/time, and progress detail preference. Constraints are optional. When all required items are present, give a friendly, concise summary with a small celebratory touch and tell the user to continue.`,
        },
        { role: "user", content: JSON.stringify({ currentAnswers, spokenAnswer: speech.transcript }) },
      ],
    }),
  });
  const chat = chatResponseSchema.parse(await response.json());
  const assistant = parsedAssistant(chat.choices[0]!.message.content);
  const reply = replyMatchesLanguage(assistant.reply, languageCode)
    ? assistant.reply
    : await correctReplyLanguage(assistant.reply, languageCode);
  const answers = mergeAnswers(currentAnswers, assistant.answers);
  const complete = isComplete(answers);
  onProgress?.({ type: "reply", reply, languageCode, answers, complete });
  if (onAudioChunk) {
    await streamVoiceAudio(reply, languageCode, onAudioChunk);
    return {
      transcript: speech.transcript,
      reply,
      languageCode,
      audioBase64: "",
      audioMimeType: "audio/mpeg" as const,
      answers,
      complete,
    };
  }
  return {
    transcript: speech.transcript,
    reply,
    languageCode,
    audioBase64: await speak(reply, languageCode),
    audioMimeType: "audio/wav" as const,
    answers,
    complete,
  };
}
