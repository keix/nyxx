const std = @import("std");
const APU = @import("../apu.zig").APU;

test "APU init" {
    const apu = APU.init();
    
    try std.testing.expectEqual(@as(u16, 0), apu.frame_counter.cycle);
    try std.testing.expectEqual(false, apu.frame_counter.frame_irq);
    try std.testing.expectEqual(@as(u8, 0), apu.pulse1.length_counter);
    try std.testing.expectEqual(@as(u8, 0), apu.pulse2.length_counter);
}

test "APU pulse channel write" {
    var apu = APU.init();
    
    // Enable pulse 1
    apu.write(0x4015, 0x01);
    try std.testing.expectEqual(true, apu.status_pulse1);
    try std.testing.expectEqual(true, apu.pulse1.enabled);
    
    // Write to pulse 1 registers
    apu.write(0x4000, 0x30); // Duty 0, constant volume, volume 0
    try std.testing.expectEqual(@as(u2, 0), apu.pulse1.ctrl.duty);
    try std.testing.expectEqual(true, apu.pulse1.ctrl.constant);
    try std.testing.expectEqual(@as(u4, 0), apu.pulse1.ctrl.volume);
    
    // Write timer and trigger length counter
    apu.write(0x4002, 0x00); // Timer low
    apu.write(0x4003, 0x08); // Timer high + length
    try std.testing.expectEqual(@as(u8, 254), apu.pulse1.length_counter); // Length table index 1
}

test "APU frame counter 4-step mode" {
    var apu = APU.init();
    
    // Set 4-step mode
    apu.write(0x4017, 0x00);
    try std.testing.expectEqual(.four_step, apu.frame_counter.mode);
    
    // Test quarter frame at cycle 3729
    apu.step(3729 * 2); // APU runs at half CPU speed
    
    // After reset delay
    apu.step(10);
}

test "APU frame counter 5-step mode" {
    var apu = APU.init();
    
    // Set 5-step mode
    apu.write(0x4017, 0x80);
    try std.testing.expectEqual(.five_step, apu.frame_counter.mode);
    try std.testing.expectEqual(@as(u2, 3), apu.frame_counter.reset_timer);
}

test "APU status register read" {
    var apu = APU.init();
    
    // Enable channels and set length counters
    apu.write(0x4015, 0x03); // Enable pulse 1 and 2
    apu.pulse1.length_counter = 10;
    apu.pulse2.length_counter = 20;
    
    const status = apu.read(0x4015);
    try std.testing.expectEqual(@as(u8, 0x03), status & 0x03);
}

test "APU envelope clock" {
    var apu = APU.init();
    
    // Enable pulse 1
    apu.write(0x4015, 0x01);
    
    // Set envelope mode (not constant volume)
    apu.write(0x4000, 0x00); // Envelope period = 0, constant = false
    apu.write(0x4003, 0x00); // Trigger envelope start
    
    try std.testing.expectEqual(true, apu.pulse1.envelope_start);
    try std.testing.expectEqual(@as(u4, 0), apu.pulse1.ctrl.volume);
    try std.testing.expectEqual(false, apu.pulse1.ctrl.constant);
}

test "APU length counter lookup" {
    var apu = APU.init();
    
    // Test a few length counter values
    apu.write(0x4015, 0x01); // Enable pulse 1
    
    // Length index 0 should give 10
    apu.write(0x4003, 0x00);
    try std.testing.expectEqual(@as(u8, 10), apu.pulse1.length_counter);
    
    // Length index 1 should give 254
    apu.write(0x4003, 0x08);
    try std.testing.expectEqual(@as(u8, 254), apu.pulse1.length_counter);
}

test "APU sweep unit" {
    var apu = APU.init();
    
    // Enable pulse 1
    apu.write(0x4015, 0x01);
    
    // Set sweep with shift=1, period=1, enabled
    apu.write(0x4001, 0x81); // Enable, period=0, negate=0, shift=1
    try std.testing.expectEqual(true, apu.pulse1.sweep.enabled);
    try std.testing.expectEqual(@as(u3, 1), apu.pulse1.sweep.shift);
    try std.testing.expectEqual(true, apu.pulse1.sweep_reload);
}

test "APU IRQ callback" {
    var apu = APU.init();
    
    // We'll track IRQ state through the frame_irq flag instead
    // Set 4-step mode without IRQ inhibit
    apu.write(0x4017, 0x00);
    
    // Step through to frame IRQ (14915 APU cycles)
    // Need to account for reset delay (3-4 cycles)
    apu.step(8); // Process reset delay
    apu.step(14915 * 2); // Step to IRQ point
    
    // IRQ flag should be set in 4-step mode
    try std.testing.expectEqual(true, apu.frame_counter.frame_irq);
    
    // Test IRQ inhibit
    apu.write(0x4017, 0x40); // IRQ inhibit set
    try std.testing.expectEqual(false, apu.frame_counter.frame_irq); // Should clear IRQ
    
    // Step through another frame with inhibit
    apu.step(8); // Process reset delay
    apu.step(14915 * 2);
    try std.testing.expectEqual(false, apu.frame_counter.frame_irq); // Should not set IRQ
}