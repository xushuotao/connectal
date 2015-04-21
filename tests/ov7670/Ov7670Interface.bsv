
// Copyright (c) 2015 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import I2C::*;

interface Ov7670ControllerRequest;
   method Action probe(Bool write, Bit#(7) slaveaddr, Bit#(8) address, Bit#(8) data);
   method Action setReset(Bit#(1) rval);
   method Action setPowerDown(Bit#(1) pwdn);
endinterface

interface Ov7670ControllerIndication;
   method Action probeResponse(Bit#(8) data);
   method Action vsync();
endinterface

interface Ov7670Pins;
   interface I2C_Pins i2c;
   interface Clock xclk;
   interface Clock pclk_deleteme_unused_clock;
   method bit reset();
   method bit pwdn();
   method Action pclk(Bit#(1) v);
   method Action pxl(Bit#(1) vsync, Bit#(1) href, Bit#(8) data);
endinterface