const Sweep = packed struct { shift: u3, negate: bool, period: u3, enabled: bool };
const Ctrl = packed struct { volume: u4, constant: bool, loop: bool, duty: u2 };
// TimerLow is just a u8.
const TimerHi = packed struct { timer: u3, length: u5 };

const Pulse = packed struct {
    ctrl: Ctrl = Ctrl{ .volume = 0, .constant = false, .loop = false, .duty = 0 },
    sweep: Sweep = Sweep{ .shift = 0, .negate = false, .period = 0, .enabled = false },
    timer_low: u8 = 0,
    timer_hi: TimerHi = TimerHi{ .timer = 0, .length = 0 },

    pub fn write(self: *Pulse, offset: u2, val: u8) void {
        switch (offset) {
            0 => self.ctrl = @bitCast(val),
            1 => self.sweep = @bitCast(val),
            2 => self.timer_low = val,
            3 => self.timer_hi = @bitCast(val),
        }
    }
};

pub const APU = struct {
    pulse1: Pulse = .{},
    pulse2: Pulse = .{},

    cycle_counter: u32 = 0,

    pub fn init() APU {
        return APU{};
    }

    pub fn step(self: *APU, cpu_cycles: u32) void {
        const apu_cycles = cpu_cycles / 2; // APU runs at half the CPU speed.
        for (apu_cycles) |_| {
            self.cycle_counter += 1;
            self.clock_frame();
        }
    }

    fn clock_frame(self: *APU) void {
        if (self.cycle_counter % 14913 == 0) {
            self.clock_half();
        }
        if (self.cycle_counter % 7457 == 0) {
            self.clock_quarter();
        }
    }

    fn clock_half(_: *APU) void {
        // This function would handle the half frame clocking logic, such as
        // updating the envelope and length counters.
        // For now, it's a placeholder.
    }

    fn clock_quarter(_: *APU) void {
        // This function would handle the quarter frame clocking logic, such as
        // updating the sweep and timer logic.
        // For now, it's a placeholder.
    }

    pub fn writePulse(self: *APU, addr: u8, val: u8) void {
        switch (addr) {
            0...3 => self.pulse1.write(@intCast(addr), val),
            4...7 => self.pulse2.write(@intCast(addr - 4), val),
            else => {},
        }
    }
};
