# Nyxx – NES Emulator in Zig
A minimal 6502 CPU emulator written in Zig.

## Overview
Nyxx is designed with clarity and modularity in mind. It targets the Ricoh 2A03 — a custom variant of the MOS 6502 used in the Nintendo Entertainment System (NES). This makes Nyxx suitable for building NES emulators, tools, or educational systems that simulate 8-bit era behavior.

## Pronunciation
Nyxx is pronounced **Nix** (`/nɪks/`), as in **Nyx**, the Greek goddess of the night. The name draws inspiration from Nyx and follows the tradition of Unix-like systems by appending an "x" to the end, forming Nyxx as a minimal, modern homage to classic systems.

## Requirements
This project only depends on Zig and can be built on any modern system.

- Zig version 0.14.0 
- LLVM version 19.1.3

Nyxx supports multiple frontend implementations. You can choose between:

- WebGL (via WASM export) For in-browser rendering
- SDL2 (tested with libsdl2 version 2.32.2) For native desktop display

The frontend can be selected at build time. The core emulator (CPU/PPU/etc.) remains platform-independent.

## Build & Run
Nyxx is built with [Zig](https://ziglang.org). You can compile and run it for both **native desktop** or **browser** environments.

### Native (SDL2 frontend)

To run with native SDL2 frontend:

```bash
zig build
./zig-out/bin/nyxx $PATH_TO_ROM_FILE
```

### WASM (WebGL frontend)
To compile for the web frontend:

```bash
zig build wasm
```

This produces a nyxx.wasm binary, which requires a JavaScript engine to run (e.g. [6502.city](https://github.com/keix/6502.city)).

## Documentation
Explore detailed docs and implementation notes on Notion:
[Project Nyxx](https://6502.notion.site/)

## Design Priorities
- Keep the codebase minimal, readable, and portable
- Avoid unnecessary abstraction; show the structure
- Export as a WASM runtime for live interaction
- Emulate the 6502 CPU with instruction-level accuracy

## License
This project is licensed under the MIT License. Copyright (c) 2025 Kei Sawamura a.k.a. keix
