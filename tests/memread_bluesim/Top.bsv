// (c) 2013 Quanta Research Cambridge, Inc.

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

// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import PCIE::*;
import DefaultValue::*;

// portz libraries
import MemServer::*;
import MMU::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import MemTypes::*;
import Leds::*;
import HostInterface::*;
import MemSlaveEngine::*;
import AddressGenerator::*;

// generated by tool
import MemreadRequestWrapper::*;
import DmaDebugRequestWrapper::*;
import MMUConfigRequestWrapper::*;
import MemreadIndicationProxy::*;
import DmaDebugIndicationProxy::*;
import MMUConfigIndicationProxy::*;

// defined by user
import Memread::*;

typedef enum {MemreadIndication, MemreadRequest, HostDmaDebugIndication, HostDmaDebugRequest, HostMMUConfigRequest, HostMMUConfigIndication} IfcNames deriving (Eq,Bits);

module mkPortalTop(PortalTop#(PhysAddrWidth,DataBusWidth,Empty,1));

   MemreadIndicationProxy memreadIndicationProxy <- mkMemreadIndicationProxy(MemreadIndication);
   Memread memread <- mkMemread(memreadIndicationProxy.ifc);
   MemreadRequestWrapper memreadRequestWrapper <- mkMemreadRequestWrapper(MemreadRequest,memread.request);

   Vector#(1, ObjectReadClient#(DataBusWidth)) readClients = cons(memread.dmaClient, nil);
   MMUConfigIndicationProxy hostMMUConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMUConfigIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMUConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMUConfigRequest, hostMMU.request);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   MemServer#(PhysAddrWidth,DataBusWidth,1) dma <- mkMemServerR(hostDmaDebugIndicationProxy.ifc, readClients, cons(hostMMU,nil));
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   MemMaster#(PhysAddrWidth,DataBusWidth) dma1 = (interface MemMaster;
	  interface MemReadClient read_client;
	     interface Get readReq;
		method ActionValue#(MemRequest#(PhysAddrWidth)) get() if (False);
		   return ?;
	        endmethod
	     endinterface
	  endinterface
	  interface MemWriteClient write_client;
	     interface Get writeReq;
		method ActionValue#(MemRequest#(PhysAddrWidth)) get() if (False);
		   return ?;
	        endmethod
	     endinterface
	  endinterface
      endinterface);

   Reg#(Bit#(32)) cycles <- mkReg(0);
   Reg#(Bit#(32)) reqCycles <- mkReg(0);
   Reg#(Bit#(32)) lastCycle <- mkReg(0);
   rule count;
      cycles <= cycles + 1;
      if (cycles == 1)
	 $dumpvars();
      if (cycles == 10000)
	 $dumpoff();
   endrule

   let my_id = PciId {bus: 4, dev: 2, func: 0};
   MemSlaveEngine#(DataBusWidth) memSlaveEngine <- mkMemSlaveEngine(my_id);
   mkConnection(dma.masters[0], memSlaveEngine.slave);

   AddressGenerator#(32, DataBusWidth) addrGenerator <- mkAddressGenerator();

   FIFO#(TLPData#(16)) tlpFifo <- mkSizedFIFO(1);
   FIFO#(TLPData#(16)) tlpOutFifo <- mkSizedFIFO(16);

   rule displayTlp;
      let tlp <- memSlaveEngine.tlp.request.get();
      TLPMemory4DWHeader hdr4dw = unpack(tlp.data);
      TLPMemoryIO3DWHeader hdr3dw = unpack(tlp.data);
      let newReqCycles = cycles;
      Bit#(32) addr = extend(hdr3dw.addr);
      TLPTag   tag  = hdr3dw.tag;
      TLPLength burstLen = hdr3dw.length;

      if (tlp.sof && hdr4dw.format == MEM_READ_4DW_NO_DATA) begin
	 $display("%d 4dw req %h len=%d %d", cycles-reqCycles, hdr4dw.addr<<2, hdr3dw.length, fromInteger(valueOf(DataBusWidth)));

	 addr = truncate(hdr4dw.addr);
	 tag = hdr4dw.tag;
	 burstLen = hdr4dw.length;
      end
      else if (tlp.sof && hdr3dw.format == MEM_READ_3DW_NO_DATA) begin
	 $display("%d 3dw req %h len=%h %d", cycles-reqCycles, hdr3dw.addr<<2, hdr4dw.length, fromInteger(valueOf(DataBusWidth)));
      end
      else if (tlp.sof) begin
	 $display("%d sof %h", cycles-reqCycles, tlp.data);
      end
      else begin
	 $display("unknown tlp %h", tlp);
      end

      addrGenerator.request.put(MemRequest {addr: addr, burstLen: burstLen<<2, tag: truncate(tag) });
      reqCycles <= newReqCycles;
      tlpFifo.enq(tlp);

      TLPData#(16) resptlp;
      resptlp.sof = True;
      resptlp.eof = (burstLen == 1);
      resptlp.be = 16'hffff;
      resptlp.hit = 0;
      Vector#(4, Bit#(32)) vec = unpack(0);
      TLPCompletionHeader completion = defaultValue;
      completion.format = MEM_WRITE_3DW_DATA;
      completion.pkttype = COMPLETION;
      completion.relaxed = hdr3dw.relaxed;
      completion.nosnoop = hdr3dw.nosnoop;
      completion.length = hdr3dw.length;
      completion.tclass = hdr3dw.tclass;
      completion.cmplid = my_id;
      completion.tag = truncate(hdr3dw.tag);
      completion.bytecount = extend(burstLen)*4;
      completion.reqid = hdr3dw.reqid;
      completion.loweraddr = getLowerAddr(hdr3dw.addr, hdr3dw.firstbe);
      completion.data = byteSwap(0);

      resptlp.data = pack(completion);
      tlpOutFifo.enq(resptlp);
      lastCycle <= cycles;
      $display("%d: gen tlp resp %h burstLen %d", cycles-lastCycle, resptlp, burstLen);
   endrule
   rule dataRule;
      let addrBeat <- addrGenerator.addrBeat.get();
      if (addrBeat.last)
	 tlpFifo.deq();
      TLPData#(16) resptlp;
      resptlp.sof = False;
      resptlp.eof = addrBeat.last;
      resptlp.be = 16'hffff;
      resptlp.hit = 0;
      if (addrBeat.last) begin
	 resptlp.be = 16'hfff0;
      end
      Vector#(4, Bit#(32)) vec = unpack(0);
      resptlp.data = pack(vec);
      $display("     addr %h", addrBeat.addr << 2);
      $display("%d: gen tlp data %h last=%d", cycles-lastCycle, resptlp, addrBeat.last);
      lastCycle <= cycles;
      tlpOutFifo.enq(resptlp);
   endrule
   rule tlpout;
      let resptlp <- toGet(tlpOutFifo).get();
      memSlaveEngine.tlp.response.put(resptlp);
   endrule
   Vector#(6,StdPortal) portals;
   portals[0] = hostDmaDebugIndicationProxy.portalIfc; 
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = hostDmaDebugRequestWrapper.portalIfc;
   portals[3] = memreadRequestWrapper.portalIfc;
   portals[4] = hostMMUConfigRequestWrapper.portalIfc;
   portals[5] = hostMMUConfigIndicationProxy.portalIfc;

   
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = cons(dma1,nil);
   interface leds = default_leds;
   interface Empty pins; endinterface      
endmodule : mkPortalTop
