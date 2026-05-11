---
name: notion-skills
description: Route Notion work to the right bundled sub-skill. Use when the user asks Codex to work with Notion for knowledge capture, meeting preparation, research documentation, or turning specs into implementation plans and tasks.
---

# Notion Skills

Use this skill as a router for the Notion sub-skills in this folder. Select the smallest matching sub-skill, read its `SKILL.md`, then follow it for the task.

## Routing

- **Knowledge capture**: Read `knowledge-capture/SKILL.md` when turning conversations, meeting notes, discussions, decisions, or raw notes into structured Notion documentation.
- **Meeting intelligence**: Read `meeting-intelligence/SKILL.md` when preparing agendas, pre-reads, attendee context, meeting briefs, or follow-up materials.
- **Research documentation**: Read `research-documentation/SKILL.md` when researching a topic and synthesizing findings, sources, comparisons, or reports into Notion.
- **Spec to implementation**: Read `spec-to-implementation/SKILL.md` when converting PRDs, specs, requirements, or feature plans into implementation plans, tasks, milestones, or progress tracking.

## Workflow

1. Identify the user's primary Notion outcome.
2. Read only the matching sub-skill first.
3. If the task spans multiple outcomes, use the sub-skills in workflow order:
   - `research-documentation` for background research
   - `meeting-intelligence` for meeting preparation
   - `knowledge-capture` for documenting outcomes
   - `spec-to-implementation` for turning decisions into tracked work
4. Prefer existing Notion connectors or MCP/app tools when available. If direct Notion writes are requested, confirm the target page or database unless the user already provided it.
5. Keep generated Notion content structured and action-oriented: clear title, context, sections, decisions, owners, dates, links, and next steps where relevant.

## Safety

Before creating or updating Notion pages, verify the target workspace/page/database and avoid overwriting existing content without reading the current version first.
