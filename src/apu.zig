// Status register bit masks
const STATUS_PULSE1 = 0x01;
const STATUS_PULSE2 = 0x02;
const STATUS_FRAME_IRQ = 0x40;

// Frame counter control bits
const FRAME_COUNTER_MODE_BIT = 0x80;
const FRAME_COUNTER_IRQ_INHIBIT_BIT = 0x40;

// Frame counter constants
const FRAME_COUNTER_4_STEP_CYCLES = [_]u16{ 3729, 7457, 11186, 14915 };
const FRAME_COUNTER_5_STEP_CYCLES = [_]u16{ 3729, 7457, 11186, 18641 };

// Length counter lookup table
const LENGTH_TABLE = [32]u8{
    10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
    12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30,
};

const Sweep = packed struct { shift: u3, negate: bool, period: u3, enabled: bool };
const Ctrl = packed struct { volume: u4, constant: bool, loop: bool, duty: u2 };
const TimerHi = packed struct { timer: u3, length: u5 };

const Pulse = struct {
    ctrl: Ctrl = .{ .volume = 0, .constant = false, .loop = false, .duty = 0 },
    sweep: Sweep = .{ .shift = 0, .negate = false, .period = 0, .enabled = false },
    timer_low: u8 = 0,
    timer_hi: TimerHi = .{ .timer = 0, .length = 0 },

    // Internal state
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
            0 => self.writeCtrl(val),
            1 => self.writeSweep(val),
            2 => self.timer_low = val,
            3 => self.writeTimerHi(val),
        }
    }

    fn writeCtrl(self: *Pulse, val: u8) void {
        self.ctrl = @bitCast(val);
    }

    fn writeSweep(self: *Pulse, val: u8) void {
        self.sweep = @bitCast(val);
        self.sweep_reload = true;
    }

    fn writeTimerHi(self: *Pulse, val: u8) void {
        self.timer_hi = @bitCast(val);
        self.updateTimerValue();
        if (self.enabled) {
            self.loadLengthCounter();
        }
        self.envelope_start = true;
    }

    fn updateTimerValue(self: *Pulse) void {
        self.timer_value = (@as(u11, self.timer_hi.timer) << 8) | self.timer_low;
    }

    fn loadLengthCounter(self: *Pulse) void {
        self.length_counter = LENGTH_TABLE[self.timer_hi.length];
    }

    pub fn getTimer(self: *const Pulse) u11 {
        return (@as(u11, self.timer_hi.timer) << 8) | self.timer_low;
    }

    pub fn setTimer(self: *Pulse, timer: u11) void {
        self.timer_low = @intCast(timer & 0xFF);
        self.timer_hi.timer = @intCast((timer >> 8) & 0x7);
        self.timer_value = timer;
    }
};


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
                        self.clockQuarter();
                        self.clockHalf();
                    }
                }
            }

            // Step frame counter
            self.frame_counter.cycle += 1;

            // Check for frame counter events
            self.processFrameCounterEvents();
        }
    }

    fn processFrameCounterEvents(self: *APU) void {
        switch (self.frame_counter.mode) {
            .four_step => self.processFourStepMode(),
            .five_step => self.processFiveStepMode(),
        }
    }

    fn processFourStepMode(self: *APU) void {
        switch (self.frame_counter.cycle) {
            3729 => self.clockQuarter(),
            7457 => self.clockQuarterAndHalf(),
            11186 => self.clockQuarter(),
            14915 => {
                self.clockQuarterAndHalf();
                self.triggerFrameIrq();
                self.frame_counter.cycle = 0;
            },
            else => {},
        }
    }

    fn processFiveStepMode(self: *APU) void {
        switch (self.frame_counter.cycle) {
            3729 => self.clockQuarter(),
            7457 => self.clockQuarterAndHalf(),
            11186 => self.clockQuarter(),
            18641 => {
                self.clockQuarterAndHalf();
                self.frame_counter.cycle = 0;
            },
            else => {},
        }
    }

    fn clockQuarterAndHalf(self: *APU) void {
        self.clockQuarter();
        self.clockHalf();
    }

    fn triggerFrameIrq(self: *APU) void {
        if (!self.frame_counter.irq_inhibit) {
            self.frame_counter.frame_irq = true;
            if (self.irq_callback) |callback| {
                callback();
            }
        }
    }

    fn clockHalf(self: *APU) void {
        self.clockLengthCounter(&self.pulse1);
        self.clockLengthCounter(&self.pulse2);
        self.clockSweep(&self.pulse1, false);
        self.clockSweep(&self.pulse2, true);
    }

    fn clockLengthCounter(self: *APU, pulse: *Pulse) void {
        _ = self;
        if (!pulse.ctrl.loop and pulse.length_counter > 0) {
            pulse.length_counter -= 1;
        }
    }

    fn clockQuarter(self: *APU) void {
        // Clock envelopes
        self.clockEnvelope(&self.pulse1);
        self.clockEnvelope(&self.pulse2);
    }

    fn clockEnvelope(self: *APU, pulse: *Pulse) void {
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

    fn clockSweep(self: *APU, pulse: *Pulse, isPulse2: bool) void {
        _ = self;
        const timer = pulse.getTimer();

        if (shouldUpdateSweep(pulse, timer)) {
            const newTimer = calculateSweepTarget(pulse, timer, isPulse2);
            if (newTimer <= 0x7FF) {
                pulse.setTimer(newTimer);
            }
        }

        updateSweepDivider(pulse);
    }

    fn shouldUpdateSweep(pulse: *const Pulse, timer: u11) bool {
        return pulse.sweep_divider == 0 and pulse.sweep.enabled and timer >= 8;
    }

    fn calculateSweepTarget(pulse: *const Pulse, timer: u11, isPulse2: bool) u11 {
        const delta = timer >> pulse.sweep.shift;
        if (pulse.sweep.negate) {
            const adjustment = if (isPulse2) delta else delta + 1;
            return timer -% adjustment;
        } else {
            return timer +% delta;
        }
    }

    fn updateSweepDivider(pulse: *Pulse) void {
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
            0x4015 => self.writeStatus(val),
            0x4017 => self.writeFrameCounter(val),
            else => {},
        }
    }

    fn writeStatus(self: *APU, val: u8) void {
        self.setPulseEnabled(&self.pulse1, &self.status_pulse1, val & STATUS_PULSE1 != 0);
        self.setPulseEnabled(&self.pulse2, &self.status_pulse2, val & STATUS_PULSE2 != 0);
    }

    fn setPulseEnabled(self: *APU, pulse: *Pulse, status: *bool, enabled: bool) void {
        _ = self;
        status.* = enabled;
        pulse.enabled = enabled;
        if (!enabled) pulse.length_counter = 0;
    }

    fn writeFrameCounter(self: *APU, val: u8) void {
        self.frame_counter.mode = if (val & FRAME_COUNTER_MODE_BIT != 0) .five_step else .four_step;
        self.frame_counter.irq_inhibit = (val & FRAME_COUNTER_IRQ_INHIBIT_BIT) != 0;
        self.frame_counter.reset_timer = 3;
        if (self.frame_counter.irq_inhibit) {
            self.frame_counter.frame_irq = false;
        }
    }

    pub fn read(self: *APU, addr: u16) u8 {
        return switch (addr) {
            0x4015 => self.readStatus(),
            else => 0,
        };
    }

    fn readStatus(self: *APU) u8 {
        const status = self.buildStatusByte();
        self.frame_counter.frame_irq = false;
        return status;
    }

    fn buildStatusByte(self: *const APU) u8 {
        var status: u8 = 0;
        if (self.pulse1.length_counter > 0) status |= STATUS_PULSE1;
        if (self.pulse2.length_counter > 0) status |= STATUS_PULSE2;
        if (self.frame_counter.frame_irq) status |= STATUS_FRAME_IRQ;
        return status;
    }

    pub fn setIrqCallback(self: *APU, callback: *const fn () void) void {
        self.irq_callback = callback;
    }
};
