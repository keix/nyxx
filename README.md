# Nyxx – A 6502 Emulator in Zig
A minimal 6502 CPU emulator written in Zig.

## Overview
Nyxx is designed with clarity and modularity in mind. It targets the Ricoh 2A03 — a custom variant of the MOS 6502 used in the Nintendo Entertainment System (NES). This makes Nyxx suitable for building NES emulators, tools, or educational systems that simulate 8-bit era behavior.

## Pronunciation
Nyxx is pronounced **Nix** (`/nɪks/`), as in **Nyx**, the Greek goddess of the night. The name draws inspiration from Nyx and follows the tradition of Unix-like systems by appending an "x" to the end, forming Nyxx as a minimal, modern homage to classic systems.

## Environment

This project was developed and tested under the following environment:

- Gentoo Linux 6.12.21
- LLVM version 19.1.3
- Zig version 0.14.0 (self-hosted from stage3)

## Documentation
Explore detailed docs and implementation notes on Notion:
[Project Nyxx](https://6502.notion.site/)

## Goals (This is a work in progress)
- Accurate emulation of 6502 CPU behavior
- Minimal codebase with educational clarity
- Build toward a complete NES-compatible emulator
- Exportable to WASM for web integration

## License
This project is licensed under the MIT License. Copyright (c) 2025 Kei Sawamura a.k.a. keix
