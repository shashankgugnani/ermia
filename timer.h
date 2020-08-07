/*-
 *   BSD LICENSE
 *
 *   Copyright (c) 2018-2019, Shashank Gugnani.
 *   All rights reserved.
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 *     * Neither the name of the copyright holder nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 *   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 *   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef QF_TIMER_H
#define QF_TIMER_H

#include "stdinc.h"

#ifndef CONFIG_TIMER
#define CONFIG_TIMER 1
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Timer stuff
 * Usage:
 * TIMER_START("xyz")
 * xyz()
 * TIMER_END("xyz")
 * Info:
 * Timer will print time spent in the xyz routine as follows:
 * xyz took a.bc us
 * Nested timers are supported as well;
 * Define MAX_TIMERS to change the maximum number
 * of concurrent timers
 */
#define MAX_TIMERS 10
__attribute__((used))
static int timers = 0;
__attribute__((used))
static double start_time[MAX_TIMERS];
__attribute__((used))
static double end_time[MAX_TIMERS];

/**
 * Get microsecond precision timestamp.
 */
static inline double
get_timestamp(void)
{
    struct timeval tv;

    if (gettimeofday(&tv, NULL)) {
        perror("gettimeofday");
        return 0;
    }
    return (double)tv.tv_sec * 1000000 + (double)tv.tv_usec;
}

/**
 * Read cpu timestamp counter.
 */
static inline uint64_t
rdtsc(void)
{
    unsigned int lo, hi;
    __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

#define TIMER_START(...)                                    \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
	        start_time[timers++] = get_timestamp();         \
	    }                                                   \
    } while (0)

#define TIMER_END(...)                                      \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
            end_time[--timers] = get_timestamp();           \
            fprintf(stderr, __VA_ARGS__);                   \
            fprintf(stderr, " took %f us\n",                \
                end_time[timers] - start_time[timers]);     \
        }                                                   \
    } while (0)

static inline double
TIMER_ELAPSED(void)
{
#if CONFIG_TIMER
    end_time[--timers] = get_timestamp();
    return end_time[timers] - start_time[timers];
#else
    return 0;
#endif
}

/**
 * Thread safe timers
 * Usage:
 * TIMER_MT_REGISTER() [once per thread]
 * TIMER_MT_START("xyz")
 * xyz()
 * TIMER_MT_END("xyz")
 */
#define TIMER_MT_REGISTER()                                 \
    double start_mt_time, end_mt_time;                      \
    (void)(end_mt_time);

#define TIMER_MT_START(...)                                 \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
            start_mt_time = get_timestamp();                \
        }                                                   \
    } while (0)

#define TIMER_MT_END(...)                                   \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
            end_mt_time = get_timestamp();                  \
            fprintf(stderr, __VA_ARGS__);                   \
            fprintf(stderr, " took %f us\n",                \
                end_mt_time - start_mt_time);               \
        }                                                   \
    } while (0)

#define TIMER_MT_ELAPSED(...)                               \
    (get_timestamp() - start_mt_time)

/**
 * Thread safe high precision timers
 * Usage:
 * TIMER_HP_REGISTER() [once per thread]
 * TIMER_HP_START("xyz")
 * xyz()
 * TIMER_HP_END("xyz")
 */
#define TIMER_HP_REGISTER()                                 \
    uint64_t start_hp_time, end_hp_time;                    \
    (void)(end_hp_time);

#define TIMER_HP_START(...)                                 \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
            start_hp_time = rdtsc();                        \
        }                                                   \
    } while (0)

#define TIMER_HP_END(...)                                   \
    do {                                                    \
        if (CONFIG_TIMER) {                                 \
            end_hp_time = rdtsc();                          \
            fprintf(stderr, __VA_ARGS__);                   \
            fprintf(stderr, " took %" PRIu64 " cycles\n",   \
                    end_hp_time - start_hp_time);           \
        }                                                   \
    } while (0)

#define TIMER_HP_ELAPSED(...)                               \
    (rdtsc() - start_hp_time)

#ifdef __cplusplus
}
#endif

#endif /* QF_TIMER_H */
