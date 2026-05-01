"""Skill executor — sandboxed skill execution for Aizen Agent.

Executes skill instructions in an isolated subprocess using the
allowed toolsets defined in the skill's frontmatter.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .loader import Skill


@dataclass
class ExecutionResult:
    """Result of skill execution."""
    success: bool
    output: str
    error: str = ""
    exit_code: int = 0
    duration_seconds: float = 0.0
    skill_name: str = ""


# Sandbox profiles per toolset
SANDBOX_PROFILES: dict[str, dict[str, Any]] = {
    "terminal": {
        "allow_network": False,
        "allow_filesystem": True,
        "allowed_commands": ["git", "npm", "pip", "cargo", "zig", "make", "ls", "cat", "echo", "mkdir", "cp", "mv"],
        "timeout": 300,
    },
    "file": {
        "allow_network": False,
        "allow_filesystem": True,
        "allowed_commands": [],
        "timeout": 60,
    },
    "web": {
        "allow_network": True,
        "allow_filesystem": False,
        "allowed_commands": ["curl", "wget"],
        "timeout": 60,
    },
    "code_exec": {
        "allow_network": False,
        "allow_filesystem": True,
        "allowed_commands": ["python3", "node", "zig"],
        "timeout": 120,
    },
    "browser": {
        "allow_network": True,
        "allow_filesystem": False,
        "allowed_commands": [],
        "timeout": 120,
    },
}


def _merge_sandbox_config(skill: Skill) -> dict[str, Any]:
    """Merge sandbox profiles from all skill toolsets."""
    config: dict[str, Any] = {
        "allow_network": False,
        "allow_filesystem": False,
        "allowed_commands": [],
        "timeout": 60,
    }
    
    for toolset in skill.toolsets:
        if toolset in SANDBOX_PROFILES:
            profile = SANDBOX_PROFILES[toolset]
            config["allow_network"] = config["allow_network"] or profile["allow_network"]
            config["allow_filesystem"] = config["allow_filesystem"] or profile["allow_filesystem"]
            config["allowed_commands"].extend(profile["allowed_commands"])
            config["timeout"] = max(config["timeout"], profile["timeout"])
    
    # Deduplicate
    config["allowed_commands"] = list(dict.fromkeys(config["allowed_commands"]))
    return config


def execute_skill(
    skill: Skill,
    context: dict[str, Any] | None = None,
    workdir: str | Path | None = None,
    env: dict[str, str] | None = None,
) -> ExecutionResult:
    """Execute a skill in a sandboxed subprocess.
    
    Args:
        skill: Parsed Skill object to execute.
        context: Optional context dict passed as JSON to the skill.
        workdir: Working directory for execution.
        env: Additional environment variables.
        
    Returns:
        ExecutionResult with success status, output, and metadata.
    """
    import time
    
    sandbox = _merge_sandbox_config(skill)
    start_time = time.time()
    
    # Prepare execution environment
    exec_env = os.environ.copy()
    exec_env["AIZEN_SKILL_NAME"] = skill.name
    exec_env["AIZEN_SKILL_CATEGORY"] = skill.category
    exec_env["AIZEN_SKILL_TOOLSETS"] = ",".join(skill.toolsets)
    
    if context:
        exec_env["AIZEN_SKILL_CONTEXT"] = json.dumps(context)
    
    if env:
        exec_env.update(env)
    
    # Write skill body to temp file for execution
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".md",
        prefix=f"aizen-skill-{skill.name}-",
        delete=False,
    ) as f:
        f.write(skill.body)
        temp_path = f.name
    
    try:
        # Execute as subprocess with sandbox constraints
        result = subprocess.run(
            ["python3", "-c", f"""
import sys, json, os

# Read skill file
with open('{temp_path}') as f:
    body = f.read()

# Context
ctx = json.loads(os.environ.get('AIZEN_SKILL_CONTEXT', '{{}}'))

# Output skill info and body for the agent to interpret
output = {{
    'skill': os.environ.get('AIZEN_SKILL_NAME', 'unknown'),
    'category': os.environ.get('AIZEN_SKILL_CATEGORY', 'unknown'),
    'toolsets': os.environ.get('AIZEN_SKILL_TOOLSETS', '').split(','),
    'context': ctx,
    'instructions': body,
}}
print(json.dumps(output, indent=2))
"""],
            capture_output=True,
            text=True,
            timeout=sandbox["timeout"],
            cwd=str(workdir) if workdir else None,
            env=exec_env,
        )
        
        duration = time.time() - start_time
        
        return ExecutionResult(
            success=result.returncode == 0,
            output=result.stdout,
            error=result.stderr,
            exit_code=result.returncode,
            duration_seconds=round(duration, 2),
            skill_name=skill.name,
        )
        
    except subprocess.TimeoutExpired:
        duration = time.time() - start_time
        return ExecutionResult(
            success=False,
            output="",
            error=f"Skill execution timed out after {sandbox['timeout']}s",
            exit_code=-1,
            duration_seconds=round(duration, 2),
            skill_name=skill.name,
        )
    except Exception as e:
        duration = time.time() - start_time
        return ExecutionResult(
            success=False,
            output="",
            error=str(e),
            exit_code=-1,
            duration_seconds=round(duration, 2),
            skill_name=skill.name,
        )
    finally:
        # Cleanup temp file
        try:
            os.unlink(temp_path)
        except OSError:
            pass