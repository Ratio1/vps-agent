#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..");
const DEFAULT_PROFILES_PATH = process.env.VPS_PROFILES_PATH
  ? path.resolve(process.env.VPS_PROFILES_PATH)
  : path.join(ROOT_DIR, "profiles.json");

const RESERVED_ACCOUNT_KEYS = new Set([
  "provider",
  "account",
  "name",
  "default",
  "enabled",
  "description",
  "credentials",
  "settings",
]);

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    command: null,
    file: DEFAULT_PROFILES_PATH,
    format: null,
    provider: null,
    tenant: null,
    account: null,
    optional: false,
    makeDefault: false,
    credentials: [],
    settings: [],
    passthrough: [],
  };

  if (argv.length === 0) {
    fail("Usage: node scripts/profiles.js <list|resolve|validate|upsert-account> [options]");
  }

  args.command = argv[0];

  for (let i = 1; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === "--") {
      args.passthrough = argv.slice(i + 1);
      break;
    }

    if (!token.startsWith("--")) {
      fail(`Unknown positional argument: ${token}`);
    }

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
      case "--provider":
        args.provider = readValue();
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
      case "--make-default":
        args.makeDefault = true;
        break;
      case "--credential":
        args.credentials.push(parseKeyValue(readValue(), "--credential"));
        break;
      case "--setting":
        args.settings.push(parseKeyValue(readValue(), "--setting"));
        break;
      default:
        fail(`Unknown option: ${flag}`);
    }
  }

  return args;
}

function parseKeyValue(raw, flagName) {
  const idx = raw.indexOf("=");
  if (idx <= 0) {
    fail(`${flagName} expects KEY=VALUE`);
  }

  const key = raw.slice(0, idx).trim();
  const value = raw.slice(idx + 1);
  validateEnvKey(key);
  return { key, value };
}

function validateEnvKey(key) {
  if (!/^[A-Z][A-Z0-9_]*$/.test(key)) {
    fail(`Invalid environment key: ${key}`);
  }
}

function readProfiles(filePath, optional = false) {
  if (!fs.existsSync(filePath)) {
    if (optional) {
      return null;
    }
    fail(`Profiles file not found: ${filePath}`);
  }

  let raw;
  try {
    raw = JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    fail(`Unable to parse ${filePath}: ${error.message}`);
  }

  if (Array.isArray(raw)) {
    return {
      schemaVersion: 1,
      defaults: {},
      hasSchemaVersion: false,
      hasDefaults: false,
      tenants: raw,
      filePath,
    };
  }

  if (raw && typeof raw === "object") {
    const tenants = Array.isArray(raw.tenants)
      ? raw.tenants
      : Array.isArray(raw.profiles)
        ? raw.profiles
        : null;

    if (!tenants) {
      fail(`Profiles file must be an array or an object with a tenants array: ${filePath}`);
    }

    return {
      schemaVersion: Number.isInteger(raw.schemaVersion) ? raw.schemaVersion : 1,
      defaults: raw.defaults && typeof raw.defaults === "object" ? raw.defaults : {},
      hasSchemaVersion: Object.prototype.hasOwnProperty.call(raw, "schemaVersion"),
      hasDefaults: Object.prototype.hasOwnProperty.call(raw, "defaults"),
      tenants,
      filePath,
    };
  }

  fail(`Profiles file must be a JSON array or object: ${filePath}`);
}

function derivedAccountName(account, index) {
  if (typeof account.account === "string" && account.account.trim()) {
    return account.account.trim();
  }
  if (typeof account.name === "string" && account.name.trim()) {
    return account.name.trim();
  }
  return "primary";
}

