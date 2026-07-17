---
name: supy-kg
description: Connect to Supy's architecture knowledge graph through the Cortex MCP — find services, events, flows, endpoints, and cross-repo usage
user-invocable: true
allowed-tools:
  - mcp__claude_ai_Cortex__search_entities
  - mcp__claude_ai_Cortex__search_code
  - mcp__claude_ai_Cortex__list_entities
  - mcp__claude_ai_Cortex__get_entity
  - mcp__claude_ai_Cortex__search_relationships
  - mcp__claude_ai_Cortex__trace_implementation
  - mcp__claude_ai_Cortex__get_perspective
  - mcp__claude_ai_Cortex__get_repo_guide
  - mcp__claude_ai_Cortex__get_stats
  - mcp__claude_ai_Cortex__get_recent_changes
  - mcp__claude_ai_Cortex__find_symbol
  - mcp__claude_ai_Cortex__find_usages
  - mcp__claude_ai_Cortex__get_dto_usage
  - mcp__claude_ai_Cortex__get_handler_contract
  - mcp__claude_ai_Cortex__get_event_schema
  - mcp__claude_ai_Cortex__get_context_for_file
  - mcp__claude_ai_Cortex__get_coding_rules
  - Read
  - Grep
  - Glob
---

# Supy Knowledge Graph (Cortex)

Supy's cross-repo architecture — services, endpoints, NATS patterns, events, discovered
business flows, and client→API mappings — is indexed in a knowledge graph served by the
**Cortex MCP**. This skill is the *connection*: it tells you the graph exists and which tool
answers which question. **Cortex owns the graph and its methodology** — treat the MCP as the
source of truth rather than re-deriving flows from source.

## Prerequisite

The **Cortex MCP** must be connected (tools prefixed `mcp__…Cortex__…`). If it is not, ask the
user to connect it; only then fall back to reading source directly with Grep/Glob as a degraded
mode. Do not restate Cortex's tracing procedure here — call the tools.

## When to reach for it

Any question that spans repos or asks "how does X actually work across the stack": which service
emits an event, who consumes a NATS pattern, what a DTO's shape is and who uses it, what an
endpoint chains into, or the full path of a business flow from client to audit trail.

## Question → tool

| You want… | Cortex MCP tool |
|---|---|
| Find entities by name/topic | `search_entities` (query + optional `group_id`) |
| Search code by content | `search_code` |
| Browse/list entities of a type | `list_entities` |
| Full entity details + relationships | `get_entity` |
| How two entities connect | `search_relationships` |
| Trace a symbol/pattern implementation | `trace_implementation` / `find_symbol` |
| Who calls / uses a symbol | `find_usages` |
| A DTO's shape and consumers | `get_dto_usage` |
| A NATS handler's contract | `get_handler_contract` |
| An event's payload schema | `get_event_schema` |
| Structured views (service graph, NATS map, endpoint→NATS chains, discovered-flows, client-api-map, frontend routes) | `get_perspective name=<view>` |
| Repo overview | `get_repo_guide` |
| Context for a specific file | `get_context_for_file` |
| Coding rules for an area | `get_coding_rules` |
| Counts / coverage | `get_stats` |
| What changed recently / graph freshness | `get_recent_changes` |

**Large perspectives:** for `client-api-map` and `endpoint-nats-chains`, always pass the `filter`
parameter to scope to one BFF (`supy-api-retailer`, `supy-api-mobile`, or `supy-api-admin`) — the
unfiltered dataset is too large to process accurately.

## Using it in a review or task

- Cite the tool behind each cross-repo claim (e.g. "From `get_handler_contract`: …"). Don't
  fabricate — if the graph doesn't have it, say so and fall back to source.
- For end-to-end flow tracing, deep validation, or updating the graph, that work lives in the
  Cortex repo — use its own skills/agents there rather than duplicating them here.
