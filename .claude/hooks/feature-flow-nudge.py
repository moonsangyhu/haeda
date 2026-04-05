#!/usr/bin/env python3
"""UserPromptSubmit hook: nudge users toward /feature-flow for feature work.

Detects prompts that look like feature add/modify requests but were NOT
invoked via /feature-flow. Prints a reminder (does not block).

Exit 0 always — this is advisory only.
"""
import json
import re
import sys

# Patterns that suggest feature work (Korean + English)
_FEATURE_PATTERNS = [
    # Korean
    r"기능\s*(추가|구현|만들|생성|개발)",
    r"화면\s*(추가|구현|만들|생성|개발)",
    r"엔드포인트\s*(추가|구현|만들)",
    r"API\s*(추가|구현|만들)",
    r"(추가|구현|만들|생성).*해\s*줘",
    r"(추가|구현|만들|생성).*해\s*주세요",
    r"(수정|변경|고쳐|바꿔).*해\s*줘",
    r"(수정|변경|고쳐|바꿔).*해\s*주세요",
    r"새로운?\s*(스크린|위젯|페이지|라우터|모델)",
    r"(로그인|인증|챌린지|캘린더|인증샷|댓글|프로필).*구현",
    # English
    r"(?i)add\s+.*\b(feature|screen|endpoint|api|page|widget)\b",
    r"(?i)implement\s+.*\b(feature|screen|endpoint|api)\b",
    r"(?i)create\s+.*\b(feature|screen|endpoint|api|page)\b",
    r"(?i)build\s+.*\b(feature|screen|endpoint|api)\b",
    r"(?i)modify\s+.*\b(login|auth|challenge|calendar|verification)\b",
    r"(?i)change\s+.*\b(login|auth|challenge|calendar|verification)\b",
    r"(?i)fix\s+.*\b(login|auth|challenge|calendar|verification)\b.*flow",
]

# Prompts that are clearly NOT feature work (skip nudge)
_SKIP_PATTERNS = [
    r"^/",                      # Slash commands (already using a skill)
    r"(?i)^(commit|push|pull)", # Git operations
    r"(?i)^(explain|what|how|why|show|read|find|search|grep|list|check)",  # Questions/exploration
    r"(?i)^(test|lint|build|deploy|docker|make)",  # Build/test commands
    r"(?i)^(git |npm |flutter |uv |pip )",  # Direct tool commands
    r"(?i)^@",                  # Agent mentions
]


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    prompt = data.get("prompt", "").strip()
    if not prompt:
        sys.exit(0)

    # Skip if it's already a slash command or non-feature prompt
    for pat in _SKIP_PATTERNS:
        if re.search(pat, prompt):
            sys.exit(0)

    # Check if it looks like feature work
    for pat in _FEATURE_PATTERNS:
        if re.search(pat, prompt):
            print(
                "HINT: 이 작업은 /feature-flow 로 시작하세요.\n"
                "  예: /feature-flow " + prompt[:60] + ("..." if len(prompt) > 60 else "") + "\n"
                "\n"
                "/feature-flow는 요구사항 → plan → 구현 → QA → report → push 순서를 강제합니다."
            )
            sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
