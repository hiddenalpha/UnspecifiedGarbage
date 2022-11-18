package ch.hiddenalpha.unspecifiedgarbage.time;


public class TimeUtils {

    /**
     * Delegates to {@link #nanosToEpochMillis(long, long, long)} and assumes
     * that the 'nanos' value was measure in the same JVM process as this call
     * here occurs and is not too long back.
     */
    public static long nanosToEpochMillis(long nanos) {
        return nanosToEpochMillis(nanos, System.nanoTime(), System.currentTimeMillis());
    }

    public static long nanosToEpochMillis(long nanos, long referenceNanos, long referenceEpochMs) {
        long diffNs = nanos - referenceNanos;
        if (diffNs < (Long.MIN_VALUE >> 1) || diffNs > (Long.MAX_VALUE>>1)) {
            // Looks as System.nanoTime() did overflow while measurement. So flip result too.
            diffNs -= Long.MAX_VALUE;
        }
        return referenceEpochMs + (diffNs / 1_000_000);
    }

    /**
     * Computers cannot represent all existing integers. Due to how integers
     * are represented in computers, they are not infinite but more like a circle.
     * Speak when we infinitely increment an integer, it overflows and (usually)
     * continues to walk around this (imaginary) circle.
     *
     * This function takes two of those numbers on this circle and returns the
     * smallest distance to travel on the circle between them. Here some examples:
     * - f(7, 13) = 6
     * - f(-7, +11) = 18
     * - f(LONG_MIN, LONG_MAX) = 1
     * - f(-9223372036854775805, 9223372036854775802) = 9
     *
     * This can be handy for example in conjunction with {@link System#nanoTime()}.
     * Because in case of overflows between measuring begNs and endNs a simple subtraction
     * would lead to uselessly large results. So we can use it as:
     * long begNs = System.nanoTime();
     * long endNs = System.nanoTime();
     * long durationNs = nanosSmallDiff(begNs, endNs);
     *
     * WARN: Do NOT use this if your distance can reach (LONG_MAX / 2). Because
     * in this case you would get wrong (too small) results.
     */
    public static long nanosSmallDiff(long a, long b) {
        return (a - b >= 0) ? a - b : b - a;
    }

}
