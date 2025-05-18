pub const Registers = struct {
    ctrl: u8 = 0, // $2000
    mask: u8 = 0, // $2001
    status: u8 = 0, // $2002
    oam_addr: u8 = 0, // $2003
    oam_data: u8 = 0, // $2004
    scroll_x: u8 = 0, // $2005 (write 1)
    scroll_y: u8 = 0, // $2005 (write 2)
    vram_data: u8 = 0, // $2007
};

pub const PPU = struct {
    registers: Registers = .{},

    addr_latch: bool = false,

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
        self.registers.mask = value;
    }

    fn writeOamAddr(self: *PPU, value: u8) void {
        self.registers.oam_addr = value;
    }

    fn writeOamData(self: *PPU, value: u8) void {
        self.registers.oam_data = value;
    }

    fn writeScroll(self: *PPU, value: u8) void {
        if (!self.addr_latch) {
            self.registers.scroll_x = value;
        } else {
            self.registers.scroll_y = value;
        }
        self.addr_latch = !self.addr_latch;
    }

    fn writeAddr(self: *PPU, value: u8) void {
        _ = value; // placeholder
        self.addr_latch = !self.addr_latch;
    }

    fn writeData(self: *PPU, value: u8) void {
        self.registers.vram_data = value;
    }

    fn readStatus(self: *PPU) u8 {
        return self.registers.status;
    }

    fn readOamData(self: *PPU) u8 {
        return self.registers.oam_data;
    }

    fn readData(self: *PPU) u8 {
        return self.registers.vram_data;
    }
};
