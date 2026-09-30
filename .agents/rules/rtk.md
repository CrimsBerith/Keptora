# RTK - Rust Token Killer (CLI Proxy)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule
Always prefix shell commands with `rtk` when running bash/terminal commands to minimize token consumption.

Examples:
```bash
rtk git status
rtk git diff
rtk git log
rtk ls -la
rtk grep "pattern"
rtk rg "pattern"
rtk find . -name "*.swift"
rtk cargo test
rtk npm test
rtk pnpm test
rtk docker ps
rtk gh pr list
```

## Meta Commands
```bash
rtk gain              # Show token savings
rtk gain --history    # Command history with savings
rtk discover          # Find missed RTK opportunities
rtk proxy <cmd>       # Run raw (no filtering, for debugging)
```

## Why
RTK filters and compresses command outputs before they reach LLM context, reducing bash tokens by up to 90%. Always use `rtk <cmd>` instead of raw commands.
