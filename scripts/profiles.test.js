#!/usr/bin/env node

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT_DIR = path.resolve(__dirname, "..");
const PROFILES_SCRIPT = path.join(ROOT_DIR, "scripts", "profiles.js");

function runProfiles(args) {
  return execFileSync(process.execPath, [PROFILES_SCRIPT, ...args], {
    cwd: ROOT_DIR,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

test("validate and resolve ignore nested ssh metadata blocks", () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "profiles-test-"));
  const filePath = path.join(tempDir, "profiles.json");

  fs.writeFileSync(
    filePath,
    `${JSON.stringify(
      {
        tenants: [
          {
            tenant: "Ratio1",
            accounts: [
              {
                provider: "contabo",
                credentials: {
                  CLIENT_ID: "client-id",
                  CLIENT_SECRET: "client-secret",
                  API_USER: "api-user",
                  API_PASSWORD: "api-password",
                },
                ssh: {
                  ssh_user: "root",
                  ssh_pem: "aidamian.pem",
                  hosts: {
                    "r1s-01": "184.174.38.249",
                    "r1s-02": "89.116.28.21",
                  },
                },
                settings: {
                  CONTABO_API_BASE_URL: "https://api.contabo.com",
                },
              },
            ],
          },
        ],
      },
      null,
      2,
    )}\n`,
    "utf8",
  );

  const validation = JSON.parse(runProfiles(["validate", "--file", filePath, "--format", "json"]));
  assert.equal(validation.tenants, 1);
  assert.deepEqual(validation.warnings, []);

  const resolved = JSON.parse(
    runProfiles([
      "resolve",
      "--file",
      filePath,
      "--tenant",
      "Ratio1",
      "--provider",
      "contabo",
      "--format",
      "json",
    ]),
  );

  assert.equal(resolved.tenant, "Ratio1");
  assert.equal(resolved.provider, "contabo");
  assert.equal(resolved.env.CLIENT_ID, "client-id");
  assert.equal(resolved.env.CONTABO_API_BASE_URL, "https://api.contabo.com");
  assert.ok(!Object.prototype.hasOwnProperty.call(resolved.env, "ssh"));
  assert.ok(!Object.prototype.hasOwnProperty.call(resolved.env, "SSH"));
});
