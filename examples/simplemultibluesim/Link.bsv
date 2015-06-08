/* Copyright (c) 2015 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import Vector::*;
import FIFO::*;
import GetPut::*;
import Pipe::*;
import Connectable::*;
import CtrlMux::*;
import Portal::*;
import HostInterface::*;
import CnocPortal::*;
import SimLink::*;
import LinkIF::*;
import Simple::*;
import SimpleRequest::*;
import LinkRequest::*;

module mkLink#(SimpleRequest simple2IndicationProxy)(Link);
   // the indications from simpleRequest will be connected to the request interface to simpleReuqest2
   SimpleRequestOutput simple1Output <- mkSimpleRequestOutput();
   Simple simple1 <- mkSimple(simple1Output.ifc);

   Simple simple2 <- mkSimple(simple2IndicationProxy);
   SimpleRequestInput simple2Input <- mkSimpleRequestInput();
   mkConnection(simple2Input.pipes, simple2.request);

   // now connect them via a Cnoc link
   SimLink#(32) link <- mkSimLink(17);

   let msgIndication <- mkPortalMsgIndication(22, simple1Output.portalIfc.indications, simple1Output.portalIfc.messageSize);
   mkConnection(msgIndication.message, link.tx);
   let msgRequest <- mkPortalMsgRequest(23, simple2Input.portalIfc.requests);
   mkConnection(link.rx, msgRequest.message);

   interface SimpleRequest simpleRequest = simple1.request;
   interface LinkRequest linkRequest;
      method Action start(Bool l);
	 $display("Link.start l=%d", l);
	 link.start(l);
      endmethod
   endinterface

endmodule : mkLink

export mkLink;
export Link;