function normalizeProfiles(profiles) {
  const warnings = [];
  const tenantNames = new Set();

  const normalizedTenants = profiles.tenants.map((tenant, tenantIndex) => {
    if (!tenant || typeof tenant !== "object") {
      fail(`Tenant entry at index ${tenantIndex} must be an object`);
    }

    const tenantName = typeof tenant.tenant === "string" ? tenant.tenant.trim() : "";
    if (!tenantName) {
      fail(`Tenant entry at index ${tenantIndex} is missing a non-empty tenant name`);
    }
    if (tenantNames.has(tenantName.toLowerCase())) {
      fail(`Duplicate tenant name: ${tenantName}`);
    }
    tenantNames.add(tenantName.toLowerCase());

    if (!Array.isArray(tenant.accounts)) {
      fail(`Tenant ${tenantName} is missing an accounts array`);
    }

    const accountIds = new Set();
    const defaults = tenant.defaults && typeof tenant.defaults === "object" ? tenant.defaults : {};

    const normalizedAccounts = tenant.accounts.map((account, accountIndex) => {
      if (!account || typeof account !== "object") {
        fail(`Account entry ${accountIndex} for tenant ${tenantName} must be an object`);
      }

      const provider = typeof account.provider === "string" ? account.provider.trim().toLowerCase() : "";
      if (!provider) {
        fail(`Account entry ${accountIndex} for tenant ${tenantName} is missing provider`);
      }

      const accountName = derivedAccountName(account, accountIndex);
      const dedupeKey = provider;
      if (accountIds.has(dedupeKey)) {
        fail(`Duplicate provider ${provider} in tenant ${tenantName}. Each tenant/provider pair must be unique.`);
      }
      accountIds.add(dedupeKey);

      const env = flattenAccountEnv(account, provider);

      return {
        raw: account,
        tenant: tenantName,
        provider,
        account: accountName,
        enabled: account.enabled !== false,
        default: account.default === true,
        description: typeof account.description === "string" ? account.description.trim() : "",
        env,
      };
    });

    return {
      raw: tenant,
      tenant: tenantName,
      defaults,
      accounts: normalizedAccounts,
    };
  });

  return {
    schemaVersion: profiles.schemaVersion,
    defaults: profiles.defaults,
    hasSchemaVersion: profiles.hasSchemaVersion === true,
    hasDefaults: profiles.hasDefaults === true,
    tenants: normalizedTenants,
    filePath: profiles.filePath,
    warnings,
  };
}

function flattenAccountEnv(account, provider) {
  const env = {};

  for (const [key, value] of Object.entries(account)) {
    if (RESERVED_ACCOUNT_KEYS.has(key)) {
      continue;
    }
    validateEnvKey(key);
    env[key] = stringifyEnvValue(value);
  }

  if (account.settings && typeof account.settings === "object") {
    for (const [key, value] of Object.entries(account.settings)) {
      validateEnvKey(key);
      env[key] = stringifyEnvValue(value);
    }
  }

  if (account.credentials && typeof account.credentials === "object") {
    for (const [key, value] of Object.entries(account.credentials)) {
      validateEnvKey(key);
      env[key] = stringifyEnvValue(value);
    }
  }

  applyProviderAliases(provider, env);
  return env;
}

function stringifyEnvValue(value) {
  if (value === null || value === undefined) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  return String(value);
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (String(value || "").trim()) {
      return String(value).trim();
    }
  }
  return "";
}

function isNonEmpty(value) {
  return String(value || "").trim() !== "";
}

function getContaboCredentialSet(env) {
  return {
    mcpApiKey: firstNonEmpty(env.CONTABO_MCP_API_KEY),
    accessToken: firstNonEmpty(env.CONTABO_ACCESS_TOKEN, env.ACCESS_TOKEN),
    clientId: firstNonEmpty(env.CONTABO_CLIENT_ID, env.CLIENT_ID),
    clientSecret: firstNonEmpty(env.CONTABO_CLIENT_SECRET, env.CLIENT_SECRET),
    apiUser: firstNonEmpty(env.CONTABO_API_USER, env.API_USER),
    apiPassword: firstNonEmpty(env.CONTABO_API_PASSWORD, env.API_PASSWORD),
  };
}

function applyProviderAliases(provider, env) {
  if (provider === "hostinger") {
    if (!env.API_TOKEN && env.HOSTINGER_API_TOKEN) {
      env.API_TOKEN = env.HOSTINGER_API_TOKEN;
    }
    if (!env.HOSTINGER_API_TOKEN && env.API_TOKEN) {
      env.HOSTINGER_API_TOKEN = env.API_TOKEN;
    }
    return;
  }

  if (provider === "contabo") {
    const credentials = getContaboCredentialSet(env);

    if (credentials.clientId) {
      env.CONTABO_CLIENT_ID = credentials.clientId;
      if (!env.CLIENT_ID) {
        env.CLIENT_ID = credentials.clientId;
      }
    }

    if (credentials.clientSecret) {
      env.CONTABO_CLIENT_SECRET = credentials.clientSecret;
      if (!env.CLIENT_SECRET) {
        env.CLIENT_SECRET = credentials.clientSecret;
      }
    }

    if (credentials.apiUser) {
      env.CONTABO_API_USER = credentials.apiUser;
      if (!env.API_USER) {
        env.API_USER = credentials.apiUser;
      }
    }

    if (credentials.apiPassword) {
      env.CONTABO_API_PASSWORD = credentials.apiPassword;
      if (!env.API_PASSWORD) {
        env.API_PASSWORD = credentials.apiPassword;
      }
    }

    if (credentials.accessToken) {
      env.CONTABO_ACCESS_TOKEN = credentials.accessToken;
      if (!env.ACCESS_TOKEN) {
        env.ACCESS_TOKEN = credentials.accessToken;
      }
    }
  }
}

