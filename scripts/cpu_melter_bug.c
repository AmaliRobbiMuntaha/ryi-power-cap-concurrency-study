#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define NUM_THREADS 8

pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
long long shared_balance = 0;

// Separate mutex so that the target result calculation isn't affected by the
// bug
pthread_mutex_t expected_lock = PTHREAD_MUTEX_INITIALIZER;
long long expected_updates = 0;

// The “blackhole” variable prevents the compiler (GCC) from removing
// mathematical functions
volatile double blackhole = 0;

void *worker(void *arg) {
  time_t start = time(NULL);
  long long local_updates = 0;

  // Loop continuously for exactly 10 seconds
  while (time(NULL) - start < 10) {

    // 1. THERMAL BURN (15W Power Limit / 80 Celsius)
    // This intensive workload ensures the CPU runs at 100% capacity nonstop
    double x = 1.5;
    for (int i = 0; i < 500000; i++) {
      x = sin(x) * cos(x) + 1.0001;
    }
    blackhole = x;

    // 2. CRITICAL PHASE (Race Condition / Atomicity)
    pthread_mutex_lock(&lock);
    long long temp = shared_balance;
    pthread_mutex_unlock(&lock);

    // The delay is very short. This is where the PCT will randomize the thread
    // schedule!
    for (volatile int k = 0; k < 100; k++)
      ;

    pthread_mutex_lock(&lock);
    shared_balance = temp + 10;
    pthread_mutex_unlock(&lock);

    local_updates++;
  }

  // Record the number of updates that should have occurred
  pthread_mutex_lock(&expected_lock);
  expected_updates += local_updates;
  pthread_mutex_unlock(&expected_lock);

  return NULL;
}

int main() {
  pthread_t t[NUM_THREADS];
  printf("Starting the Thermal Burner + Bug Simulator (Duration: 10 "
         "Seconds)...\n");

  for (int i = 0; i < NUM_THREADS; i++) {
    pthread_create(&t[i], NULL, worker, NULL);
  }
  for (int i = 0; i < NUM_THREADS; i++) {
    pthread_join(t[i], NULL);
  }

  long long expected_balance = expected_updates * 10;
  printf("Final Results: %lld | It should be: %lld\n", shared_balance,
         expected_balance);

  // ORACLE: Bug Classification
  if (shared_balance != expected_balance) {
    printf(">>> BUG DETECTED! <<<\n");
    return 134; // Send signal 134 to the Bash script
  }

  printf(">>> OK <<<\n");
  return 0;
}
