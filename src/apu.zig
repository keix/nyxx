const std = @import("std");

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

// Audio constants
const CPU_FREQ = 1789773; // NTSC CPU frequency
const APU_FREQ = CPU_FREQ / 2; // APU runs at half CPU speed
const SAMPLE_RATE = 48000;
const CYCLES_PER_SAMPLE = @as(f32, @floatFromInt(CPU_FREQ)) / @as(f32, @floatFromInt(SAMPLE_RATE)); // ~37.28

// Duty cycle sequences for pulse channels
const DUTY_CYCLES = [4][8]bool{
    [8]bool{ false, true, false, false, false, false, false, false },  // 12.5%
    [8]bool{ false, true, true, false, false, false, false, false },   // 25%
    [8]bool{ false, true, true, true, true, false, false, false },     // 50%
    [8]bool{ true, false, false, true, true, true, true, true },       // 25% negated
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
    
    // Sequencer for wave generation
    timer: u16 = 0,  // Current timer value (counts down)
    sequencer_pos: u3 = 0,  // Position in duty cycle (0-7)

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
    
    pub fn clock(self: *Pulse) void {
        // Clock the timer at CPU rate
        if (self.timer == 0) {
            // Reload timer and advance sequencer
            self.timer = self.timer_value;
            self.sequencer_pos = (self.sequencer_pos +% 1) & 0x7;
        } else {
            self.timer -= 1;
        }
    }
    
    pub fn getOutput(self: *const Pulse) u4 {
        // Check if channel should output
        if (!self.enabled or self.length_counter == 0 or self.timer_value < 8) {
            return 0;
        }
        
        // Get current volume
        const volume = if (self.ctrl.constant) self.ctrl.volume else self.envelope_decay;
        
        // Check duty cycle
        const output = DUTY_CYCLES[self.ctrl.duty][self.sequencer_pos];
        
        return if (output) volume else 0;
    }
    
    pub fn getFrequency(self: *const Pulse) f32 {
        // Calculate actual frequency output
        // f = CPU_FREQ / (16 * (t + 1))
        // where t is the timer value
        if (self.timer_value < 8) return 0.0;
        return @as(f32, @floatFromInt(CPU_FREQ)) / (16.0 * @as(f32, @floatFromInt(self.timer_value + 1)));
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
    
    // Audio generation
    audio_samples: [16384]f32 = [_]f32{0.0} ** 16384,  // Larger buffer to prevent underruns
    audio_write_pos: usize = 0,
    audio_read_pos: usize = 0,
    sample_timer: f32 = 0,
    sample_counter: u64 = 0,
    allocator: std.mem.Allocator = undefined,
    audio_enabled: bool = false,

    pub fn init(allocator: std.mem.Allocator) !APU {
        var apu = APU{
            .allocator = allocator,
        };
        
        // Audio is now using internal buffer
        apu.audio_enabled = true;
        
        return apu;
    }
    
    pub fn deinit(self: *APU) void {
        _ = self;
        // Nothing to deallocate with fixed-size buffer
    }

    pub fn step(self: *APU, cpu_cycles: u32) void {
        // Clock pulse timers at CPU rate
        for (0..cpu_cycles) |_| {
            self.pulse1.clock();
            self.pulse2.clock();
        }
        
        // Generate audio samples based on CPU cycles
        if (self.audio_enabled) {
            self.sample_timer += @as(f32, @floatFromInt(cpu_cycles));
            while (self.sample_timer >= CYCLES_PER_SAMPLE) {
                self.sample_timer -= CYCLES_PER_SAMPLE;
                self.generateSample();
            }
        }
        
        // APU runs at half CPU speed - accumulate pending cycles
        self.cpu_cycles_pending += cpu_cycles;

        while (self.cpu_cycles_pending >= 2) {
            self.cpu_cycles_pending -= 2;
            
            // Don't clock sequencers here - they run at CPU rate

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
    
    fn generateSample(self: *APU) void {
        // Get raw outputs from channels
        const pulse1_out = @as(f32, @floatFromInt(self.pulse1.getOutput()));
        const pulse2_out = @as(f32, @floatFromInt(self.pulse2.getOutput()));
        
        // Use NES-style mixing (approximate)
        // Pulse mixing: pulse_out = 95.88 / ((8128 / (pulse1 + pulse2)) + 100)
        const pulse_sum = pulse1_out + pulse2_out;
        var pulse_mixed: f32 = 0.0;
        
        if (pulse_sum > 0) {
            pulse_mixed = 95.88 / ((8128.0 / pulse_sum) + 100.0);
        }
        
        // Scale to audio range (NES output is typically 0-1, center at 0.5)
        // Apply DC offset removal and scale to [-1, 1]
        const sample = pulse_mixed * 2.0 - 0.5;
        
        // Apply simple high-pass filter to remove DC offset
        const filtered_sample = std.math.clamp(sample, -1.0, 1.0);
        
        // Write to internal buffer
        self.audio_samples[self.audio_write_pos] = filtered_sample;
        self.audio_write_pos = (self.audio_write_pos + 1) % self.audio_samples.len;
    }
    
    pub fn readAudioSample(self: *APU) ?f32 {
        if (self.audio_read_pos == self.audio_write_pos) {
            return null;
        }
        
        const sample = self.audio_samples[self.audio_read_pos];
        self.audio_read_pos = (self.audio_read_pos + 1) % self.audio_samples.len;
        return sample;
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