function resolveSelection(normalizedProfiles, options) {
  const provider = (options.provider || "").trim().toLowerCase();
  if (!provider) {
    fail("resolve requires --provider");
  }

  const defaults = normalizedProfiles.defaults && typeof normalizedProfiles.defaults === "object"
    ? normalizedProfiles.defaults
    : {};

  const tenantSelector =
    options.tenant ||
    process.env.VPS_TENANT ||
    (typeof defaults.tenant === "string" ? defaults.tenant : "");

  let tenant;
  if (tenantSelector) {
    tenant = normalizedProfiles.tenants.find((entry) => entry.tenant === tenantSelector);
    if (!tenant) {
      fail(`Tenant not found: ${tenantSelector}`);
    }
  } else if (normalizedProfiles.tenants.length === 1) {
    tenant = normalizedProfiles.tenants[0];
  } else {
    fail(`Multiple tenants configured. Select one with VPS_TENANT or --tenant. Available: ${normalizedProfiles.tenants.map((entry) => entry.tenant).join(", ")}`);
  }

  const candidates = tenant.accounts.filter((entry) => entry.enabled && entry.provider === provider);
  if (candidates.length === 0) {
    fail(`No enabled ${provider} provider entry configured for tenant ${tenant.tenant}`);
  }

  const providerEnvKey = `VPS_${provider.toUpperCase().replace(/[^A-Z0-9]/g, "_")}_ACCOUNT`;
  const accountSelector =
    options.account ||
    process.env[providerEnvKey] ||
    (tenant.defaults.accounts && typeof tenant.defaults.accounts[provider] === "string" ? tenant.defaults.accounts[provider] : "") ||
    (defaults.accounts && typeof defaults.accounts[provider] === "string" ? defaults.accounts[provider] : "");

  let account;
  if (candidates.length === 1) {
    account = candidates[0];
  } else if (accountSelector) {
    account = candidates.find((entry) => entry.account === accountSelector);
    if (!account) {
      fail(`Legacy account selector ${accountSelector} not found for provider ${provider} in tenant ${tenant.tenant}`);
    }
  } else {
    const explicitDefault = candidates.find((entry) => entry.default);
    if (explicitDefault) {
      account = explicitDefault;
    } else {
      fail(`Multiple legacy ${provider} entries configured for tenant ${tenant.tenant}. Each tenant/provider pair must be unique.`);
    }
  }

  return {
    tenant: tenant.tenant,
    provider,
    account: account.account,
    env: {
      VPS_SELECTED_TENANT: tenant.tenant,
      VPS_SELECTED_PROVIDER: provider,
      ...account.env,
    },
  };
}

function shellEscape(value) {
  return `'${String(value).replace(/'/g, `'\"'\"'`)}'`;
}

