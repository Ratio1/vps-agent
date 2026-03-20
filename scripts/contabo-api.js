#!/usr/bin/env node

const crypto = require("crypto");
const { execFileSync } = require("child_process");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..");
const DEFAULT_PROFILES_PATH = process.env.VPS_PROFILES_PATH
  ? path.resolve(process.env.VPS_PROFILES_PATH)
  : path.join(ROOT_DIR, "profiles.json");
const DEFAULT_AUTH_URL = "https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token";
const DEFAULT_API_BASE_URL = "https://api.contabo.com";

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    command: null,
    file: DEFAULT_PROFILES_PATH,
    format: null,
    tenant: null,
    account: null,
    optional: false,
  };

  if (argv.length === 0) {
    fail("Usage: node scripts/contabo-api.js <token|list-instances> [options]");
  }

  args.command = argv[0];

  for (let i = 1; i < argv.length; i += 1) {
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
      case "--format":
        args.format = readValue();
        break;
      case "--tenant":
        args.tenant = readValue();
        break;
      case "--account":
        args.account = readValue();
        break;
      case "--optional":
        args.optional = true;
        break;
      default:
        fail(`Unknown option: ${flag}`);
    }
  }

  return args;
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (String(value || "").trim()) {
      return String(value).trim();
    }
  }
  return "";
}

function hasFullDirectCredentialSet(env) {
  return [
    env.CONTABO_CLIENT_ID,
    env.CONTABO_CLIENT_SECRET,
    env.CONTABO_API_USER,
    env.CONTABO_API_PASSWORD,
  ].every((value) => firstNonEmpty(value));
}

function canonicalizeContaboEnv(inputEnv) {
  const env = { ...inputEnv };

  const clientId = firstNonEmpty(env.CONTABO_CLIENT_ID, env.CLIENT_ID);
  const clientSecret = firstNonEmpty(env.CONTABO_CLIENT_SECRET, env.CLIENT_SECRET);
  const apiUser = firstNonEmpty(env.CONTABO_API_USER, env.API_USER);
  const apiPassword = firstNonEmpty(env.CONTABO_API_PASSWORD, env.API_PASSWORD);
  const accessToken = firstNonEmpty(env.CONTABO_ACCESS_TOKEN, env.ACCESS_TOKEN);

  if (clientId) {
    env.CONTABO_CLIENT_ID = clientId;
    env.CLIENT_ID = env.CLIENT_ID || clientId;
  }
  if (clientSecret) {
    env.CONTABO_CLIENT_SECRET = clientSecret;
    env.CLIENT_SECRET = env.CLIENT_SECRET || clientSecret;
  }
  if (apiUser) {
    env.CONTABO_API_USER = apiUser;
    env.API_USER = env.API_USER || apiUser;
  }
  if (apiPassword) {
    env.CONTABO_API_PASSWORD = apiPassword;
    env.API_PASSWORD = env.API_PASSWORD || apiPassword;
  }
  if (accessToken) {
    env.CONTABO_ACCESS_TOKEN = accessToken;
    env.ACCESS_TOKEN = env.ACCESS_TOKEN || accessToken;
  }

  env.CONTABO_AUTH_URL = firstNonEmpty(env.CONTABO_AUTH_URL, DEFAULT_AUTH_URL);
  env.CONTABO_API_BASE_URL = firstNonEmpty(env.CONTABO_API_BASE_URL, DEFAULT_API_BASE_URL);

  return env;
}

function hasUsableDirectCredentials(env) {
  const canonical = canonicalizeContaboEnv(env);
  return Boolean(firstNonEmpty(canonical.CONTABO_ACCESS_TOKEN)) || hasFullDirectCredentialSet(canonical);
}

function resolveProfileEnv(args) {
  const profilesScript = path.join(ROOT_DIR, "scripts", "profiles.js");
  const command = [
    profilesScript,
    "resolve",
    "--provider",
    "contabo",
    "--format",
    "json",
  ];

  if (args.optional) {
    command.push("--optional");
  }
  if (args.file) {
    command.push("--file", args.file);
  }
  if (args.tenant) {
    command.push("--tenant", args.tenant);
  }
  if (args.account) {
    command.push("--account", args.account);
  }

  let raw;
  try {
    raw = execFileSync(process.execPath, command, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    if (args.optional) {
      return {};
    }
    const stderr = String(error.stderr || "").trim();
    fail(stderr || "Unable to resolve the selected contabo account from profiles.json.");
  }

  if (!raw) {
    return {};
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    fail(`Unable to parse resolved Contabo profile JSON: ${error.message}`);
  }

  return parsed && parsed.env && typeof parsed.env === "object" ? parsed.env : {};
}

function buildContaboEnv(args) {
  const env = canonicalizeContaboEnv(process.env);
  if (hasUsableDirectCredentials(env)) {
    return env;
  }

  const profileEnv = canonicalizeContaboEnv(resolveProfileEnv(args));
  return canonicalizeContaboEnv({
    ...profileEnv,
    ...env,
  });
}

async function fetchAccessToken(env) {
  const cachedToken = firstNonEmpty(env.CONTABO_ACCESS_TOKEN, env.ACCESS_TOKEN);
  if (cachedToken) {
    return cachedToken;
  }

  if (!hasFullDirectCredentialSet(env)) {
    fail("Missing Contabo direct API credentials. Configure CONTABO_ACCESS_TOKEN or CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD.");
  }

  const body = new URLSearchParams();
  body.set("client_id", env.CONTABO_CLIENT_ID);
  body.set("client_secret", env.CONTABO_CLIENT_SECRET);
  body.set("username", env.CONTABO_API_USER);
  body.set("password", env.CONTABO_API_PASSWORD);
  body.set("grant_type", "password");

  let response;
  try {
    response = await fetch(env.CONTABO_AUTH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });
  } catch (error) {
    fail(`Unable to reach Contabo auth endpoint: ${error.message}`);
  }

  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    fail(`Unable to parse Contabo auth response: ${error.message}`);
  }

  if (!response.ok) {
    const message = firstNonEmpty(payload.error_description, payload.error, response.statusText);
    fail(`Contabo auth failed (${response.status}): ${message}`);
  }

  const accessToken = firstNonEmpty(payload.access_token);
  if (!accessToken) {
    fail("Contabo auth succeeded but no access_token was returned.");
  }

  return accessToken;
}

