#!/bin/bash
#
# PreToolUse Hook: Secret Scanner
# Detects sensitive patterns before writing/editing files
# Exit codes: 0 = safe, 2 = blocked
#

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PATTERNS=(
  # AWS
  'AKIA[0-9A-Z]{16}'
  # API Keys
  'sk-[a-zA-Z0-9]{48}'
  'ghp_[a-zA-Z0-9]{36}'
  'AIza[0-9A-Za-z_-]{35}'
  'sk_live_[0-9a-zA-Z]{24}'
  # Bot Tokens
  'xoxb-[0-9A-Za-z-]+'
  'xoxp-[0-9A-Za-z-]+'
  # Private Keys
  '-----BEGIN .* PRIVATE KEY-----'
  '-----BEGIN .* CERTIFICATE-----'
  # Database URLs with credentials
  '(postgres|mysql|mongodb|redis)://[^:]+:[^@]+@'
  # JWT Tokens
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'
  # Generic secrets
  '(?i)(password|secret|token|api_key|auth_token|access_token)\s*[=:]\s*["'"'"'][^"'"'"']{8,}["'"'"']'
  # Azure
  'DefaultEndpointsProtocol=https;AccountName='
  # SSH/RSA
  'BEGIN RSA PRIVATE KEY'
  'BEGIN EC PRIVATE KEY'
  'BEGIN OPENSSH PRIVATE KEY'
  # NPM Token
  '//registry.npmjs.org/:_authToken='
  # Docker Config
  '"auth"\s*:\s*"[a-zA-Z0-9+/=]{20,}"'
)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','unknown'))" \
  2>/dev/null || echo "unknown")

CONTENT=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',{}); \
   print(ti.get('content', ti.get('new_string', '')))" \
  2>/dev/null || echo "$INPUT")

# Allowlist: .env.example and test files (warning only)
IS_ALLOWLISTED=false
if [[ "$FILE_PATH" == *".env.example" ]] || [[ "$FILE_PATH" == *.test.* ]] || [[ "$FILE_PATH" == *_test.* ]]; then
  IS_ALLOWLISTED=true
fi

MATCHED=false
DETECTED_PATTERNS=()
for pattern in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -E -q -- "$pattern"; then
    MATCHED=true
    DETECTED_PATTERNS+=("$pattern")
  fi
done

if [[ "$MATCHED" == true ]]; then
  if [[ "$IS_ALLOWLISTED" == true ]]; then
    echo -e "${YELLOW}WARNING: Sensitive data pattern detected in $FILE_PATH (allowlisted)${NC}" >&2
    exit 0
  else
    echo -e "${RED}BLOCKED: Sensitive data pattern detected in $FILE_PATH${NC}" >&2
    echo -e "${RED}Remove secrets before proceeding.${NC}" >&2
    for pattern in "${DETECTED_PATTERNS[@]}"; do
      echo -e "${RED}  - $pattern${NC}" >&2
    done
    exit 2
  fi
fi

exit 0
