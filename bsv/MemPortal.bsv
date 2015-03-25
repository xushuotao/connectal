// Copyright (c) 2014 Quanta Research Cambridge, Inc.

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

import Vector::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import CtrlMux::*;

import MIFO::*;
import Pipe::*;
import Portal::*;
import MemTypes::*;
import AddressGenerator::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import ConnectalMemory::*;
import HostInterface::*;

interface PortalCtrlMemSlave#(numeric type addrWidth, numeric type dataWidth);
   interface PortalCtrl#(addrWidth, dataWidth)  memSlave;
   interface ReadOnly#(Bool) interrupt;
   interface WriteOnly#(Bit#(dataWidth)) num_portals;
endinterface

module mkPortalCtrlMemSlave#(Bit#(dataWidth) ifcId, PortalInterrupt#(dataWidth) intr)
   (PortalCtrlMemSlave#(addrWidth, dataWidth))
   provisos(Add#(d__, dataWidth, TMul#(dataWidth, 2)));
   Reg#(Bit#(dataWidth)) num_portals_reg <- mkReg(0);
   Reg#(Bool) interruptEnableReg <- mkReg(False);
   Reg#(Bit#(TMul#(dataWidth,2))) cycle_count <- mkReg(0);
   Reg#(Bit#(dataWidth))    snapshot <- mkReg(0);
   let verbose = False;
   
   rule count;
      cycle_count <= cycle_count+1;
   endrule
   
   interface PortalCtrl memSlave;
   method Action write(Bit#(addrWidth) addr, Bit#(dataWidth) v);
      if (addr == 4)
	 interruptEnableReg <= v[0] == 1'd1;
   endmethod

   method ActionValue#(Bit#(dataWidth)) read(Bit#(addrWidth) addr);
	       let v = 'h05a05a0;
	       if (addr == 0)
		  v = intr.status() ? 1 : 0;
	       if (addr == 4)
		  v = interruptEnableReg ? 1 : 0;
	       if (addr == 8)
		  v = fromInteger(valueOf(NumberOfTiles));
               if (addr == 'h00C) begin
		  if (intr.status())
		     v = intr.channel()+1;
		  else 
		     v = 0;
               end
	       if (addr == 'h010)
		  v = ifcId;
	       if (addr == 'h014)
		  v = num_portals_reg;
	       if (addr == 'h018) begin
		  snapshot <= truncate(cycle_count);
		  v = truncate(cycle_count>>valueOf(dataWidth));
	       end
	       if (addr == 'h01C)
		  v = snapshot;
	       return v;
   endmethod
   endinterface
   interface ReadOnly interrupt;
      method Bool _read();
	 return intr.status() && interruptEnableReg;
      endmethod
   endinterface
   interface WriteOnly num_portals;
      method Action _write(Bit#(dataWidth) v);
	 num_portals_reg <= v;
      endmethod
   endinterface
endmodule   

module mkMemPortalIn#(Bit#(slaveDataWidth) ifcId, Vector#(numRequests, PipeIn#(Bit#(slaveDataWidth))) requests)(MemPortal#(slaveAddrWidth, slaveDataWidth))
   provisos ( Add#(1, i__, slaveDataWidth)
	     ,Add#(c__, 5, slaveAddrWidth)
	     ,Add#(d__, 1, c__)
	     ,Add#(a__, TLog#(TAdd#(1, numRequests)), c__)
	     ,Add#(b__, slaveDataWidth, TMul#(slaveDataWidth, 2))
             ,Add#(e__, TLog#(numRequests), c__)
	     );

   PortalCtrlMemSlave#(5,slaveDataWidth) ctrlPort <- mkPortalCtrlMemSlave(ifcId, (interface PortalInterrupt;
           method Bool status();
              return False;
           endmethod
           method Bit#(dataWidth) channel();
              return -1;
           endmethod
        endinterface));
   let memslave  <- mkMemMethodMuxIn(ctrlPort.memSlave,requests);
   interface PhysMemSlave slave = memslave;
   interface ReadOnly interrupt = ctrlPort.interrupt;
   interface WriteOnly num_portals = ctrlPort.num_portals;
endmodule

module mkMemPortalOut#(Bit#(slaveDataWidth) ifcId, Vector#(numIndications, PipeOut#(Bit#(slaveDataWidth))) indications, PortalInterrupt#(slaveDataWidth) intr)(MemPortal#(slaveAddrWidth, slaveDataWidth))
   provisos ( Add#(1, i__, slaveDataWidth)
	     ,Add#(c__, 5, slaveAddrWidth)
	     ,Add#(d__, 1, c__)
	     ,Add#(a__, TLog#(TAdd#(1, numIndications)), c__)
	     ,Add#(b__, slaveDataWidth, TMul#(slaveDataWidth, 2))
             ,Add#(e__, TLog#(numIndications), c__)
	     );

   PortalCtrlMemSlave#(5,slaveDataWidth) ctrlPort <- mkPortalCtrlMemSlave(ifcId, intr);
   let memslave  <- mkMemMethodMuxOut(ctrlPort.memSlave,indications);
   interface PhysMemSlave slave = memslave;
   interface ReadOnly interrupt = ctrlPort.interrupt;
   interface WriteOnly num_portals = ctrlPort.num_portals;
endmodule
