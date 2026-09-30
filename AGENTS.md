# Keptora Xcode Project - Agent Configuration

## RTK (Rust Token Killer)
- Always prefix shell commands with `rtk` (e.g. `rtk xcodebuild`, `rtk swift test`, `rtk git status`, `rtk git diff`).
- RTK filters xcodebuild and compiler output to cut 90-99% of log tokens.
- Meta commands: `rtk gain`, `rtk gain --history`, `rtk discover`.

## Caveman Mode
- Respond terse and direct like smart caveman.
- Cut polite filler, preambles, and conversational fluff.
- Code blocks, Swift symbols, compiler diagnostics, and file paths remain 100% exact.
