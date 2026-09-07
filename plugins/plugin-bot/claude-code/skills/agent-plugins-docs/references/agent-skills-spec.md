# Agent Skills specification

> Verified against <https://agentskills.io/specification.md> — 2026-09-07

The portable `SKILL.md` contract. Every host that claims Agent Skills support reads this format; anything a host adds on top of it is that host's own layer, not this one.

## Directory structure

A skill is a directory containing at minimum a `SKILL.md` file:

```text
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
└── ...               # Any additional files or directories
```

`scripts/`, `references/` and `assets/` are conventions, not requirements. A skill directory may contain any files beyond the required `SKILL.md`.

- `scripts/` — executable code the agent runs. Self-contained or with documented dependencies, helpful error messages, graceful edge-case handling. Supported languages depend on the client.
- `references/` — documentation loaded on demand. Keep individual files focused; smaller files mean less context spent.
- `assets/` — static resources: templates, images, data files.

## Frontmatter

`SKILL.md` must open with YAML frontmatter, then a Markdown body.

| Field | Required | Constraints |
| :-- | :-- | :-- |
| `name` | Yes | Max 64 characters. Lowercase letters, numbers and hyphens only. Must not start or end with a hyphen. |
| `description` | Yes | Max 1024 characters. Non-empty. Describes what the skill does and when to use it. |
| `license` | No | License name or reference to a bundled license file. |
| `compatibility` | No | Max 500 characters. Environment requirements — intended product, system packages, network access. |
| `metadata` | No | Arbitrary key-value mapping (a map from string keys to string values). |
| `allowed-tools` | No | Space-separated string of pre-approved tools. Experimental. |

### `name` — the full constraint list

- Must be 1–64 characters.
- May only contain unicode lowercase alphanumeric characters (`a-z`, `0-9`) and hyphens (`-`).
- Must not start or end with a hyphen (`-`).
- **Must not contain consecutive hyphens (`--`).**
- **Must match the parent directory name.**

Invalid: `PDF-Processing` (uppercase), `-pdf` (leading hyphen), `pdf--processing` (consecutive hyphens).

The consecutive-hyphen rule and the directory-match rule are the two that get missed; neither is visible from the field's one-line description.

### `description`

Must be 1–1024 characters. Should describe both *what* the skill does and *when* to use it, and should include specific keywords that help agents identify relevant tasks.

Good: `Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs. Use when working with PDF documents or when the user mentions PDFs, forms, or document extraction.`

Poor: `Helps with PDFs.`

### `compatibility`

1–500 characters if present. Include it only when the skill has real environment requirements. Most skills do not need this field.

```yaml
compatibility: Designed for Claude Code (or similar products)
compatibility: Requires git, docker, jq, and access to the internet
compatibility: Requires Python 3.14+ and uv
```

### `metadata`

A map from string keys to string values. Clients use it to store properties the spec does not define. Keep key names reasonably unique to avoid conflicts.

```yaml
metadata:
  author: example-org
  version: "1.0"
```

### `allowed-tools`

A space-separated string of pre-approved tools. **Experimental** — support varies between agent implementations, so a skill that depends on it is not portable.

```yaml
allowed-tools: Bash(git:*) Bash(jq:*) Read
```

## Body content

There are no format restrictions on the Markdown body. Recommended sections: step-by-step instructions, examples of inputs and outputs, common edge cases.

The agent loads this entire file once it decides to activate the skill. Split longer content into referenced files.

## Progressive disclosure

Agents load skills progressively, pulling in detail only as the task calls for it:

1. **Metadata** (~100 tokens) — `name` and `description`, loaded at startup for every installed skill.
2. **Instructions** (**recommended under 5000 tokens**) — the full `SKILL.md` body, loaded when the skill activates.
3. **Resources** (as needed) — files under `scripts/`, `references/`, `assets/`, loaded only when required.

**Keep the main `SKILL.md` under 500 lines.** Move detailed reference material to separate files.

## File references

Use relative paths from the skill root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

**Keep file references one level deep from `SKILL.md`.** Avoid deeply nested reference chains — a reference that points at another reference that points at a third is a chain the agent will not follow reliably.

## Validation

```bash
skills-ref validate ./my-skill
```

The [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference library checks that the frontmatter is valid and follows all naming conventions.
