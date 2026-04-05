"""Claude invocation wrapper: Agent SDK when available, CLI subprocess fallback.

Token-saving design:
- Prompts reference file paths instead of embedding content.
- Claude reads only the files it needs via its Read tool.
- Logs are streamed to separate files, not stored in state.
"""

from __future__ import annotations

import asyncio
import json
import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .config import DEFAULT_MODEL, DEFAULT_PERMISSION_MODE

log = logging.getLogger(__name__)

# Try importing Agent SDK
try:
    from claude_agent_sdk import ClaudeAgentOptions, query as sdk_query
    HAS_SDK = True
except ImportError:
    HAS_SDK = False


@dataclass
class RunResult:
    """Result of a Claude invocation."""
    exit_code: int
    result_text: str
    session_id: Optional[str] = None
    cost_usd: Optional[float] = None
    is_max_turns: bool = False
    num_turns: Optional[int] = None


async def resume_claude(
    session_id: str,
    prompt: str,
    cwd: Path,
    *,
    log_file: Optional[Path] = None,
    allowed_tools: Optional[list[str]] = None,
    model: str = DEFAULT_MODEL,
    permission_mode: str = DEFAULT_PERMISSION_MODE,
    max_turns: int = 30,
) -> RunResult:
    """Resume a previous Claude session with a continuation prompt (CLI only)."""
    cmd = [
        "claude", "-p", prompt,
        "--resume", session_id,
        "--output-format", "json",
        "--model", model,
        "--permission-mode", permission_mode,
    ]
    if max_turns:
        cmd.extend(["--max-turns", str(max_turns)])
    if allowed_tools:
        cmd.extend(["--allowedTools", ",".join(allowed_tools)])

    log.info("Resuming session %s in %s", session_id[:12], cwd)

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=str(cwd),
    )
    stdout, stderr = await proc.communicate()

    if log_file:
        with open(log_file, "a") as f:
            f.write(f"\n=== CONTINUATION (session {session_id[:12]}) ===\n")
            f.write(f"=== STDOUT ===\n{stdout.decode()}\n")
            if stderr:
                f.write(f"=== STDERR ===\n{stderr.decode()}\n")

    result_text = ""
    new_session_id = None
    cost_usd = None
    is_max_turns = False
    num_turns = None

    try:
        data = json.loads(stdout.decode())
        result_text = data.get("result", "")
        new_session_id = data.get("session_id", session_id)
        cost_usd = data.get("cost_usd")
        num_turns = data.get("num_turns")
        if data.get("is_error") and data.get("subtype") == "error_max_turns":
            is_max_turns = True
    except (json.JSONDecodeError, KeyError):
        result_text = stdout.decode()

    return RunResult(
        exit_code=proc.returncode or 0,
        result_text=result_text,
        session_id=new_session_id,
        cost_usd=cost_usd,
        is_max_turns=is_max_turns,
        num_turns=num_turns,
    )


async def run_claude(
    prompt: str,
    cwd: Path,
    *,
    log_file: Optional[Path] = None,
    allowed_tools: Optional[list[str]] = None,
    model: str = DEFAULT_MODEL,
    permission_mode: str = DEFAULT_PERMISSION_MODE,
    max_turns: int = 30,
    max_budget_usd: Optional[float] = None,
) -> RunResult:
    """Run Claude with the given prompt and return the result.

    Uses Agent SDK if available, otherwise falls back to CLI subprocess.
    """
    if HAS_SDK:
        return await _run_sdk(
            prompt, cwd,
            log_file=log_file,
            allowed_tools=allowed_tools,
            model=model,
            permission_mode=permission_mode,
            max_turns=max_turns,
        )
    else:
        return await _run_cli(
            prompt, cwd,
            log_file=log_file,
            allowed_tools=allowed_tools,
            model=model,
            permission_mode=permission_mode,
            max_turns=max_turns,
            max_budget_usd=max_budget_usd,
        )


async def _run_sdk(
    prompt: str,
    cwd: Path,
    **kwargs,
) -> RunResult:
    """Run Claude via Agent SDK."""
    from claude_agent_sdk import ClaudeAgentOptions, query as sdk_query

    options = ClaudeAgentOptions(
        cwd=str(cwd),
        model=kwargs.get("model", DEFAULT_MODEL),
        permission_mode=kwargs.get("permission_mode", DEFAULT_PERMISSION_MODE),
        max_turns=kwargs.get("max_turns", 30),
    )
    if kwargs.get("allowed_tools"):
        options.allowed_tools = kwargs["allowed_tools"]

    log_file = kwargs.get("log_file")
    log_handle = open(log_file, "w") if log_file else None
    result_text = ""

    try:
        async for message in sdk_query(prompt=prompt, options=options):
            text = str(message)
            if log_handle:
                log_handle.write(text + "\n")
            # Capture the last assistant text as result
            if hasattr(message, "content"):
                for block in message.content:
                    if hasattr(block, "text"):
                        result_text = block.text
    except Exception as e:
        log.error("SDK error: %s", e)
        if log_handle:
            log_handle.write(f"\nERROR: {e}\n")
        return RunResult(exit_code=1, result_text=str(e))
    finally:
        if log_handle:
            log_handle.close()

    return RunResult(exit_code=0, result_text=result_text)


async def _run_cli(
    prompt: str,
    cwd: Path,
    **kwargs,
) -> RunResult:
    """Run Claude via CLI subprocess (fallback)."""
    cmd = [
        "claude", "-p", prompt,
        "--output-format", "json",
        "--model", kwargs.get("model", DEFAULT_MODEL),
        "--permission-mode", kwargs.get("permission_mode", DEFAULT_PERMISSION_MODE),
    ]

    max_turns = kwargs.get("max_turns")
    if max_turns:
        cmd.extend(["--max-turns", str(max_turns)])

    allowed_tools = kwargs.get("allowed_tools")
    if allowed_tools:
        cmd.extend(["--allowedTools", ",".join(allowed_tools)])

    max_budget = kwargs.get("max_budget_usd")
    if max_budget:
        cmd.extend(["--max-budget-usd", str(max_budget)])

    log.info("Running CLI: claude -p '<prompt>' in %s", cwd)

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=str(cwd),
    )
    stdout, stderr = await proc.communicate()

    # Write log
    log_file = kwargs.get("log_file")
    if log_file:
        with open(log_file, "w") as f:
            f.write(f"=== STDOUT ===\n{stdout.decode()}\n")
            if stderr:
                f.write(f"=== STDERR ===\n{stderr.decode()}\n")

    # Parse JSON output
    result_text = ""
    session_id = None
    cost_usd = None
    is_max_turns = False
    num_turns = None

    try:
        data = json.loads(stdout.decode())
        result_text = data.get("result", "")
        session_id = data.get("session_id")
        cost_usd = data.get("cost_usd")
        num_turns = data.get("num_turns")
        # Detect max-turns error
        if data.get("is_error") and data.get("subtype") == "error_max_turns":
            is_max_turns = True
            log.warning("Max turns reached (session: %s)", session_id)
    except (json.JSONDecodeError, KeyError):
        result_text = stdout.decode()
        # Also check stderr for max turns indicator
        stderr_text = stderr.decode() if stderr else ""
        if "max" in stderr_text.lower() and "turn" in stderr_text.lower():
            is_max_turns = True

    return RunResult(
        exit_code=proc.returncode or 0,
        result_text=result_text,
        session_id=session_id,
        cost_usd=cost_usd,
        is_max_turns=is_max_turns,
        num_turns=num_turns,
    )