function powerShellEscape(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function formatResolveOutput(result, format) {
  switch (format) {
    case "json":
      return JSON.stringify(result, null, 2);
    case "shell":
      return Object.entries(result.env)
        .map(([key, value]) => `export ${key}=${shellEscape(value)}`)
        .join("\n");
    case "powershell":
      return Object.entries(result.env)
        .map(([key, value]) => `$env:${key}=${powerShellEscape(value)}`)
        .join("\n");
    default:
      fail(`Unsupported resolve format: ${format}`);
  }
}

function listAccounts(normalizedProfiles, provider) {
  const wantedProvider = provider ? provider.trim().toLowerCase() : "";
  const defaults = normalizedProfiles.defaults && typeof normalizedProfiles.defaults === "object"
    ? normalizedProfiles.defaults
    : {};

  const rows = [];
  for (const tenant of normalizedProfiles.tenants) {
    for (const account of tenant.accounts) {
      if (!account.enabled) {
        continue;
      }
      if (wantedProvider && account.provider !== wantedProvider) {
        continue;
      }
      rows.push({
        tenant: tenant.tenant,
        provider: account.provider,
        defaultTenant: defaults.tenant === tenant.tenant,
        defaultAccount:
          (tenant.defaults.accounts && tenant.defaults.accounts[account.provider] === account.account) ||
          (defaults.accounts && defaults.accounts[account.provider] === account.account) ||
          account.default === true,
      });
    }
  }
  return rows;
}

function formatListOutput(rows, format) {
  switch (format) {
    case "json":
      return JSON.stringify(rows, null, 2);
    case "text":
      if (rows.length === 0) {
        return "No provider entries configured.";
      }
      return rows
        .map((row) => {
          const flags = [];
          if (row.defaultTenant) {
            flags.push("default-tenant");
          }
          return `${row.tenant}\t${row.provider}${flags.length ? `\t[${flags.join(", ")}]` : ""}`;
        })
        .join("\n");
    default:
      fail(`Unsupported list format: ${format}`);
  }
}

function validateProfiles(normalizedProfiles, format) {
  const defaults = normalizedProfiles.defaults && typeof normalizedProfiles.defaults === "object"
    ? normalizedProfiles.defaults
    : {};
  const rows = listAccounts(normalizedProfiles, null);
  const warnings = [];

  if (normalizedProfiles.tenants.length === 0) {
    warnings.push("No tenants configured.");
  }

  for (const tenant of normalizedProfiles.tenants) {
    for (const account of tenant.accounts) {
      const envValues = Object.values(account.env).map((value) => String(value || "").trim());
      const hasAnyValue = envValues.some((value) => value !== "");
      if (!hasAnyValue) {
        warnings.push(`Tenant ${tenant.tenant} / ${account.provider} has no non-empty credential or setting values.`);
        continue;
      }

      if (account.provider === "hostinger" && !String(account.env.API_TOKEN || account.env.HOSTINGER_API_TOKEN || "").trim()) {
        warnings.push(`Tenant ${tenant.tenant} / hostinger is missing API_TOKEN.`);
      }

      if (account.provider === "contabo") {
        const credentials = getContaboCredentialSet(account.env);
        const hasDirectCredentialSet =
          isNonEmpty(credentials.clientId) &&
          isNonEmpty(credentials.clientSecret) &&
          isNonEmpty(credentials.apiUser) &&
          isNonEmpty(credentials.apiPassword);

        if (!isNonEmpty(credentials.mcpApiKey) && !isNonEmpty(credentials.accessToken) && !hasDirectCredentialSet) {
          warnings.push(`Tenant ${tenant.tenant} / contabo is missing a usable Contabo credential set. Provide CONTABO_MCP_API_KEY, CONTABO_ACCESS_TOKEN, or CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD.`);
        }
      }
    }
  }

  const text = [
    `Profiles file: ${normalizedProfiles.filePath}`,
    `Schema version: ${normalizedProfiles.schemaVersion}`,
    `Tenants: ${normalizedProfiles.tenants.length}`,
    rows.length ? "Accounts:" : "Accounts: none",
    ...rows.map((row) => {
      const flags = [];
      if (row.defaultTenant) {
        flags.push("default-tenant");
      }
      if (row.defaultAccount) {
        flags.push("default-account");
      }
      return `- ${row.tenant} / ${row.provider}${flags.length ? ` [${flags.join(", ")}]` : ""}`;
    }),
    ...warnings.map((warning) => `Warning: ${warning}`),
  ].join("\n");

  if (format === "json") {
    return JSON.stringify(
      {
        file: normalizedProfiles.filePath,
        schemaVersion: normalizedProfiles.schemaVersion,
        tenants: normalizedProfiles.tenants.length,
        accounts: rows,
        warnings,
      },
      null,
      2,
    );
  }

  if (format === "text") {
    return text;
  }

  fail(`Unsupported validate format: ${format}`);
}

function buildWritableProfiles(existingProfiles) {
  if (!existingProfiles) {
    return { tenants: [] };
  }

  const profiles = {
    tenants: existingProfiles.tenants.map((tenant) => JSON.parse(JSON.stringify(tenant.raw || tenant))),
  };

  if (existingProfiles.hasSchemaVersion) {
    profiles.schemaVersion = existingProfiles.schemaVersion || 1;
  }

  if (existingProfiles.hasDefaults) {
    profiles.defaults = existingProfiles.defaults && typeof existingProfiles.defaults === "object"
      ? JSON.parse(JSON.stringify(existingProfiles.defaults))
      : { accounts: {} };
  }

  return profiles;
}

function applyWritableAccountName(account) {
  if (Object.prototype.hasOwnProperty.call(account, "account")) {
    delete account.account;
  }
  if (Object.prototype.hasOwnProperty.call(account, "name")) {
    delete account.name;
  }
}

function upsertAccount(options) {
  if (!options.tenant) {
    fail("upsert-account requires --tenant");
  }
  if (!options.provider) {
    fail("upsert-account requires --provider");
  }

  const provider = options.provider.trim().toLowerCase();
  const existing = readProfiles(options.file, true);
  const profiles = buildWritableProfiles(existing ? normalizeProfiles(existing) : null);

  let tenant = profiles.tenants.find((entry) => entry.tenant === options.tenant);
  if (!tenant) {
    tenant = {
      tenant: options.tenant,
      accounts: [],
    };
    profiles.tenants.push(tenant);
  }

  let account = tenant.accounts.find((entry) => entry.provider === provider);

  if (!account) {
    account = {
      provider,
      credentials: {},
      settings: {},
    };
    applyWritableAccountName(account);
    tenant.accounts.push(account);
  } else {
    if (!account.credentials || typeof account.credentials !== "object") {
      account.credentials = {};
    }
    if (!account.settings || typeof account.settings !== "object") {
      account.settings = {};
    }
    account.provider = provider;
    applyWritableAccountName(account);
  }

  for (const entry of options.credentials) {
    account.credentials[entry.key] = entry.value;
  }
  for (const entry of options.settings) {
    account.settings[entry.key] = entry.value;
  }

  if (options.makeDefault) {
    if (!profiles.defaults || typeof profiles.defaults !== "object") {
      profiles.defaults = { accounts: {} };
    }
    if (!profiles.defaults.accounts || typeof profiles.defaults.accounts !== "object") {
      profiles.defaults.accounts = {};
    }
    profiles.defaults.tenant = options.tenant;
    profiles.defaults.accounts[provider] = "primary";

    if (!tenant.defaults || typeof tenant.defaults !== "object") {
      tenant.defaults = { accounts: {} };
    }
    if (!tenant.defaults.accounts || typeof tenant.defaults.accounts !== "object") {
      tenant.defaults.accounts = {};
    }
    tenant.defaults.accounts[provider] = "primary";
  }

  fs.writeFileSync(options.file, `${JSON.stringify(profiles, null, 2)}\n`, "utf8");
  return JSON.stringify(
    {
      file: options.file,
      tenant: options.tenant,
      provider,
      makeDefault: options.makeDefault,
    },
    null,
    2,
  );
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  switch (args.command) {
    case "list": {
      const rawProfiles = readProfiles(args.file, args.optional);
      if (!rawProfiles) {
        process.stdout.write(args.format === "json" ? "[]\n" : "No provider entries configured.\n");
        return;
      }
      const normalized = normalizeProfiles(rawProfiles);
      const output = formatListOutput(listAccounts(normalized, args.provider), args.format || "text");
      process.stdout.write(`${output}\n`);
      return;
    }
    case "resolve": {
      const rawProfiles = readProfiles(args.file, args.optional);
      if (!rawProfiles) {
        if (args.format === "json") {
          process.stdout.write("{}\n");
          return;
        }
        return;
      }
      const normalized = normalizeProfiles(rawProfiles);
      const output = formatResolveOutput(resolveSelection(normalized, args), args.format || "json");
      if (output) {
        process.stdout.write(`${output}\n`);
      }
      return;
    }
    case "validate": {
      const rawProfiles = readProfiles(args.file, args.optional);
      if (!rawProfiles) {
        fail(`Profiles file not found: ${args.file}`);
      }
      const normalized = normalizeProfiles(rawProfiles);
      process.stdout.write(`${validateProfiles(normalized, args.format || "text")}\n`);
      return;
    }
    case "upsert-account": {
      process.stdout.write(`${upsertAccount(args)}\n`);
      return;
    }
    default:
      fail(`Unknown command: ${args.command}`);
  }
}

main();
