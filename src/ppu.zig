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
    coarse_x: u5 = 0, // bits 0–4
    coarse_y: u5 = 0, // bits 5–9
    nametable: u2 = 0, // bits 10–11
    fine_y: u3 = 0, // bits 12–14
    unused: u1 = 0, // bit 15

    pub fn fromU16(value: u16) LoopyRegister {
        return @bitCast(value);
    }

    pub fn toU16(self: LoopyRegister) u16 {
        return @bitCast(self);
    }
};

const Scroll = struct {
    x: u8 = 0,
    y: u8 = 0,
    latch: bool = false,

    pub fn write(self: *Scroll, value: u8) void {
        if (!self.latch) {
            self.x = value;
        } else {
            self.y = value;
        }
        self.latch = !self.latch;
    }

    pub fn resetLatch(self: *Scroll) void {
        self.latch = false;
    }
};

const Addr = struct {
    high: u8 = 0,
    low: u8 = 0,
    latch: bool = false,

    pub fn write(self: *Addr, value: u8) void {
        if (!self.latch) {
            self.high = value & 0x3F;
        } else {
            self.low = value;
        }
        self.latch = !self.latch;
    }

    pub fn read(self: Addr) u16 {
        return (@as(u16, self.high) << 8) | self.low;
    }

    pub fn resetLatch(self: *Addr) void {
        self.latch = false;
    }

    pub fn increment(self: *Addr, delta: u16) void {
        const current = self.read();
        const next = (current + delta) & 0x3FFF;
        self.high = @truncate(next >> 8);
        self.low = @truncate(next & 0xFF);
    }
};

const Registers = struct {
    ctrl: u8 = 0, // $2000
    mask: Mask = @bitCast(@as(u8, 0)), // $2001
    status: Status = @bitCast(@as(u8, 0)), // $2002
    oam_addr: u8 = 0, // $2003
    oam_data: [256]u8 = [_]u8{0} ** 256, // $2004
    scroll: Scroll = .{}, // $2005
    addr: Addr = .{}, // $2006
    vram_buffer: u8 = 0, // $2007
};

pub const PPU = struct {
    registers: Registers = .{},
    addr_latch: bool = false,
    vram: [0x4000]u8 = [_]u8{0} ** 0x4000, // VRAM

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
            5 => self.writeScroll(value),
            6 => self.writeAddr(value),
            7 => self.writeData(value),
        }
    }

    pub fn readRegister(self: *PPU, reg: u3) u8 {
        return switch (reg) {
            2 => self.readStatus(),
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

    fn writeAddr(self: *PPU, value: u8) void {
        _ = value; // placeholder
        self.addr_latch = !self.addr_latch;
    }

    fn writeData(self: *PPU, value: u8) void {
        const addr = self.registers.addr.read();

        if (addr < 0x4000) {
            self.vram[addr] = value;
        }

        const increment: u16 = if ((self.registers.ctrl >> 2) & 0b1 == 1) 32 else 1;
        self.registers.addr.increment(increment);
    }

    fn readStatus(self: *PPU) u8 {
        const value = self.registers.status.read();
        self.addr_latch = false;
        return value;
    }

    fn readOamData(self: *PPU) u8 {
        return self.registers.oam_data[self.registers.oam_addr];
    }

    fn readData(self: *PPU) u8 {
        return self.registers.vram_buffer;
    }
};
