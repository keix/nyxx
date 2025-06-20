const Sweep = packed struct { shift: u3, negate: bool, period: u3, enabled: bool };
const Ctrl = packed struct { volume: u4, constant: bool, loop: bool, duty: u2 };
// TimerLow is just a u8.
const TimerHi = packed struct { timer: u3, length: u5 };

const Pulse = packed struct {
    ctrl: Ctrl = Ctrl{ .volume = 0, .constant = false, .loop = false, .duty = 0 },
    sweep: Sweep = Sweep{ .shift = 0, .negate = false, .period = 0, .enabled = false },
    timer_low: u8 = 0,
    timer_hi: TimerHi = TimerHi{ .timer = 0, .length = 0 },

    // Internal state for proper emulation
    envelope_divider: u4 = 0,
    envelope_decay: u4 = 0,
    envelope_start: bool = false,
    length_counter: u8 = 0,
    sweep_divider: u3 = 0,
    sweep_reload: bool = false,
    timer_value: u11 = 0,
    enabled: bool = false,

    pub fn write(self: *Pulse, offset: u2, val: u8) void {
        switch (offset) {
            0 => self.ctrl = @bitCast(val),
            1 => {
                self.sweep = @bitCast(val);
                self.sweep_reload = true;
            },
            2 => self.timer_low = val,
            3 => {
                self.timer_hi = @bitCast(val);
                self.timer_value = (@as(u11, self.timer_hi.timer) << 8) | self.timer_low;
                if (self.enabled) {
                    self.length_counter = LENGTH_TABLE[self.timer_hi.length];
                }
                self.envelope_start = true;
            },
        }
    }
};

// Length counter lookup table
const LENGTH_TABLE = [32]u8{
    10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
    12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30,
};

// Frame counter state
const FrameCounterMode = enum(u1) {
    four_step = 0,
    five_step = 1,
};

const FrameCounter = struct {
    cycle: u16 = 0,
    mode: FrameCounterMode = .four_step,
    irq_inhibit: bool = false,
    frame_irq: bool = false,
    reset_timer: u2 = 0,
};

