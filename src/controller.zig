const std = @import("std");

pub const Controller = struct {
    buttons: u8 = 0,        // Current button state (A,B,Select,Start,Up,Down,Left,Right)
    shift_register: u8 = 0, // Shift register for serial reading
    shift_count: u8 = 0,    // Number of bits shifted
    strobe: bool = false,   // Strobe/latch state
    
    pub fn init() Controller {
        return Controller{};
    }
    
    pub fn write(self: *Controller, value: u8) void {
        const new_strobe = (value & 0x01) != 0;
        
        // On strobe transition from high to low, reload shift register
        if (self.strobe and !new_strobe) {
            self.shift_register = self.buttons;
            self.shift_count = 0;
        }
        
        self.strobe = new_strobe;
    }
    
    pub fn read(self: *Controller) u8 {
        var result: u8 = 0;
        
        if (self.strobe) {
            // When strobe is high, always return A button
            result = self.buttons & 0x01;
        } else {
            // Return current bit and shift
            result = self.shift_register & 0x01;
            self.shift_register >>= 1;
            self.shift_count += 1;
            
            // After 8 reads, return 1 (bus pull-up)
            if (self.shift_count >= 8) {
                result = 1;
            }
        }
        
        // Only return bit 0, upper bits should come from open bus
        return result;
    }
    
    pub fn setButtons(self: *Controller, a: bool, b: bool, select: bool, start: bool, 
                      up: bool, down: bool, left: bool, right: bool) void {
        self.buttons = 0;
        if (a) self.buttons |= 0x01;      // bit 0
        if (b) self.buttons |= 0x02;      // bit 1
        if (select) self.buttons |= 0x04; // bit 2
        if (start) self.buttons |= 0x08;  // bit 3
        if (up) self.buttons |= 0x10;     // bit 4
        if (down) self.buttons |= 0x20;   // bit 5
        if (left) self.buttons |= 0x40;   // bit 6
        if (right) self.buttons |= 0x80;  // bit 7
    }
    
    pub fn setFromState(self: *Controller, state: anytype) void {
        self.setButtons(
            state.a,
            state.b,
            state.select,
            state.start,
            state.up,
            state.down,
            state.left,
            state.right
        );
    }
};