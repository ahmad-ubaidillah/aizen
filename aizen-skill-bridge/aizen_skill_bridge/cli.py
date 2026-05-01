"""CLI for Aizen Skill Bridge."""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path

from .loader import discover_skills, find_skills_by_trigger, parse_skill_file
from .registry import get_registry, init_registry


def main() -> int:
    import argparse
    
    parser = argparse.ArgumentParser(prog="aizen-skill", description="Aizen Skill Bridge CLI")
    sub = parser.add_subparsers(dest="command")
    
    # List skills
    p_list = sub.add_parser("list", help="List all discovered skills")
    p_list.add_argument("--category", help="Filter by category")
    p_list.add_argument("--trigger", help="Filter by trigger match")
    p_list.add_argument("--json", action="store_true", help="JSON output")
    
    # Show skill
    p_show = sub.add_parser("show", help="Show skill details")
    p_show.add_argument("name", help="Skill name")
    
    # Reload registry
    p_reload = sub.add_parser("reload", help="Reload skill registry from disk")
    
    # Stats
    p_stats = sub.add_parser("stats", help="Show skill registry statistics")
    p_stats.add_argument("--json", action="store_true", help="JSON output")
    
    args = parser.parse_args()
    
    skills_dir = os.environ.get("AIZEN_SKILL_PATH", str(Path("~/.aizen/skills").expanduser()))
    
    if args.command == "list":
        if args.category:
            skills = get_registry(skills_dir).by_category(args.category)
        elif args.trigger:
            skills = get_registry(skills_dir).find(args.trigger)
        else:
            skills = get_registry(skills_dir).all()
        
        if args.json:
            print(json.dumps([{"name": s.name, "category": s.category, "triggers": s.triggers} for s in skills], indent=2))
        else:
            if not skills:
                print("No skills found.")
            for s in skills:
                print(f"  {s.name} [{s.category}] - {s.description}")
                if s.triggers:
                    print(f"    triggers: {', '.join(s.triggers)}")
    
    elif args.command == "show":
        skill = get_registry(skills_dir).get(args.name)
        if not skill:
            print(f"Skill not found: {args.name}", file=sys.stderr)
            return 1
        print(json.dumps({
            "name": skill.name,
            "version": skill.version,
            "category": skill.category,
            "description": skill.description,
            "triggers": skill.triggers,
            "toolsets": skill.toolsets,
            "path": skill.path,
        }, indent=2))
        print("\n--- Skill Body ---")
        print(skill.body[:500])
        if len(skill.body) > 500:
            print("... [truncated]")
    
    elif args.command == "reload":
        reg = init_registry(skills_dir) if "--force" in sys.argv else get_registry(skills_dir)
        result = reg.reload()
        print(json.dumps(result))
    
    elif args.command == "stats":
        reg = get_registry(skills_dir)
        stats = reg.stats()
        if args.json:
            print(json.dumps(stats, indent=2, default=str))
        else:
            print(f"Total skills: {stats['total_skills']}")
            print(f"Total calls: {stats['total_calls']}")
            print(f"Success rate: {stats['success_rate']}")
    
    else:
        parser.print_help()
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())