function normalizeInstanceItems(payload) {
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

async function fetchContaboJson(url, accessToken, errorPrefix) {
  let response;
  try {
    response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: "application/json",
        "x-request-id": crypto.randomUUID(),
      },
    });
  } catch (error) {
    fail(`Unable to reach Contabo API: ${error.message}`);
  }

  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    fail(`Unable to parse Contabo API response: ${error.message}`);
  }

  if (!response.ok) {
    fail(`${errorPrefix} (${response.status}): ${JSON.stringify(payload)}`);
  }

  return payload;
}

async function fetchAllInstances(baseUrl, accessToken) {
  const pageSize = 200;
  let page = 1;
  let totalPages = 1;
  let firstPayload = null;
  const allItems = [];

  while (page <= totalPages) {
    const url = `${baseUrl}/v1/compute/instances?page=${page}&size=${pageSize}`;
    const payload = await fetchContaboJson(url, accessToken, "Contabo instance listing failed");
    const items = normalizeInstanceItems(payload);
    if (!items) {
      fail("Unexpected Contabo instances payload shape.");
    }

    if (!firstPayload) {
      firstPayload = payload;
    }

    allItems.push(...items);

    const reportedTotalPages = Number(payload?._pagination?.totalPages);
    if (Number.isFinite(reportedTotalPages) && reportedTotalPages > 0) {
      totalPages = reportedTotalPages;
    } else if (items.length < pageSize) {
      totalPages = page;
    } else {
      totalPages = page + 1;
    }

    page += 1;
  }

  if (firstPayload && typeof firstPayload === "object" && !Array.isArray(firstPayload)) {
    return {
      ...firstPayload,
      data: allItems,
      _pagination: {
        ...(firstPayload._pagination && typeof firstPayload._pagination === "object" ? firstPayload._pagination : {}),
        size: allItems.length,
        totalElements: allItems.length,
        totalPages: 1,
        page: 1,
      },
    };
  }

  return allItems;
}

function summarizeInstances(payload) {
  const items = normalizeInstanceItems(payload);
  if (!items) {
    fail("Unexpected Contabo instances payload shape.");
  }

  const states = {};
  const rows = items.map((item) => {
    const state = firstNonEmpty(item.status, item.state, "unknown");
    states[state] = (states[state] || 0) + 1;
    return {
      instanceId: item.instanceId ?? item.id ?? null,
      name: firstNonEmpty(item.displayName, item.name, item.hostname),
      status: state,
      region: firstNonEmpty(item.region, item.regionName),
      productId: firstNonEmpty(item.productId),
    };
  });

  return {
    count: items.length,
    states,
    instances: rows,
  };
}

async function listInstances(env, format) {
  const accessToken = await fetchAccessToken(env);
  const baseUrl = env.CONTABO_API_BASE_URL.replace(/\/+$/, "");
  const payload = await fetchAllInstances(baseUrl, accessToken);

  switch (format) {
    case "json":
      process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
      return;
    case "summary": {
      const summary = summarizeInstances(payload);
      const lines = [
        `count=${summary.count}`,
        `states=${JSON.stringify(summary.states)}`,
        ...summary.instances.map((instance) => {
          const parts = [
            instance.instanceId ?? "",
            instance.name || "",
            instance.status || "",
            instance.region || "",
            instance.productId || "",
          ];
          return parts.join("\t").replace(/\t+$/, "");
        }),
      ];
      process.stdout.write(`${lines.join("\n")}\n`);
      return;
    }
    default:
      fail(`Unsupported list-instances format: ${format}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const env = buildContaboEnv(args);

  switch (args.command) {
    case "token": {
      const accessToken = await fetchAccessToken(env);
      if ((args.format || "token") === "json") {
        process.stdout.write(`${JSON.stringify({ accessToken }, null, 2)}\n`);
        return;
      }
      if ((args.format || "token") === "token") {
        process.stdout.write(`${accessToken}\n`);
        return;
      }
      fail(`Unsupported token format: ${args.format}`);
      return;
    }
    case "list-instances":
      await listInstances(env, args.format || "json");
      return;
    default:
      fail(`Unknown command: ${args.command}`);
  }
}

main().catch((error) => fail(error.message));
