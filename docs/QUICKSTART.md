# Vaalin Development Quickstart

## 🚀 Getting Started

All tasks from `docs/tasks.md` have been converted to **93 GitHub issues**.

### Key Links

- **Issues**: https://github.com/TrevorS/vaalin/issues
- **Project Board**: https://github.com/users/TrevorS/projects/3
- **Task Summary**: `docs/github-issues-summary.md`

## 🎯 Where to Start

### MVP (Minimum Viable Product) - 32 Issues

To get a working MUD client, complete these phases in order:

1. **Foundation** (#1-5) - 5 issues
   - Set up Xcode project
   - Define core data models
   - Create event bus

2. **Phase 1** (#6-20) - 15 issues
   - Implement XML parser
   - Build network layer
   - Create basic UI
   - ✅ **Checkpoint**: End-to-end integration test

3. **Phase 2** (#21-32) - 12 issues
   - Add ANSI color rendering
   - Build command input system
   - Implement game log
   - ✅ **Checkpoint**: Fully playable game

## 📊 Full Feature Development

After MVP, continue with:

4. **Phase 3** (#33-47) - HUD Panels
5. **Phase 4** (#48-58) - Stream Filtering
6. **Phase 5** (#59-71) - Advanced Features (highlighting, macros, search)
7. **Phase 6** (#72-86) - Polish & Distribution
8. **Testing** (#87-93) - Test Infrastructure

## 🏷️ Label System

### Finding Issues

```bash
# View all parser-related issues
gh issue list --label "component:parser"

# View all checkpoints
gh issue list --label "type:checkpoint"

# View small, quick wins
gh issue list --label "complexity:small"

# View Phase 1 issues
gh issue list | grep "P1-"
```

### Component Labels

- `component:parser` - XML parsing logic
- `component:network` - TCP connection to Lich
- `component:core` - Shared models and utilities
- `component:ui` - SwiftUI views
- `component:panels` - HUD panels (vitals, hands, etc.)
- `component:streams` - Stream filtering
- `component:advanced` - Item highlighting, macros
- `component:polish` - Accessibility, themes
- `component:distribution` - Release preparation
- `component:testing` - Tests and CI

### Type Labels

- `type:feature` - New functionality
- `type:test` - Test implementation
- `type:checkpoint` - Integration milestone ⚠️
- `type:research` - Investigation task
- `type:documentation` - Docs

### Complexity Labels

- `complexity:small` - < 4 hours (quick wins)
- `complexity:medium` - 4-16 hours
- `complexity:large` - > 16 hours (checkpoints, integration)

## ⚠️ Important Checkpoints

**Do not skip checkpoints!** These ensure integration works before moving forward:

- #20: Phase 1 - Parser + Network + Basic UI
- #32: Phase 2 - Playable Game
- #47: Phase 3 - All HUD Panels Working
- #58: Phase 4 - Stream Filtering
- #71: Phase 5 - Advanced Features
- #86: Phase 6 - Production Ready

## 🔗 Dependencies

Issues are linked using "Blocks" relationships. Check the "Blocks" and "Blocked by" sections in each issue to understand dependencies.

## 📝 Issue Structure

Each issue contains:

- **Description** - What to build
- **Acceptance Criteria** - ✅ Task list of requirements
- **Implementation Approach** - TDD, new feature, refactor, etc.
- **Required Components** - Files to create/modify
- **Test Requirements** - Tests to write
- **Dependencies** - Blocking issues
- **Reference** - requirements.md line numbers

## 💡 Development Tips

1. **Start with #1** - Create Xcode Project Structure
2. **Follow TDD** - Write tests first when indicated
3. **Complete checkpoints** - Don't skip integration tests
4. **Track progress** - Update issue status as you work
5. **Reference Illthorn** - Use `/Users/trevor/Projects/illthorn` for examples

## 📚 Documentation

- `docs/requirements.md` - Full requirements specification
- `docs/tasks.md` - Original task breakdown (source)
- `docs/github-issues-summary.md` - This conversion summary

## 🎯 Next Action

Ready to start? Open issue #1:

```bash
gh issue view 1
```

Or view the project board:

```bash
open https://github.com/users/TrevorS/projects/3
```

Happy coding! 🚀
