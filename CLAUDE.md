# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace Overview

This directory is the **RobotLab project workspace** — a collection of 7 closely related Ruby gems that together form the RobotLab multi-robot LLM framework. Each subdirectory is an independent git repo with its own Gemfile, gemspec, tests, and `CLAUDE.md`.

| Repo | Purpose |
|------|---------|
| `robot_lab` | Core framework: robots, networks, MCP, memory |
| `robot_lab-a2a` | Agent2Agent (A2A) protocol adapter over HTTP+SSE |
| `robot_lab-document_store` | Vector embeddings & semantic search (fastembed + TF-IDF fallback) |
| `robot_lab-durable` | Cross-session persistent learning |
| `robot_lab-ractor` | CPU parallelism via Ractors |
| `robot_lab-rails` | ActiveJob, generators, Turbo broadcasts for Rails apps |

When working inside a specific sub-repo, that sub-repo's `CLAUDE.md` takes precedence.

## Common Commands (run inside a sub-repo)

```bash
bundle exec rake test              # All tests with SimpleCov coverage gates
bundle exec rake test_verbose      # Verbose test output
bundle exec rake test_file[path]   # Single test file (robot_lab core)
ruby -Ilib:test test/some_test.rb  # Single test (extension gems)
bundle exec rake integration       # Integration tests only (robot_lab core)
bundle exec rubocop                # Lint
bundle exec rubocop -a             # Auto-fix lint
bundle exec rake quality           # All gates: tests + coverage + rubocop + flog
bin/console                        # IRB shell with gem loaded
```

Coverage thresholds enforced in CI: **95% line, 75% branch**. Flog gates: warn ≥20, fail ≥50 per method.

## Architecture: How the Gems Relate

```
robot_lab  (core)
  ├── robot_lab-rails         depends on robot_lab
  ├── robot_lab-durable       depends on robot_lab
  ├── robot_lab-ractor        depends on robot_lab
  ├── robot_lab-document_store  depends on robot_lab
  └── robot_lab-a2a           depends on robot_lab + simple_a2a
```

Extension gems register themselves at load time via `RobotLab.register_extension`. During cross-gem development, `Gemfile` in extension repos points to the local `robot_lab` path via `gem "robot_lab", path: "../robot_lab"`.

## robot_lab Core Architecture

- **`RobotLab.build()`** / **`RobotLab.create_network()`** — primary factory methods
- **`Robot`** — subclasses `RubyLLM::Agent`; wraps a persistent chat, template-based prompts, tools, MCP clients, and a memory store. Use `robot.run("...")` to interact
- **`Network`** — orchestrates multiple robots sequentially with a routing lambda (`->(args) { [...robot_names...] or nil }`)
- **`RunConfig`** — configuration cascade: global → network → robot → template front matter → task → runtime. Merge semantics: more-specific wins
- **`Memory`** — key-value store with reserved keys (`:data`, `:results`, `:messages`, `:session_id`, `:cache`); optional Redis backend
- **`Tool`** — base class for robot capabilities; exceptions are caught and returned as text to the LLM by default

### Template Format

Templates are `.md` files with YAML front matter in the configured prompts directory:

```markdown
---
description: A helpful assistant
parameters:
  company_name: null   # null = required
  tone: friendly
model: claude-sonnet-4
temperature: 0.7
---
You are a helpful assistant for <%= company_name %>.
```

Front matter LLM keys (`model`, `temperature`, `top_p`, etc.) and `tools`/`mcp` lists are all supported. Constructor-provided values always override front matter.

## Key Configuration

Config cascades from `defaults.yml` → `~/.config/robot_lab/config.yml` → `./config/robot_lab.yml` → env vars (`ROBOT_LAB_*`, double underscore for nesting) → constructor params.

LLM API keys are passed as env vars per provider (e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`).

## Extension Gem Patterns

- **robot_lab-a2a**: Adapts `RobotLab::Robot` / `RobotLab::Network` to the A2A HTTP+SSE protocol. Two adapter modes: `:acp_tool` (injects `AskUserTool` for multi-turn input) and `:io_bridge` (replaces I/O streams). Supersedes the retired `robot_lab-acp` gem.
- **robot_lab-document_store**: `RobotLab::DocumentStore` — add documents, query by semantic similarity. Uses fastembed when available, falls back to TF-IDF cosine
- **robot_lab-durable**: Persistence layer for robot memory and learned behaviors across sessions
- **robot_lab-ractor**: `RobotLab::RactorPool` for CPU-parallel robot execution; configured via `ractor_pool_size` in RunConfig
