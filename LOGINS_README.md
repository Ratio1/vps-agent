`logins/` is a local-only helper directory for per-machine SSH launcher scripts.

Rules:
- `logins/` stays untracked and gitignored.
- Keep one tenant folder per tenant, for example `logins/ratio1/` and `logins/aurelex/`.
- Generate one executable `.sh` file per VPS.
- Name scripts with a provider prefix to avoid collisions: `<provider>__<machine-name>.sh`.
- Each script should run the SSH command in this form:

```bash
ssh -i ~/.ssh/aidamian.pem root@<ip> "$@"
```

Notes:
- `root` is the default user for both Hostinger and Contabo in this local helper set.
- The target IPv4 should match the current provider inventory at generation time.
- Extra arguments passed to the script should be forwarded to `ssh`.
