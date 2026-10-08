#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>

static int (*real_pthread_mutex_lock)(pthread_mutex_t *mutex) = NULL;

__attribute__((constructor)) static void setup_random_scheduler() {
  real_pthread_mutex_lock = dlsym(RTLD_NEXT, "pthread_mutex_lock");
  char *seed_str = getenv("PCT_SEED");
  unsigned int seed = seed_str ? atoi(seed_str) : 42;
  srand(seed);
}

int pthread_mutex_lock(pthread_mutex_t *mutex) {
  // Naive Random Scheduler (Thomson et al., 2014)
  // 10% probability of releasing the remaining CPU time (forced context switch)
  if (rand() % 100 < 10) {
    sched_yield();
  }

  return real_pthread_mutex_lock(mutex);
}