pub const APU = struct {
    pulse1: Pulse = .{},
    pulse2: Pulse = .{},

    frame_counter: FrameCounter = .{},
    cpu_cycles_pending: u32 = 0,

    // Status register ($4015)
    status_pulse1: bool = false,
    status_pulse2: bool = false,

    // IRQ callback
    irq_callback: ?*const fn () void = null,

    pub fn init() APU {
        return APU{};
    }

    pub fn step(self: *APU, cpu_cycles: u32) void {
        // APU runs at half CPU speed - accumulate pending cycles
        self.cpu_cycles_pending += cpu_cycles;

        while (self.cpu_cycles_pending >= 2) {
            self.cpu_cycles_pending -= 2;

            // Handle frame counter reset delay
            if (self.frame_counter.reset_timer > 0) {
                self.frame_counter.reset_timer -= 1;
                if (self.frame_counter.reset_timer == 0) {
                    self.frame_counter.cycle = 0;
                    if (self.frame_counter.mode == .five_step) {
                        // Immediate clock in 5-step mode
                        self.clock_quarter();
                        self.clock_half();
                    }
                }
            }

            // Step frame counter
            self.frame_counter.cycle += 1;

            // Check for frame counter events based on mode
            switch (self.frame_counter.mode) {
                .four_step => {
                    switch (self.frame_counter.cycle) {
                        3729 => self.clock_quarter(),
                        7457 => {
                            self.clock_quarter();
                            self.clock_half();
                        },
                        11186 => self.clock_quarter(),
                        14915 => {
                            self.clock_quarter();
                            self.clock_half();
                            if (!self.frame_counter.irq_inhibit) {
                                self.frame_counter.frame_irq = true;
                                if (self.irq_callback) |callback| {
                                    callback();
                                }
                            }
                            self.frame_counter.cycle = 0;
                        },
                        else => {},
                    }
                },
                .five_step => {
                    switch (self.frame_counter.cycle) {
                        3729 => self.clock_quarter(),
                        7457 => {
                            self.clock_quarter();
                            self.clock_half();
                        },
                        11186 => self.clock_quarter(),
                        18641 => {
                            self.clock_quarter();
                            self.clock_half();
                            self.frame_counter.cycle = 0;
                        },
                        else => {},
                    }
                },
            }
        }
    }

    fn clock_half(self: *APU) void {
        // Clock length counters
        if (!self.pulse1.ctrl.loop and self.pulse1.length_counter > 0) {
            self.pulse1.length_counter -= 1;
        }
        if (!self.pulse2.ctrl.loop and self.pulse2.length_counter > 0) {
            self.pulse2.length_counter -= 1;
        }

        // Clock sweep units
        self.clock_sweep(&self.pulse1, false);
        self.clock_sweep(&self.pulse2, true);
    }

    fn clock_quarter(self: *APU) void {
        // Clock envelopes
        self.clock_envelope(&self.pulse1);
        self.clock_envelope(&self.pulse2);
    }

    fn clock_envelope(self: *APU, pulse: *Pulse) void {
        _ = self;
        if (pulse.envelope_start) {
            pulse.envelope_start = false;
            pulse.envelope_decay = 15;
            pulse.envelope_divider = pulse.ctrl.volume;
        } else {
            if (pulse.envelope_divider == 0) {
                pulse.envelope_divider = pulse.ctrl.volume;
                if (pulse.envelope_decay > 0) {
                    pulse.envelope_decay -= 1;
                } else if (pulse.ctrl.loop) {
                    pulse.envelope_decay = 15;
                }
            } else {
                pulse.envelope_divider -= 1;
            }
        }
    }

    fn clock_sweep(self: *APU, pulse: *Pulse, is_pulse2: bool) void {
        _ = self;
        const timer = (@as(u11, pulse.timer_hi.timer) << 8) | pulse.timer_low;
        var new_timer = timer;

        if (pulse.sweep_divider == 0 and pulse.sweep.enabled and timer >= 8) {
            const delta = timer >> pulse.sweep.shift;
            if (pulse.sweep.negate) {
                // Pulse 1 uses two's complement, Pulse 2 uses one's complement
                const adjustment = if (is_pulse2) delta else delta + 1;
                new_timer = timer -% adjustment;
            } else {
                new_timer = timer +% delta;
            }

            // Update timer if valid
            if (new_timer <= 0x7FF) {
                pulse.timer_low = @intCast(new_timer & 0xFF);
                pulse.timer_hi.timer = @intCast((new_timer >> 8) & 0x7);
                pulse.timer_value = new_timer;
            }
        }

        if (pulse.sweep_divider == 0 or pulse.sweep_reload) {
            pulse.sweep_divider = pulse.sweep.period;
            pulse.sweep_reload = false;
        } else {
            pulse.sweep_divider -= 1;
        }
    }

    pub fn write(self: *APU, addr: u16, val: u8) void {
        switch (addr) {
            0x4000...0x4003 => self.pulse1.write(@intCast(addr & 0x3), val),
            0x4004...0x4007 => self.pulse2.write(@intCast(addr & 0x3), val),
            0x4015 => { // Status register
                self.status_pulse1 = (val & 0x01) != 0;
                self.status_pulse2 = (val & 0x02) != 0;
                self.pulse1.enabled = self.status_pulse1;
                self.pulse2.enabled = self.status_pulse2;
                if (!self.status_pulse1) self.pulse1.length_counter = 0;
                if (!self.status_pulse2) self.pulse2.length_counter = 0;
            },
            0x4017 => { // Frame counter
                self.frame_counter.mode = if (val & 0x80 != 0) .five_step else .four_step;
                self.frame_counter.irq_inhibit = (val & 0x40) != 0;
                self.frame_counter.reset_timer = 3; // Reset after 3-4 CPU cycles
                if (self.frame_counter.irq_inhibit) {
                    self.frame_counter.frame_irq = false;
                }
            },
            else => {},
        }
    }

    pub fn read(self: *APU, addr: u16) u8 {
        return switch (addr) {
            0x4015 => { // Status register
                var status: u8 = 0;
                if (self.pulse1.length_counter > 0) status |= 0x01;
                if (self.pulse2.length_counter > 0) status |= 0x02;
                if (self.frame_counter.frame_irq) status |= 0x40;
                // Reading clears frame interrupt
                self.frame_counter.frame_irq = false;
                return status;
            },
            else => 0,
        };
    }

    pub fn setIrqCallback(self: *APU, callback: *const fn () void) void {
        self.irq_callback = callback;
    }
};
