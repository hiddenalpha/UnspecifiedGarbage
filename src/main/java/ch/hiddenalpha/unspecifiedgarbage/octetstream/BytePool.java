package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;


/**
 * Is a shared resource of a maximum amount of bytes. Callers then can request
 * bytes from the pool as an {@link AutoCloseable}.
 *
 * This allows to apply an upper limit of total bytes to allocate cross over
 * multiple threads, so helps to prevent OutOfMemory issues, but still allows to
 * use large buffers.
 */
public class BytePool {

    private final long poolSize;
    private final AtomicLong pool;

    public BytePool( long maxBytes ){
        this.poolSize = maxBytes;
        this.pool = new AtomicLong(maxBytes);
    }

    /**
     * Here a caller can request to allocate an amount of bytes. The pool then
     * tries to satisfy that request. But be aware that the caller may only receive
     * less than requested. This can happen for example if the pool is exhausted.
     */
    public AllocatedBytes alloc( int amount ){
        return new AllocatedBytes(amount);
    }

    /**
     * Returns a snapshot of how much of the pool is in use. Most usually handy
     * for metrics only.
     */
    public Utilization getUtilization() {
        return new Utilization() {
            final long used = pool.get();
            @Override public long numUsedBytes() { return used; }
            @Override public long numTotalBytes() { return poolSize; }
        };
    }

    private void shrinkTo( AllocatedBytes allocdBytes, int newLength ){
        if( newLength < 0 ){
            throw new IllegalArgumentException("length cannot be smaller than 0");
        }
        if( allocdBytes.amount.get() == newLength ){
            return; // Nothing do to. Already up-to-date.
        }
        // Amount does change. Update accordingly.
        int diff = 0;
        // 1st we give up our bytes.
        {
            int oldVal;
            do{
                oldVal = allocdBytes.amount.get();
                // We also need to calculate the diff so we can add it back to the pool further below.
                diff = oldVal - newLength;
                if( diff < 0 ){
                    throw new IllegalArgumentException("Cannot shrink below zero"); }
            }while( !allocdBytes.amount.compareAndSet(oldVal, newLength) );
        }
        // Then we give them back to the pool.
        {
            long oldVal, newVal;
            do{
                oldVal = pool.get();
                newVal = oldVal + diff;
            }while( !pool.compareAndSet(oldVal, newVal) );
        }
        synchronized( BytePool.this ){
            BytePool.this.notifyAll();
        }
    }

    /**
     * Represents the resource which we handle over to our client.
     */
    public class AllocatedBytes implements AutoCloseable {
        private final AtomicInteger amount = new AtomicInteger(); // How many bytes this instance owns.

        private AllocatedBytes( int requested ){
            long oldVal, newVal;
            do{
                oldVal = pool.get();
                newVal = Math.max(0, oldVal - requested);
            }while( !pool.compareAndSet(oldVal, newVal) );
            long amountLong = oldVal - newVal;
            this.amount.set((int) amountLong);
            if( this.amount.get() != amountLong ){
                throw new RuntimeException("A moron just tried to allocate " + amountLong + " bytes (more than INT_MAX)");
            }
        }

        /** @return How much bytes this resource actually could acquire. */
        public int getAmount(){ return amount.get(); }

        @Override
        public void close(){ shrinkTo(0); }

        /**
         * Example usage:<br/><br/>
         * <code>
         *     // Don't know exactly how much we need. Make a guess.<br/>
         *     allocdBytes = pool.alloc(42);<br/>
         *     int actuallyNeeded = source.read(buf, 0, allocdBytes.getAmount());<br/>
         *     // Now we know exactly how much we need and can free the rest.<br/>
         *     allocdBytes.shrinkTo(actuallyNeeded);<br/>
         * </code>
         */
        public void shrinkTo( int length ) {
            BytePool.this.shrinkTo(this, length);
        }

    }


    public static interface Utilization {
        long numUsedBytes();
        long numTotalBytes();
    }

}
