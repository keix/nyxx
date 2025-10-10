const std = @import("std");

pub const Mapper = struct {
    vtable: *const VTable,

    const VTable = struct {
        read: *const fn (ctx: *anyopaque, addr: u16) u8,
        write: *const fn (ctx: *anyopaque, addr: u16, value: u8) void,
        readCHR: *const fn (ctx: *anyopaque, addr: u16) u8,
        writeCHR: *const fn (ctx: *anyopaque, addr: u16, value: u8) void,
    };

    pub fn read(self: Mapper, ctx: *anyopaque, addr: u16) u8 {
        return self.vtable.read(ctx, addr);
    }

    pub fn write(self: Mapper, ctx: *anyopaque, addr: u16, value: u8) void {
        self.vtable.write(ctx, addr, value);
    }

    pub fn readCHR(self: Mapper, ctx: *anyopaque, addr: u16) u8 {
        return self.vtable.readCHR(ctx, addr);
    }

    pub fn writeCHR(self: Mapper, ctx: *anyopaque, addr: u16, value: u8) void {
        self.vtable.writeCHR(ctx, addr, value);
    }
};

// Mapper 0 (NROM)
pub const Mapper0 = struct {
    prg_rom: []u8,
    chr_rom: []u8,
    chr_ram: []u8,

    pub fn init(prg_rom: []u8, chr_rom: []u8, chr_ram: []u8) Mapper0 {
        return .{
            .prg_rom = prg_rom,
            .chr_rom = chr_rom,
            .chr_ram = chr_ram,
        };
    }

    pub fn mapper(_: *Mapper0) Mapper {
        return .{ .vtable = &vtable };
    }

    const vtable = Mapper.VTable{
        .read = read,
        .write = write,
        .readCHR = readCHR,
        .writeCHR = writeCHR,
    };

    fn read(ctx: *anyopaque, addr: u16) u8 {
        const self: *Mapper0 = @ptrCast(@alignCast(ctx));
        if (addr >= 0x8000) {
            const offset = if (self.prg_rom.len == 0x4000)
                (addr - 0x8000) & 0x3FFF
            else
                addr - 0x8000;
            return self.prg_rom[offset];
        }
        return 0;
    }

    fn write(ctx: *anyopaque, addr: u16, value: u8) void {
        _ = ctx;
        _ = addr;
        _ = value;
        // NROM is read-only
    }

    fn readCHR(ctx: *anyopaque, addr: u16) u8 {
        const self: *Mapper0 = @ptrCast(@alignCast(ctx));
        if (addr < 0x2000) {
            if (self.chr_rom.len > 0) {
                const offset = addr & (self.chr_rom.len - 1);
                return self.chr_rom[offset];
            } else {
                const offset = addr & 0x1FFF;
                if (offset < self.chr_ram.len) {
                    return self.chr_ram[offset];
                }
            }
        }
        return 0;
    }

    fn writeCHR(ctx: *anyopaque, addr: u16, value: u8) void {
        const self: *Mapper0 = @ptrCast(@alignCast(ctx));
        if (self.chr_rom.len > 0) return;
        if (addr < 0x2000) {
            const offset = addr & 0x1FFF;
            if (offset < self.chr_ram.len) {
                self.chr_ram[offset] = value;
            }
        }
    }
};

