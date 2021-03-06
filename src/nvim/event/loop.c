#include <stdarg.h>
#include <stdint.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/process.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/loop.c.generated.h"
#endif

typedef struct idle_event {
  uv_idle_t idle;
  Event event;
} IdleEvent;


void loop_init(Loop *loop, void *data)
{
  uv_loop_init(&loop->uv);
  loop->uv.data = loop;
  loop->children = kl_init(WatcherPtr);
  loop->children_stop_requests = 0;
  loop->events = queue_new_parent(loop_on_put, loop);
  loop->fast_events = queue_new_child(loop->events);
  uv_signal_init(&loop->uv, &loop->children_watcher);
  uv_timer_init(&loop->uv, &loop->children_kill_timer);
  uv_timer_init(&loop->uv, &loop->poll_timer);
}

void loop_poll_events(Loop *loop, int ms)
{
  static int recursive = 0;

  if (recursive++) {
    abort();  // Should not re-enter uv_run
  }

  uv_run_mode mode = UV_RUN_ONCE;

  if (ms > 0) {
    // Use a repeating timeout of ms milliseconds to make sure
    // we do not block indefinitely for I/O.
    uv_timer_start(&loop->poll_timer, timer_cb, (uint64_t)ms, (uint64_t)ms);
  } else if (ms == 0) {
    // For ms == 0, we need to do a non-blocking event poll by
    // setting the run mode to UV_RUN_NOWAIT.
    mode = UV_RUN_NOWAIT;
  }

  uv_run(&loop->uv, mode);

  if (ms > 0) {
    uv_timer_stop(&loop->poll_timer);
  }

  recursive--;  // Can re-enter uv_run now
  queue_process_events(loop->fast_events);
}

void loop_on_put(Queue *queue, void *data)
{
  Loop *loop = data;
  // Sometimes libuv will run pending callbacks(timer for example) before
  // blocking for a poll. If this happens and the callback pushes a event to one
  // of the queues, the event would only be processed after the poll
  // returns(user hits a key for example). To avoid this scenario, we call
  // uv_stop when a event is enqueued.
  uv_stop(&loop->uv);
}

void loop_close(Loop *loop)
{
  uv_close((uv_handle_t *)&loop->children_watcher, NULL);
  uv_close((uv_handle_t *)&loop->children_kill_timer, NULL);
  uv_close((uv_handle_t *)&loop->poll_timer, NULL);
  do {
    uv_run(&loop->uv, UV_RUN_DEFAULT);
  } while (uv_loop_close(&loop->uv));
}

static void timer_cb(uv_timer_t *handle)
{
}
