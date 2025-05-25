const Mask = packed struct {
    grayscale: bool,
    show_bg_left: bool,
    show_sprites_left: bool,
    show_bg: bool,
    show_sprites: bool,
    emphasize_red: bool,
    emphasize_green: bool,
    emphasize_blue: bool,

    pub fn write(self: *Mask, value: u8) void {
        self.* = @bitCast(value);
    }

    pub fn read(self: Mask) u8 {
        return @bitCast(self);
    }
};

const Status = packed struct {
    unused: u5 = 0,
    sprite_overflow: bool,
    sprite0_hit: bool,
    vblank: bool,

    pub fn read(self: *Status) u8 {
        const result: u8 = @bitCast(self.*);
        self.vblank = false;
        return result;
    }
};

const LoopyRegister = packed struct {
    coarse_x: u5 = 0,
    coarse_y: u5 = 0,
    nametable: u2 = 0,
    fine_y: u3 = 0,
    unused: u1 = 0,

    pub fn read(self: LoopyRegister) u16 {
        return @bitCast(self);
    }

    pub fn write(self: *LoopyRegister, value: u16) void {
        self.* = @bitCast(value & 0x7FFF);
    }
};

const ScrollUnit = struct {
    v: LoopyRegister = .{}, // current VRAM address
    t: LoopyRegister = .{}, // temporary VRAM address
    x: u3 = 0, // fine X scroll (0-7)
    w: bool = false, // write toggle

    pub fn writeScroll(self: *ScrollUnit, value: u8) void {
        if (!self.w) {
            self.t.coarse_x = @truncate(value >> 3);
            self.x = @truncate(value & 0b0000_0111);
        } else {
            self.t.coarse_y = @truncate(value >> 3);
            self.t.fine_y = @truncate(value & 0b0000_0111);
        }
        self.w = !self.w;
    }

    pub fn writeAddr(self: *ScrollUnit, value: u8) void {
        if (!self.w) {
            const current = self.t.read() & 0x00FF;
            self.t.write((@as(u16, value & 0x3F) << 8) | current);
        } else {
            const current = self.t.read() & 0x7F00;
            self.t.write(current | value);
            self.v = self.t;
        }
        self.w = !self.w;
    }

    pub fn resetLatch(self: *ScrollUnit) void {
        self.w = false;
    }

    pub fn incrementHorizontal(self: *ScrollUnit) void {
        if (self.v.coarse_x == 31) {
            self.v.coarse_x = 0;
            self.v.nametable ^= 0b01;
        } else {
            self.v.coarse_x += 1;
        }
    }

    pub fn incrementVertical(self: *ScrollUnit) void {
        if (self.v.fine_y < 7) {
            self.v.fine_y += 1;
        } else {
            self.v.fine_y = 0;
            if (self.v.coarse_y == 29) {
                self.v.coarse_y = 0;
                self.v.nametable ^= 0b10;
            } else if (self.v.coarse_y == 31) {
                self.v.coarse_y = 0;
            } else {
                self.v.coarse_y += 1;
            }
        }
    }
};

const Registers = struct {
    ctrl: u8 = 0, // $2000
    mask: Mask = @bitCast(@as(u8, 0)), // $2001
    status: Status = @bitCast(@as(u8, 0)), // $2002
    oam_addr: u8 = 0, // $2003
    oam_data: [256]u8 = [_]u8{0} ** 256, // $2004
    scroll_unit: ScrollUnit = .{}, // $2005 + $2006 + fine X scroll
    vram_buffer: u8 = 0, // $2007
};

pub const PPU = struct {
    registers: Registers = .{},
    vram: [0x4000]u8 = [_]u8{0} ** 0x4000, // VRAM
    _vblank_injected: bool = false,

    pub fn init() PPU {
        return PPU{};
    }

    pub fn writeRegister(self: *PPU, reg: u3, value: u8) void {
        switch (reg) {
            0 => self.writeCtrl(value),
            1 => self.writeMask(value),
            2 => {}, // read-only
            3 => self.writeOamAddr(value),
            4 => self.writeOamData(value),
            5 => self.registers.scroll_unit.writeScroll(value),
            6 => self.registers.scroll_unit.writeAddr(value),
            7 => self.writeData(value),
        }
    }

    pub fn readRegister(self: *PPU, reg: u3) u8 {
        return switch (reg) {
            2 => {
                if (!self._vblank_injected) {
                    self._vblank_injected = true;
                    self.registers.status.vblank = true; // Reset vblank after reading
                }
                return self.readStatus();
            },
            4 => self.readOamData(),
            7 => self.readData(),
            else => 0,
        };
    }

    fn writeCtrl(self: *PPU, value: u8) void {
        self.registers.ctrl = value;
    }

    fn writeMask(self: *PPU, value: u8) void {
        self.registers.mask.write(value);
    }

    fn writeOamAddr(self: *PPU, value: u8) void {
        self.registers.oam_addr = value;
    }

    fn writeOamData(self: *PPU, value: u8) void {
        self.registers.oam_data[self.registers.oam_addr] = value;
        self.registers.oam_addr +%= 1;
    }

    fn writeScroll(self: *PPU, value: u8) void {
        self.registers.scroll.write(value);
    }

    fn writeData(self: *PPU, value: u8) void {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
        self.vram[addr] = value;

        const increment: u16 = if ((self.registers.ctrl >> 2) & 0b1 == 1) 32 else 1;
        self.registers.scroll_unit.v.write(addr + increment);
    }

    fn readStatus(self: *PPU) u8 {
        const value = self.registers.status.read();
        self.registers.scroll_unit.resetLatch();
        return value;
    }

    fn readOamData(self: *PPU) u8 {
        return self.registers.oam_data[self.registers.oam_addr];
    }

    fn readData(self: *PPU) u8 {
        return self.registers.vram_buffer;
    }
};
