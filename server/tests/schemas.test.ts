import { describe, expect, it } from "vitest";
import { profileSchema } from "../src/schemas.js";

describe("avatar schema", () => {
  it("accepts independently mixed character parts", () => {
    expect(profileSchema.safeParse({ avatarKey: "amara-blue-teal" }).success).toBe(true);
    expect(profileSchema.safeParse({ avatarKey: "unknown-blue-teal" }).success).toBe(false);
  });
});
