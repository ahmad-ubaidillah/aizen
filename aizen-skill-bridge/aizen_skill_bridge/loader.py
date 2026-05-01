"""SKILL.md parser — Hermes-compatible skill file format loader.

Skill files use YAML frontmatter + Markdown body:
    ---
    name: my-skill
    version: 1.0.0
    category: devops
    description: "Deploy to production"
    triggers:
      - deploy
      - release
    toolsets:
      - terminal
      - web
      - file
    ---
    # My Skill
    
    Steps:
    1. Run tests
    2. Build binary
    3. Deploy to server
"""

from __future__ import annotations

import os
import re
import yaml
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class Skill:
    """Parsed skill from SKILL.md file."""
    name: str
    version: str = "0.1.0"
    category: str = "general"
    description: str = ""
    triggers: list[str] = field(default_factory=list)
    toolsets: list[str] = field(default_factory=list)
    body: str = ""
    path: str = ""
    raw_frontmatter: dict[str, Any] = field(default_factory=dict)
    
    def matches_trigger(self, query: str) -> bool:
        """Check if any trigger matches the query (case-insensitive)."""
        q = query.lower()
        return any(t.lower() in q for t in self.triggers)
    
    def matches_category(self, category: str) -> bool:
        """Check if skill belongs to a category."""
        return self.category.lower() == category.lower()


# Regex to extract YAML frontmatter from markdown
FRONTMATTER_RE = re.compile(
    r"^---\s*\n(.*?)\n---\s*\n(.*)",
    re.DOTALL,
)


def parse_skill_file(path: str | Path) -> Skill | None:
    """Parse a SKILL.md file and return a Skill object.
    
    Args:
        path: Path to the SKILL.md file.
        
    Returns:
        Skill object if parsing succeeds, None if the file is invalid.
    """
    path = Path(path)
    if not path.exists():
        return None
    
    content = path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(content)
    
    if not match:
        # No frontmatter — try to parse as plain skill
        return Skill(
            name=path.stem,
            body=content,
            path=str(path),
        )
    
    frontmatter_str = match.group(1)
    body = match.group(2).strip()
    
    try:
        meta = yaml.safe_load(frontmatter_str)
    except yaml.YAMLError:
        return None
    
    if not isinstance(meta, dict):
        return None
    
    return Skill(
        name=meta.get("name", path.stem),
        version=str(meta.get("version", "0.1.0")),
        category=meta.get("category", "general"),
        description=meta.get("description", ""),
        triggers=meta.get("triggers", []),
        toolsets=meta.get("toolsets", []),
        body=body,
        path=str(path),
        raw_frontmatter=meta,
    )


def discover_skills(skills_dir: str | Path) -> list[Skill]:
    """Discover all SKILL.md files in a directory tree.
    
    Args:
        skills_dir: Root directory to scan for skills.
        
    Returns:
        List of parsed Skill objects.
    """
    skills_dir = Path(skills_dir)
    if not skills_dir.exists():
        return []
    
    skills: list[Skill] = []
    
    for root, _dirs, files in os.walk(skills_dir):
        for f in files:
            if f == "SKILL.md":
                skill_path = Path(root) / f
                skill = parse_skill_file(skill_path)
                if skill:
                    skills.append(skill)
    
    return skills


def find_skill_by_name(skills_dir: str | Path, name: str) -> Skill | None:
    """Find a skill by exact name.
    
    Args:
        skills_dir: Root directory to scan.
        name: Skill name to search for.
        
    Returns:
        Skill object if found, None otherwise.
    """
    for skill in discover_skills(skills_dir):
        if skill.name == name:
            return skill
    return None


def find_skills_by_trigger(skills_dir: str | Path, query: str) -> list[Skill]:
    """Find skills matching a trigger query.
    
    Args:
        skills_dir: Root directory to scan.
        query: Search query to match against triggers.
        
    Returns:
        List of matching Skill objects.
    """
    return [s for s in discover_skills(skills_dir) if s.matches_trigger(query)]


def find_skills_by_category(skills_dir: str | Path, category: str) -> list[Skill]:
    """Find skills in a specific category.
    
    Args:
        skills_dir: Root directory to scan.
        category: Category to filter by.
        
    Returns:
        List of matching Skill objects.
    """
    return [s for s in discover_skills(skills_dir) if s.matches_category(category)]