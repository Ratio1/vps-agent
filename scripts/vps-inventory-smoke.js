#!/usr/bin/env node

const { execFileSync } = require("child_process");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..");
const DEFAULT_PROFILES_PATH = process.env.VPS_PROFILES_PATH
  ? path.resolve(process.env.VPS_PROFILES_PATH)
  : path.join(ROOT_DIR, "profiles.json");
const HOSTINGER_VPS_URL = "https://developers.hostinger.com/api/vps/v1/virtual-machines";

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    file: DEFAULT_PROFILES_PATH,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    const [flag, rawValue] = token.split("=", 2);
    const readValue = () => {
      if (rawValue !== undefined) {
        return rawValue;
      }
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        fail(`Missing value for ${flag}`);
      }
      i += 1;
      return next;
    };

    switch (flag) {
      case "--file":
        args.file = path.resolve(readValue());
        break;
      default:
        fail(`Unknown option: ${flag}`);
    }
  }

  return args;
}

function runNodeScript(scriptPath, scriptArgs) {
  try {
    return execFileSync(process.execPath, [scriptPath, ...scriptArgs], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    const stderr = String(error.stderr || "").trim();
    const stdout = String(error.stdout || "").trim();
    fail(stderr || stdout || `Command failed: ${path.basename(scriptPath)}`);
  }
}

function readAccounts(filePath) {
  const profilesScript = path.join(ROOT_DIR, "scripts", "profiles.js");
  const raw = runNodeScript(profilesScript, [
    "list",
    "--file",
    filePath,
    "--format",
    "json",
    "--optional",
  ]);

  if (!raw) {
    return [];
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    fail(`Unable to parse profiles account list: ${error.message}`);
  }

  return Array.isArray(parsed) ? parsed : [];
}

function resolveEnv(filePath, tenant, provider) {
  const profilesScript = path.join(ROOT_DIR, "scripts", "profiles.js");
  const raw = runNodeScript(profilesScript, [
    "resolve",
    "--file",
    filePath,
    "--tenant",
    tenant,
    "--provider",
    provider,
    "--format",
    "json",
  ]);

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    fail(`Unable to parse resolved profile for ${tenant}/${provider}: ${error.message}`);
  }

  return parsed && parsed.env && typeof parsed.env === "object" ? parsed.env : {};
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (String(value || "").trim()) {
      return String(value).trim();
    }
  }
  return "";
}

function summarizeStates(items, selectors) {
  const states = {};
  for (const item of items) {
    const state = firstNonEmpty(...selectors.map((selector) => item?.[selector]), "unknown");
    states[state] = (states[state] || 0) + 1;
  }
  return states;
}

function normalizeHostingerItems(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }
  if (payload && typeof payload === "object" && Array.isArray(payload.data)) {
    return payload.data;
  }
  return null;
}

function normalizeContaboItems(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }
  if (payload && typeof payload === "object") {
    if (Array.isArray(payload.data)) {
      return payload.data;
    }
    if (Array.isArray(payload.instances)) {
      return payload.instances;
    }
  }
  return null;
}

async function testHostinger(env) {
  const token = firstNonEmpty(env.API_TOKEN, env.HOSTINGER_API_TOKEN);
  if (!token) {
    return {
      status: "skip",
      message: "missing API_TOKEN/HOSTINGER_API_TOKEN",
    };
  }

  let response;
  try {
    response = await fetch(HOSTINGER_VPS_URL, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
    });
  } catch (error) {
    return {
      status: "fail",
      message: `request failed: ${error.message}`,
    };
  }

  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    return {
      status: "fail",
      message: `unable to parse API response: ${error.message}`,
    };
  }

  if (!response.ok) {
    return {
      status: "fail",
      message: `Hostinger API returned ${response.status}`,
    };
  }

  const items = normalizeHostingerItems(payload);
  if (!items) {
    return {
      status: "fail",
      message: "unexpected Hostinger API payload shape",
    };
  }

  return {
    status: "pass",
    count: items.length,
    message: `listed ${items.length} VPS; states=${JSON.stringify(summarizeStates(items, ["state", "status"]))}`,
  };
}

