package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * {@link java.io.InputStream} decorator to count bytes flowed through the stream.
 *
 */
public class ByteCountInputStream extends java.io.InputStream {

    // TODO: mark/reset should be simple to implement.


    private final java.io.InputStream origin;
    private long numBytes = 0;

    public ByteCountInputStream( java.io.InputStream origin ){
        this.origin = origin;
    }

    /** @return How many bytes had flown through this stream. */
    public long getByteCount() {
        return numBytes;
    }

    @Override
    public int read() throws java.io.IOException {
        int b = origin.read();
        if( b >= 0 ){
            numBytes += 1; }
        return b;
    }

    @Override
    public int read( byte[] b, int off, int len ) throws java.io.IOException {
        int readLen = origin.read(b, off, len);
        if( readLen > 0 ){
            numBytes += readLen;
        }
        return readLen;
    }

    @Override
    public int available() throws java.io.IOException {
        return origin.available();
    }

    @Override
    public void close() throws java.io.IOException {
        origin.close();
    }

    //@Override
    //public synchronized void mark( int readlimit ) {
    //    origin.mark(readlimit);
    //}

    //@Override
    //public synchronized void reset() throws java.io.IOException {
    //    origin.reset();
    //}

    @Override
    public boolean markSupported() {
        return false;
        //return origin.markSupported();
    }

}
