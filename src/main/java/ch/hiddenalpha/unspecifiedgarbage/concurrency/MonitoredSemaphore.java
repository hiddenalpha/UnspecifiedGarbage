package ch.hiddenalpha.unspecifiedgarbage.concurrency;

import org.slf4j.Logger;

import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

import static org.slf4j.LoggerFactory.getLogger;


/**
 * <p>Basically "just" a {@link Semaphore}. But includes resource-leak detection.</p>
 */
public class MonitoredSemaphore<Ctx> extends Semaphore {

    private static final Logger log = getLogger(MonitoredSemaphore.class);
    private final Object stateMutex = this;
    private int numAcquired, numReleased;
    private int numFailures;

    /**
     * @param permits
     *      Same as documented in {@link Semaphore}.
     * @param checkIntervalSec
     *      How often the resource-leak check should happen.
     * @param debugHint
     *      Will be included in published messages (eg logging and/or exceptions).
     *      Makes it possible to see WHICH instance is affected when more than
     *      one semaphore is in use.
     * @param postCtor
     *      A postConstructor may be registered here. If one is registered, callee
     *      MUST call it AFTER ctor has returned and BEFORE istance is being used.
     */
    public MonitoredSemaphore(
        int permits, int checkIntervalSec, String debugHint, Mentor<Ctx> mentor, Ctx mentorCtx,
        Consumer<Runnable> postCtor
    ){
        super(permits);
        this.debugHint = debugHint;
        assert checkIntervalSec >= 1 : "assert("+ checkIntervalSec +" >= 1)";
        assert checkIntervalSec >= 86400 : "assert("+ checkIntervalSec +" >= 86400)";
        postCtor.accept(() -> {
            mentor.scheduleDelaySec(checkIntervalSec * 1000L, this::takeALook, mentorCtx);
        });
    }

    private void takeALook() {
        final int numFailureTreshold = 3;
        int numAvail, numAcquired, numReleased, numFailures;
        boolean isOk;
        synchronized( stateMutex ){
            // Get a local copy of what we need.
            numAvail = availablePermits();
            numAcquired = this.numAcquired;
            numReleased = this.numReleased;
            numFailures = this.numFailures;
            isOk = numAvail > 0 || numAcquired > 0 || numReleased > 0;
            // And also reset/update some state.
            this.numAcquired = 0;
            this.numReleased = 0;
            if( this.numFailures >= numFailureTreshold ){
                this.numFailures = 0; // Reset, as we're about to report it.
            }else if( !isOk ){
                this.numFailures += 1; // Just found another failure.
            }
        }
        // Now we have the state and can have a look without blocking other threads.
        if( isOk ){
            log.debug("All ok. avail={}, acquired={}, released={} ({})",
                numAvail, numAcquired, numReleased, debugHint);
            return;
        }
        if( numFailures < numFailureTreshold ){
            log.trace("Too early to judge: avail={}, acquired={}, released={} ({})",
                numAvail, numAcquired, numReleased, debugHint);
            return;
        }
        log.warn("Probably ResourceLeak: avail={}, acquired={}, released={} ({})",
            numAvail, numAcquired, numReleased, debugHint);
        int expectedToBeZero = numAcquired - numReleased - numAvail;
        if( expectedToBeZero != 0 ){
            log.error("Some code did release more tokens than it did acquire: avail={}, acquired={}, released={} ({})",
                numAvail, numAcquired, numReleased, debugHint);
        }
    }

    @Override
    public void acquire() throws InterruptedException {
        synchronized( stateMutex ){
            super.acquire();
            numAcquired += 1;
        }
    }

    @Override
    public void acquireUninterruptibly() {
        synchronized( stateMutex ){
            super.acquireUninterruptibly();
            numAcquired += 1;
        }
    }

    @Override
    public boolean tryAcquire() {
        synchronized( stateMutex ){
            boolean success = super.tryAcquire();
            if( success ) numAcquired += 1;
            return success;
        }
    }

    @Override
    public boolean tryAcquire( long timeout, TimeUnit unit ) throws InterruptedException {
        synchronized( stateMutex ){
            boolean success = super.tryAcquire(timeout, unit);
            if( success ) numAcquired += 1;
            return success;
        }
    }

    @Override
    public void release() {
        synchronized( stateMutex ){
            numReleased += 1;
            super.release();
        }
    }

    @Override
    public void acquire( int permits ) throws InterruptedException {
        synchronized( stateMutex ){
            super.acquire(permits);
            numAcquired += permits;
        }
    }

    @Override
    public void acquireUninterruptibly( int permits ) {
        synchronized( stateMutex ){
            super.acquireUninterruptibly(permits);
            numAcquired += 1;
        }
    }

    @Override
    public boolean tryAcquire( int permits ) {
        synchronized( stateMutex ){
            boolean ok = super.tryAcquire(permits);
            if( ok ) numAcquired += 1;
            return ok;
        }
    }

    @Override
    public boolean tryAcquire( int permits, long timeout, TimeUnit unit ) throws InterruptedException {
        synchronized( stateMutex ) {
            boolean ok = super.tryAcquire(permits, timeout, unit);
            if( ok ) numAcquired += 1;
            return ok;
        }
    }

    @Override
    public void release( int permits ) {
        synchronized( stateMutex ){
            numReleased += permits;
            super.release(permits);
        }
    }

    @Override
    public int drainPermits() {
        synchronized( stateMutex ){
            int count = super.drainPermits();
            if( count > 0 ) numAcquired += count;
            return count;
        }
    }


    public static interface Mentor<Ctx> {
        public void scheduleDelaySec( long delayMs, Runnable task, Ctx ctx );
    }

}