function hasUsableContaboCredentials(env) {
  const accessToken = firstNonEmpty(env.CONTABO_ACCESS_TOKEN, env.ACCESS_TOKEN);
  const clientId = firstNonEmpty(env.CONTABO_CLIENT_ID, env.CLIENT_ID);
  const clientSecret = firstNonEmpty(env.CONTABO_CLIENT_SECRET, env.CLIENT_SECRET);
  const apiUser = firstNonEmpty(env.CONTABO_API_USER, env.API_USER);
  const apiPassword = firstNonEmpty(env.CONTABO_API_PASSWORD, env.API_PASSWORD);

  return Boolean(accessToken) || Boolean(clientId && clientSecret && apiUser && apiPassword);
}

function testContabo(filePath, tenant, env) {
  if (!hasUsableContaboCredentials(env)) {
    return {
      status: "skip",
      count: null,
      message: "missing CONTABO_ACCESS_TOKEN or CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD",
    };
  }

  const contaboScript = path.join(ROOT_DIR, "scripts", "contabo-api.js");
  let raw;
  try {
    raw = execFileSync(
      process.execPath,
      [
        contaboScript,
        "list-instances",
        "--file",
        filePath,
        "--tenant",
        tenant,
        "--format",
        "json",
      ],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      },
    ).trim();
  } catch (error) {
    const stderr = String(error.stderr || "").trim();
    const stdout = String(error.stdout || "").trim();
    return {
      status: "fail",
      count: null,
      message: stderr || stdout || "Contabo inventory lookup failed",
    };
  }

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch (error) {
    return {
      status: "fail",
      count: null,
      message: `unable to parse Contabo API response: ${error.message}`,
    };
  }

  const items = normalizeContaboItems(payload);
  if (!items) {
    return {
      status: "fail",
      count: null,
      message: "unexpected Contabo API payload shape",
    };
  }

  return {
    status: "pass",
    count: items.length,
    message: `listed ${items.length} VPS; states=${JSON.stringify(summarizeStates(items, ["status", "state"]))}`,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const accounts = readAccounts(args.file);

  if (accounts.length === 0) {
    process.stdout.write("[skip] no provider entries configured\n");
    process.stdout.write("[summary] pass=0 fail=0 skip=1\n");
    return;
  }

  let passCount = 0;
  let failCount = 0;
  let skipCount = 0;
  const counts = {};

  for (const account of accounts) {
    const tenant = account.tenant;
    const provider = account.provider;
    const label = `${tenant}/${provider}`;
    const env = resolveEnv(args.file, tenant, provider);

    let result;
    switch (provider) {
      case "hostinger":
        result = await testHostinger(env);
        break;
      case "contabo":
        result = testContabo(args.file, tenant, env);
        break;
      default:
        result = {
          status: "skip",
          count: null,
          message: "no inventory smoke test implemented for this provider",
        };
        break;
    }

    counts[label] = result.count ?? null;

    switch (result.status) {
      case "pass":
        passCount += 1;
        process.stdout.write(`[pass] ${label}: ${result.message}\n`);
        break;
      case "skip":
        skipCount += 1;
        process.stdout.write(`[skip] ${label}: ${result.message}\n`);
        break;
      default:
        failCount += 1;
        process.stdout.write(`[fail] ${label}: ${result.message}\n`);
        break;
    }
  }

  process.stdout.write(`[summary] pass=${passCount} fail=${failCount} skip=${skipCount}\n`);
  process.stdout.write(`[counts] ${JSON.stringify(counts)}\n`);

  if (failCount > 0) {
    process.exit(1);
  }
}

main().catch((error) => fail(error.message));
