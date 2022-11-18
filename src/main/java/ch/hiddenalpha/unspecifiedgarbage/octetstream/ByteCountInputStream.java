package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.IOException;
import java.io.InputStream;


/**
 * {@link InputStream} decorator to count bytes flowed through the stream.
 *
 */
public class ByteCountInputStream extends InputStream {

    // TODO: mark/reset should be simple to implement.


    private final InputStream origin;
    private long numBytes = 0;

    public ByteCountInputStream( InputStream origin ){
        this.origin = origin;
    }

    /** @return How many bytes had flown through this stream. */
    public long getByteCount() {
        return numBytes;
    }

    @Override
    public int read() throws IOException {
        int b = origin.read();
        if( b >= 0 ){
            numBytes += 1; }
        return b;
    }

    @Override
    public int read( byte[] b, int off, int len ) throws IOException {
        int readLen = origin.read(b, off, len);
        if( readLen > 0 ){
            numBytes += readLen;
        }
        return readLen;
    }

    @Override
    public int available() throws IOException {
        return origin.available();
    }

    @Override
    public void close() throws IOException {
        origin.close();
    }

    //@Override
    //public synchronized void mark( int readlimit ) {
    //    origin.mark(readlimit);
    //}

    //@Override
    //public synchronized void reset() throws IOException {
    //    origin.reset();
    //}

    @Override
    public boolean markSupported() {
        return false;
        //return origin.markSupported();
    }

}
