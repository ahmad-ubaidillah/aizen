"""Tests for Aizen Skill Bridge."""
from pathlib import Path
from .loader import parse_skill_file, discover_skills, find_skill_by_name


SAMPLE_SKILL = """---
name: hello-world
version: 1.0.0
category: general
description: "A simple hello world skill"
triggers:
  - hello
  - greet
toolsets:
  - terminal
---
# Hello World

Simple greeting skill.
"""


def test_parse_skill(tmp_path):
    """Test parsing a SKILL.md file."""
    skill_file = tmp_path / "hello-world" / "SKILL.md"
    skill_file.parent.mkdir()
    skill_file.write_text(SAMPLE_SKILL)
    
    skill = parse_skill_file(skill_file)
    assert skill is not None
    assert skill.name == "hello-world"
    assert skill.version == "1.0.0"
    assert skill.category == "general"
    assert skill.description == "A simple hello world skill"
    assert "hello" in skill.triggers
    assert "greet" in skill.triggers
    assert "terminal" in skill.toolsets
    assert "Simple greeting skill" in skill.body


def test_discover_skills(tmp_path):
    """Test discovering skills in a directory."""
    for i, name in enumerate(["alpha", "beta"]):
        d = tmp_path / name
        d.mkdir()
        (d / "SKILL.md").write_text(f"""---
name: {name}
version: 0.1.{i}
category: test
triggers:
  - {name}
toolsets:
  - terminal
---
# {name.title()}
""")


def test_find_skill_by_name(tmp_path):
    """Test finding a skill by name."""
    d = tmp_path / "my-skill"
    d.mkdir()
    (d / "SKILL.md").write_text("""---
name: my-skill
category: test
triggers:
  - my
---
Content here.
""")
    
    skill = find_skill_by_name(tmp_path, "my-skill")
    assert skill is not None
    assert skill.name == "my-skill"


def test_matches_trigger():
    """Test trigger matching."""
    from .loader import Skill
    skill = Skill(
        name="test",
        triggers=["deploy", "release"],
    )
    assert skill.matches_trigger("deploy to prod")
    assert skill.matches_trigger("release v1")
    assert not skill.matches_trigger("hello world")