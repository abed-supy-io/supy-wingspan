# Changelog

## [0.1.2](https://github.com/abed-supy-io/supy-wingspan/compare/supy-wingspan-v0.1.1...supy-wingspan-v0.1.2) (2026-07-16)


### Features

* migrate supy-mobile AI-coding skills into the plugin, stack-scoped ([#9](https://github.com/abed-supy-io/supy-wingspan/issues/9)) ([824a5b4](https://github.com/abed-supy-io/supy-wingspan/commit/824a5b4e631d83d6d97fc0ec37b1a16384ff9438))

## [0.1.1](https://github.com/abed-supy-io/supy-wingspan/compare/supy-wingspan-v0.1.0...supy-wingspan-v0.1.1) (2026-07-16)


### Features

* add ai-agents stack asset set + wiring ([f9932ef](https://github.com/abed-supy-io/supy-wingspan/commit/f9932ef8d415e1c28cd1513deb6511d698977c8a))
* add Angular frontend (angular-nx) support to supy-wingspan ([f5b3a55](https://github.com/abed-supy-io/supy-wingspan/commit/f5b3a55da896997338e27965653e7657069968d1))
* add backend review subagents (architecture, nats, tests, commit/pr, security) ([224f3b1](https://github.com/abed-supy-io/supy-wingspan/commit/224f3b18cb3196749d5bad31aab2aee53e7a1de5))
* add clean-architecture/DDD backend support to supy-wingspan ([c3378f3](https://github.com/abed-supy-io/supy-wingspan/commit/c3378f3ff00af567792475831f1c01ca4e262990))
* add cross-cutting CI/coverage/pre-commit baseline standard ([4f8d078](https://github.com/abed-supy-io/supy-wingspan/commit/4f8d078aecb75aed7ccaa34d3fa5cc524fa9dbf0))
* add detect-stack SessionStart hook ([ddb24b9](https://github.com/abed-supy-io/supy-wingspan/commit/ddb24b911ad70036755249464b759e982ccf34c0))
* add firebase-functions asset set (standard, reviewer, skill, templates) + wiring ([f37a947](https://github.com/abed-supy-io/supy-wingspan/commit/f37a9472c2ec2461a7ba1e900c038123ff0b2ef9))
* add Flutter mobile (flutter) support to supy-wingspan ([ecf19f8](https://github.com/abed-supy-io/supy-wingspan/commit/ecf19f8db7cc2c4021621f154e1f2c1f6fbc4e37))
* add git-workflow skills and extract shared stack-detection reference ([b19d0de](https://github.com/abed-supy-io/supy-wingspan/commit/b19d0de53cc6c64528b5f1b0a2bc64edeb1f1193))
* add orchestration command wrappers over superpowers ([b8d6dea](https://github.com/abed-supy-io/supy-wingspan/commit/b8d6deac0e4b9d8b3f14865b1d1e8d651f5d9f23))
* add secrets-and-config standard, secrets reviewer, and k8s-config stack ([b2312b9](https://github.com/abed-supy-io/supy-wingspan/commit/b2312b9a7326f4a7f27f2c17d8b29e62b347cc16))
* add supy-baseline consistency generator ([aa0f3de](https://github.com/abed-supy-io/supy-wingspan/commit/aa0f3de4fcbe06cbd932b779952f2cda00cc2f16))
* add supy-commit and supy-create-pr Git skills ([740d50a](https://github.com/abed-supy-io/supy-wingspan/commit/740d50ae6e6fa11129b80e8331b439b6d110cbee))
* add supy-review orchestration skill ([a469aad](https://github.com/abed-supy-io/supy-wingspan/commit/a469aad2680bcdfd71cb834c9300d0f32159b6cd))
* add supy-scaffold-handler skill ([6fda568](https://github.com/abed-supy-io/supy-wingspan/commit/6fda5687d019861655d4be1380cb251254d079ba))
* add ts-cli stack asset set + wiring ([ec95438](https://github.com/abed-supy-io/supy-wingspan/commit/ec95438a9466342f83c4279e5eeed346554db2a6))
* auto-route prompts to Supy skills (soft nudge) ([caf975f](https://github.com/abed-supy-io/supy-wingspan/commit/caf975f469f48efd31a67f964571ba210438cd10))
* extract Supy backend standards and CLAUDE.md template ([2e76f47](https://github.com/abed-supy-io/supy-wingspan/commit/2e76f47a2512a16c400c717faa2965dbb53e0421))
* make Flutter standards + reviewer profile-aware ([60cae35](https://github.com/abed-supy-io/supy-wingspan/commit/60cae3574096c62053016aad41cb94d335016882))
* reinforce frontend standards with saveToUrl rule + AG Grid/pagination snippets ([56a08f8](https://github.com/abed-supy-io/supy-wingspan/commit/56a08f88171ce6f43c8de9c77a39cfbf35ddd365))


### Bug Fixes

* **bootstrap:** strip remaining VGV Flutter vocab and add Supy license attribution ([4d4232b](https://github.com/abed-supy-io/supy-wingspan/commit/4d4232b92abdbd7e54ca0f43d53d415517757ac7))
* **ci:** add CI-flagged project words to cspell dictionary ([#6](https://github.com/abed-supy-io/supy-wingspan/issues/6)) ([503fac4](https://github.com/abed-supy-io/supy-wingspan/commit/503fac47ec244e439271912248cec87fbd78ff15))
* correct command/skill inventory in PILOT.md ([285c93e](https://github.com/abed-supy-io/supy-wingspan/commit/285c93ec2901cf920a82ca2a36404d6ae325e87b))
* correct scaffold-handler layout probe, remove trivial spec case, fix generator glob ([7f88bf6](https://github.com/abed-supy-io/supy-wingspan/commit/7f88bf652fb1afb21afce28e500dbd2e2c525111))
* resolve final whole-branch review findings ([2ea07e2](https://github.com/abed-supy-io/supy-wingspan/commit/2ea07e2f55a0872236be6484b224bd85d8894f8a))
* **review-agents:** ground checks in mined standards, fix contract format and false positives ([be465fc](https://github.com/abed-supy-io/supy-wingspan/commit/be465fccc150912817a4eb29d172ad1c99dd432f))
* **review-agents:** normalize residual security check-7 citation to (rule:) format ([65d33e4](https://github.com/abed-supy-io/supy-wingspan/commit/65d33e4e2a6808058694ddd262e2d098fe74aad0))
* **standards:** correct portal policy filename and clarify Cerbos deny-all rule ([e1f9a2d](https://github.com/abed-supy-io/supy-wingspan/commit/e1f9a2d8ce78165b6bf73e6af5e16cf3b5b7c06b))


### Documentation

* add E1 "prove it live" implementation plan ([a9fb9b6](https://github.com/abed-supy-io/supy-wingspan/commit/a9fb9b6a86d903e133da4223776d399247f8aafb))
* add E1–E4 enhancement roadmap design spec ([1b7ba6a](https://github.com/abed-supy-io/supy-wingspan/commit/1b7ba6afc8b24510fe26480207da96daa6942830))
* add pilot notes and validated local enablement steps ([3564f12](https://github.com/abed-supy-io/supy-wingspan/commit/3564f128f27b1f5d7cffdad9ce0c202a1e19a757))
* add repo analysis, usage guide, and per-stack synthesis ([761ad28](https://github.com/abed-supy-io/supy-wingspan/commit/761ad28fa6c921e62cda3c5d5acfbd34e766d166))
* enrich backend standards and reconcile Cerbos current-state vs target-state ([490e429](https://github.com/abed-supy-io/supy-wingspan/commit/490e429d289750d7642a7e201f1ab801fc6ed7d1))
* reconcile counts to 11 agents / 14 skills / 7 stacks + remove stale .gitkeep ([8bcc77f](https://github.com/abed-supy-io/supy-wingspan/commit/8bcc77f6c15a64f399c574dd678f2d2007799bc7))
* refresh README, add vgv-wingspan comparison, wire Cortex MCP ([e2e32c3](https://github.com/abed-supy-io/supy-wingspan/commit/e2e32c3637343370f8f0d1e6f8555b00a7a908d5))
* update installation instructions and status in README ([22e7948](https://github.com/abed-supy-io/supy-wingspan/commit/22e794822d9639eee4fb7d1a06971105cc650a20))

## Changelog

All notable changes to supy-wingspan are recorded here. This file is maintained
automatically by [release-please](https://github.com/googleapis/release-please) from
Conventional Commits — do not edit it by hand.
