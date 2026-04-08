# Security Rules

## Secrets & Credentials

- Never hardcode secrets, API keys, passwords, or tokens in code
- Use environment variables or `.env` files (gitignored)
- `.env.example` may contain placeholder values only
- No PII (personally identifiable information) in code or logs

## Input Validation

Validate at system boundaries only (user input, external APIs):

- Length limits
- Format validation (email, phone, URL)
- Type checking
- Whitelist over blacklist

Do not over-validate internal code paths or framework-guaranteed types.

## Output Encoding

- HTML: escape user-provided content before rendering
- SQL: use parameterized queries (SQLAlchemy handles this)
- Shell: never interpolate user input into shell commands

## Enforcement

These rules are enforced by hooks:
- `secret-scanner.sh` — blocks secrets in file writes (20+ patterns)
- `bash-guard.sh` — blocks destructive shell commands
- `docs-guard.sh` — blocks unauthorized docs/ modifications
- `push-gate.py` — blocks push without QA report
