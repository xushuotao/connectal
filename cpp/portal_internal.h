
// Copyright (c) 2013-2014 Quanta Research Cambridge, Inc.

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

#ifndef _PORTAL_H_
#define _PORTAL_H_

#include <stdint.h>
#include <sys/types.h>
#include <linux/ioctl.h>
#include <sys/ioctl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <assert.h>
#include <semaphore.h>
#include <pthread.h>
#include <unistd.h>

typedef unsigned long dma_addr_t;

#include "sock_utils.h"

#define MAX_TIMERS 50

void start_timer(unsigned int i);
uint64_t lap_timer(unsigned int i);
void init_timer(void);
uint64_t catch_timer(unsigned int i);
void print_timer(int loops);

// uses the default poller
void* portalExec(void* __x);
/* fine grained functions for building custom portalExec */
void* portalExec_init(void);
void* portalExec_poll(int timeout);
void* portalExec_event(void);
void portalExec_start();
void portalExec_end(void);
void portalTrace_start();
void portalTrace_stop();
int setClockFrequency(int clkNum, long requestedFrequency, long *actualFrequency);

extern PortalPoller *defaultPoller;
extern int portalExec_timeout;

typedef struct {
    uint64_t total, min, max, over;
} TIMETYPE;

class Portal;
class PortalPoller {
private:
  Portal **portal_wrappers;
  struct pollfd *portal_fds;
  int numFds;
public:
  PortalPoller();
  int registerInstance(Portal *portal);
  int unregisterInstance(Portal *portal);
  void *portalExec_init(void);
  void *portalExec_poll(int timeout);
  void *portalExec_event(void);
  void portalExec_end(void);
  void portalExec_start();
  int portalExec_timeout;
  int stopping;
  sem_t sem_startup;

  void* portalExec(void* __x);
};

class PortalInternalCpp
{
 public:
  PortalInternal pint;
  PortalInternalCpp(int id) { init_portal_internal(&pint, id); };
  ~PortalInternalCpp() {
    if (pint.fpga_fd > 0) {
        ::close(pint.fpga_fd);
        pint.fpga_fd = -1;
    }    
  };
};

class Portal : public PortalInternalCpp
{
 public:
  Portal(int id, PortalPoller *poller = 0) : PortalInternalCpp(id) {
    if (poller == 0)
      poller = defaultPoller;
    pint.poller = poller;
    pint.poller->registerInstance(this);
  };
  ~Portal() { pint.poller->unregisterInstance(this); };
  virtual int handleMessage(unsigned int channel) { return 0; };
};

#endif // _PORTAL_H_