// Mapper 1 (MMC1)
pub const Mapper1 = struct {
    prg_rom: []u8,
    chr_rom: []u8,
    chr_ram: []u8,
    prg_ram: ?[]u8 = null,
    
    // MMC1 registers
    shift_register: u8 = 0x10,
    control: u8 = 0x0C,
    chr_bank_0: u8 = 0,
    chr_bank_1: u8 = 0,
    prg_bank: u8 = 0,
    
    // Mirroring callback
    set_mirroring: ?*const fn(mirroring: Mirroring) void = null,

    pub const Mirroring = enum { OneScreenLower, OneScreenUpper, Vertical, Horizontal };

    pub fn init(prg_rom: []u8, chr_rom: []u8, chr_ram: []u8) Mapper1 {
        // std.debug.print("MMC1 Init: PRG={d}KB, CHR={d}KB, CHR_RAM={d}KB\n", .{
        //     prg_rom.len / 1024, chr_rom.len / 1024, chr_ram.len / 1024
        // });
        // std.debug.print("MMC1 initial state: control=${X:02}, prg_bank={d}, last_bank={d}\n", .{
        //     0x0C, 0, (prg_rom.len / 0x4000) - 1
        // });
        return .{
            .prg_rom = prg_rom,
            .chr_rom = chr_rom,
            .chr_ram = chr_ram,
        };
    }

    pub fn mapper(_: *Mapper1) Mapper {
        return .{ .vtable = &vtable };
    }

    const vtable = Mapper.VTable{
        .read = read,
        .write = write,
        .readCHR = readCHR,
        .writeCHR = writeCHR,
    };

    fn read(ctx: *anyopaque, addr: u16) u8 {
        const self: *Mapper1 = @ptrCast(@alignCast(ctx));
        
        // PRG RAM at $6000-$7FFF
        if (addr >= 0x6000 and addr < 0x8000) {
            if (self.prg_ram) |ram| {
                const val = ram[addr - 0x6000];
                // std.debug.print("MMC1 PRG RAM read: ${X:04} = ${X:02}\n", .{addr, val});
                return val;
            }
            return 0;
        }
        
        // PRG ROM at $8000-$FFFF
        if (addr >= 0x8000) {
            const prg_mode: u2 = @intCast((self.control >> 2) & 0x03);
            const prg_bank_num = self.prg_bank & 0x0F;
            
            return switch (prg_mode) {
                0, 1 => blk: {
                    // 32KB mode - ignore low bit of bank number
                    const bank = prg_bank_num & 0xFE;
                    const offset = (addr - 0x8000) + (@as(u32, bank) * 0x8000);
                    break :blk self.prg_rom[offset % self.prg_rom.len];
                },
                2 => blk: {
                    // Fix first bank at $8000, switch 16KB at $C000
                    if (addr < 0xC000) {
                        break :blk self.prg_rom[addr - 0x8000];
                    } else {
                        const offset = (addr - 0xC000) + (@as(u32, prg_bank_num) * 0x4000);
                        break :blk self.prg_rom[offset % self.prg_rom.len];
                    }
                },
                3 => blk: {
                    // Fix last bank at $C000, switch 16KB at $8000
                    if (addr < 0xC000) {
                        const offset = (addr - 0x8000) + (@as(u32, prg_bank_num) * 0x4000);
                        if (addr >= 0x8E90 and addr <= 0x8EA0) {
                            std.debug.print("MMC1 read bank {d}: addr=${X:04} offset=${X:05} value=${X:02}\n", 
                                .{prg_bank_num, addr, offset, self.prg_rom[offset % self.prg_rom.len]});
                        }
                        break :blk self.prg_rom[offset % self.prg_rom.len];
                    } else {
                        const last_bank = (self.prg_rom.len / 0x4000) - 1;
                        const offset = (addr - 0xC000) + (last_bank * 0x4000);
                        // if ((addr >= 0xFFD8 and addr <= 0xFFDF) or (addr >= 0xEE90 and addr <= 0xEEA0)) {
                        //     std.debug.print("MMC1 read last bank: addr=${X:04} bank={d} offset=${X:05} value=${X:02}\n", 
                        //         .{addr, last_bank, offset, self.prg_rom[offset]});
                        // }
                        break :blk self.prg_rom[offset];
                    }
                },
            };
        }
        
        return 0;
    }

    fn write(ctx: *anyopaque, addr: u16, value: u8) void {
        const self: *Mapper1 = @ptrCast(@alignCast(ctx));
        
        // PRG RAM writes
        if (addr >= 0x6000 and addr < 0x8000) {
            if (self.prg_ram) |ram| {
                ram[addr - 0x6000] = value;
                // std.debug.print("MMC1 PRG RAM write: ${X:04} = ${X:02}\n", .{addr, value});
            }
            return;
        }
        
        // MMC1 register writes
        if (addr >= 0x8000) {
            // std.debug.print("MMC1 write: ${X:04} = ${X:02}\n", .{addr, value});
            // Reset shift register on write with bit 7 set
            if ((value & 0x80) != 0) {
                self.shift_register = 0x10;
                self.control |= 0x0C;
                return;
            }
            
            // Process serial write
            const complete = (self.shift_register & 0x01) != 0;
            self.shift_register >>= 1;
            self.shift_register |= (value & 0x01) << 4;
            
            if (complete) {
                // Write is complete, update appropriate register
                const reg_value = self.shift_register;
                self.shift_register = 0x10; // Reset for next write
                
                const reg_select: u2 = @intCast((addr >> 13) & 0x03);
                switch (reg_select) {
                    0 => { // $8000-$9FFF: Control
                        self.control = reg_value;
                        // std.debug.print("MMC1 Control = ${X:02} (PRG mode={d}, CHR mode={d})\n", .{
                        //     reg_value, (reg_value >> 2) & 0x03, (reg_value >> 4) & 0x01
                        // });
                        // Update mirroring
                        if (self.set_mirroring) |callback| {
                            const mirroring_mode = @as(Mirroring, @enumFromInt(reg_value & 0x03));
                            callback(mirroring_mode);
                        }
                    },
                    1 => { // $A000-$BFFF: CHR bank 0
                        self.chr_bank_0 = reg_value;
                        // std.debug.print("MMC1 CHR bank 0 = ${X:02}\n", .{reg_value});
                    },
                    2 => { // $C000-$DFFF: CHR bank 1
                        self.chr_bank_1 = reg_value;
                        // std.debug.print("MMC1 CHR bank 1 = ${X:02}\n", .{reg_value});
                    },
                    3 => { // $E000-$FFFF: PRG bank
                        self.prg_bank = reg_value;
                        // std.debug.print("MMC1 PRG bank = ${X:02}\n", .{reg_value});
                    },
                }
            }
        }
    }

    fn readCHR(ctx: *anyopaque, addr: u16) u8 {
        const self: *Mapper1 = @ptrCast(@alignCast(ctx));
        
        if (addr < 0x2000) {
            const chr_mode = (self.control >> 4) & 0x01;
            
            if (self.chr_rom.len > 0) {
                var offset: u32 = 0;
                
                if (chr_mode == 0) {
                    // 8KB CHR mode
                    const bank = self.chr_bank_0 & 0xFE;
                    offset = addr + (@as(u32, bank) * 0x1000);
                } else {
                    // 4KB CHR mode
                    if (addr < 0x1000) {
                        offset = addr + (@as(u32, self.chr_bank_0) * 0x1000);
                    } else {
                        offset = (addr - 0x1000) + (@as(u32, self.chr_bank_1) * 0x1000);
                    }
                }
                
                return self.chr_rom[offset % self.chr_rom.len];
            } else {
                // CHR RAM
                return self.chr_ram[addr & 0x1FFF];
            }
        }
        
        return 0;
    }

    fn writeCHR(ctx: *anyopaque, addr: u16, value: u8) void {
        const self: *Mapper1 = @ptrCast(@alignCast(ctx));
        
        // Only allow writes to CHR RAM
        if (self.chr_rom.len == 0 and addr < 0x2000) {
            self.chr_ram[addr & 0x1FFF] = value;
        }
    }
};