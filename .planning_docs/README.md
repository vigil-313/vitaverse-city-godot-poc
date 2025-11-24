# Planning Documentation - Bootstrap Guide

## 🎯 Purpose
This folder contains living documentation for the Vitaverse City enhancement project. It's designed to support multi-session development with fresh Claude Code contexts.

## 📋 For New Claude Code Sessions

### Quick Bootstrap Procedure

1. **Read this file first** to understand the structure
2. **Read `PROGRESS.md`** to see current status and next steps
3. **Read `DECISIONS.md`** to understand key technical decisions
4. **Read the relevant plan/** documents for implementation details
5. **Check the latest session log** in `sessions/` for recent context

### Starting a New Session

When starting work:
1. Create a new session log: `sessions/YYYY-MM-DD-session-XXX.md`
2. Update `PROGRESS.md` with current status
3. Mark tasks in progress
4. Begin work on next task from plan
5. Document all changes in session log
6. Update `PROGRESS.md` before ending session

## 📁 Folder Structure

```
.planning_docs/
├── README.md                    # This file - bootstrap guide
├── PROGRESS.md                  # Current status, what's next
├── DECISIONS.md                 # Key technical decisions & rationale
│
├── plan/
│   ├── overview.md              # High-level project plan
│   ├── phase-1-performance.md   # Performance fix details
│   └── phase-2-visuals.md       # Visual aesthetic details
│
├── performance/
│   ├── analysis.md              # Bottleneck analysis & profiling
│   ├── frame-budget-design.md   # LoadingQueue architecture
│   └── profiling/               # Profiling data, screenshots
│
├── visuals/
│   ├── native-lowres-architecture.md  # SubViewport design
│   ├── shader-design.md               # Palette + dithering shaders
│   ├── palettes/                      # Color palette references
│   └── references/                    # Visual inspiration
│
├── code/
│   ├── files-to-modify.md       # List of affected files
│   └── architecture-changes.md  # Before/after architecture
│
└── sessions/
    ├── 2025-01-23-session-001.md  # Session logs (dated)
    └── ...
```

## 🎨 Project Overview

**Goal:** Transform Vitaverse City into a retro PSX/Saturn-style 3D world with smooth performance.

**Two Main Objectives:**
1. **Fix Performance Stuttering** - Frame-budget queue system for chunk loading
2. **Hybrid Retro Aesthetic** - Native low-res rendering (480×360) + palette quantization + dithering

**Tech Stack:**
- Godot 4.5.1 (GDScript)
- OpenStreetMap data (South Lake Union, Seattle)
- Chunk-based streaming (500m chunks)
- Procedural mesh generation

## 🔧 Key Technical Decisions

See `DECISIONS.md` for full details:
- **Performance:** Frame-budget queue approach (not threading)
- **Visuals:** Native low-res SubViewport (not post-processing)
- **Resolution:** 480×360 default (configurable: 240p, 360p, 480p, 540p)
- **Palette:** 64 colors default (configurable: 32, 64, 256, custom)
- **All settings:** Runtime-adjustable via debug UI

## 📊 Current Phase

Check `PROGRESS.md` for up-to-date status.

**Phase 0:** Foundation & Documentation (current)
**Phase 1:** Performance Fix (next)
**Phase 2:** Visual Aesthetic (after Phase 1)

## 🚀 Quick Start Commands

```bash
# Check current progress
cat .planning_docs/PROGRESS.md

# View phase 1 plan
cat .planning_docs/plan/phase-1-performance.md

# View latest session
ls -lt .planning_docs/sessions/ | head -2
```

## 📝 Documentation Standards

When updating docs:
- Use clear markdown formatting
- Include file paths with line numbers (e.g., `chunk_manager.gd:369`)
- Mark checkboxes: `- [ ]` pending, `- [x]` done
- Date all entries
- Be specific and technical
- Include "why" not just "what"

## ⚠️ Important Notes

- This folder is gitignored (local only)
- Keep docs in sync with code changes
- Update PROGRESS.md frequently
- Session logs are historical record - don't modify old ones
- New sessions create new logs

---

Last Updated: 2025-01-23
Current Session: 001
