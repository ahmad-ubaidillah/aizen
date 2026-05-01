"""Skill registry — hot-reload skill discovery and management for Aizen Agent.

Maintains an in-memory index of all discovered skills with support
for hot-reload on file changes (watch mode).
"""

from __future__ import annotations

import json
import logging
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from threading import Lock
from typing import Any

from .loader import Skill, discover_skills, find_skill_by_name, find_skills_by_trigger

logger = logging.getLogger(__name__)


@dataclass
class RegistryEntry:
    """Registry entry for a skill with metadata."""
    skill: Skill
    loaded_at: float = field(default_factory=time.time)
    file_mtime: float = 0.0
    call_count: int = 0
    success_count: int = 0
    total_duration: float = 0.0


class SkillRegistry:
    """In-memory skill registry with hot-reload support."""
    
    def __init__(self, skills_dir: str | Path | None = None):
        self.skills_dir = Path(skills_dir) if skills_dir else Path("~/.aizen/skills").expanduser()
        self._skills: dict[str, RegistryEntry] = {}
        self._lock = Lock()
        self._mtimes: dict[str, float] = {}
    
    def discover(self) -> list[Skill]:
        """Discover all skills in the skills directory."""
        return discover_skills(self.skills_dir)
    
    def reload(self) -> dict[str, Any]:
        """Reload all skills from disk.
        
        Returns:
            Summary dict with added, removed, and updated counts.
        """
        with self._lock:
            discovered = self.discover()
            discovered_names = {s.name for s in discovered}
            
            # Track current state
            current_names = set(self._skills.keys())
            
            added = discovered_names - current_names
            removed = current_names - discovered_names
            
            # Update mtimes and add new skills
            for skill in discovered:
                entry = self._skills.get(skill.name)
                path = Path(skill.path)
                mtime = path.stat().st_mtime if path.exists() else 0
                
                if skill.name in added:
                    self._skills[skill.name] = RegistryEntry(
                        skill=skill,
                        file_mtime=mtime,
                    )
                elif entry and mtime > entry.file_mtime:
                    # Hot reload: file changed
                    self._skills[skill.name] = RegistryEntry(
                        skill=skill,
                        file_mtime=mtime,
                        call_count=entry.call_count,
                        success_count=entry.success_count,
                        total_duration=entry.total_duration,
                    )
                    logger.info(f"Hot-reloaded skill: {skill.name}")
            
            # Remove deleted skills
            for name in removed:
                del self._skills[name]
            
            return {
                "total": len(self._skills),
                "added": len(added),
                "removed": len(removed),
                "updated": len(discovered_names) - len(added) - len(removed),
            }
    
    def get(self, name: str) -> Skill | None:
        """Get a skill by exact name."""
        with self._lock:
            entry = self._skills.get(name)
            return entry.skill if entry else None
    
    def find(self, query: str) -> list[Skill]:
        """Find skills matching a trigger query."""
        with self._lock:
            return [e.skill for e in self._skills.values() if e.skill.matches_trigger(query)]
    
    def by_category(self, category: str) -> list[Skill]:
        """Get all skills in a category."""
        with self._lock:
            return [e.skill for e in self._skills.values() if e.skill.matches_category(category)]
    
    def all(self) -> list[Skill]:
        """Get all registered skills."""
        with self._lock:
            return [e.skill for e in self._skills.values()]
    
    def record_execution(self, name: str, success: bool, duration: float) -> None:
        """Record skill execution for analytics."""
        with self._lock:
            entry = self._skills.get(name)
            if entry:
                entry.call_count += 1
                entry.total_duration += duration
                if success:
                    entry.success_count += 1
    
    def stats(self) -> dict[str, Any]:
        """Get registry statistics."""
        with self._lock:
            total_calls = sum(e.call_count for e in self._skills.values())
            total_success = sum(e.success_count for e in self._skills.values())
            return {
                "total_skills": len(self._skills),
                "total_calls": total_calls,
                "total_success": total_success,
                "success_rate": round(total_success / total_calls, 3) if total_calls > 0 else 0.0,
                "skills": {
                    name: {
                        "category": e.skill.category,
                        "calls": e.call_count,
                        "success": e.success_count,
                        "avg_duration": round(e.total_duration / e.call_count, 2) if e.call_count > 0 else 0,
                        "loaded_at": e.loaded_at,
                    }
                    for name, e in self._skills.items()
                },
            }


# Global registry instance
_registry: SkillRegistry | None = None


def get_registry(skills_dir: str | Path | None = None) -> SkillRegistry:
    """Get or create the global skill registry."""
    global _registry
    if _registry is None:
        _registry = SkillRegistry(skills_dir)
        _registry.reload()
    return _registry


def init_registry(skills_dir: str | Path | None = None) -> SkillRegistry:
    """Initialize the global registry."""
    global _registry
    _registry = SkillRegistry(skills_dir)
    _registry.reload()
    return _registry