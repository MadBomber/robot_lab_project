# RobotLab Project

Research into an extensions-based community of robots (aka agents) built on top of the [RubyLLM](https://rubyllm.com) framework. This work explores multi-robot orchestration, inter-agent communication protocols, and persistent agent memory — production use is not intended as a design goal.

## Prerequisites

Install the required CLI tools via Homebrew:

```sh
brew install direnv just
```

Add the `direnv` hook to your shell profile if you haven't already — see the [direnv setup guide](https://direnv.net/docs/hook.html).

## Local Development Setup

Clone this workspace repository, then let `just` pull in all the individual gem repos:

```sh
git clone https://github.com/MadBomber/robot_lab_project.git
cd robot_lab_project
direnv allow
just clone
```

`direnv allow` loads `.envrc`, which tells `just` to look for `robot_lab_project.just` instead of the default `justfile`. `just clone` then clones the core gem and all extensions into the working directory.

Run `just` with no arguments at any time to see all available workspace tasks.

## Core Gem

| Gem | Description |
|-----|-------------|
| [robot_lab](https://github.com/MadBomber/robot_lab) | Core framework — robots, networks, MCP integration, memory, and streaming |

## Extensions

| Gem | Description |
|-----|-------------|
| [robot_lab-a2a](https://github.com/MadBomber/robot_lab-a2a) | Exposes robots and networks as agents over the Agent2Agent (A2A) HTTP+SSE protocol |
| [robot_lab-document_store](https://github.com/MadBomber/robot_lab-document_store) | Vector embeddings and semantic search using fastembed with a TF-IDF fallback |
| [robot_lab-durable](https://github.com/MadBomber/robot_lab-durable) | Persistent cross-session learning and memory for robots |
| [robot_lab-ractor](https://github.com/MadBomber/robot_lab-ractor) | CPU-parallel robot execution via Ruby Ractors |
| [robot_lab-rails](https://github.com/MadBomber/robot_lab-rails) | Rails integration — ActiveJob, generators, and Turbo Stream callbacks |
