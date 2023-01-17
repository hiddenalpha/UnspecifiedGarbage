package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.IOException;
import java.io.OutputStream;


/**
 * {@link OutputStream} decorator to count bytes flowed through the stream.
 */
public class ByteCountOutputStream extends OutputStream {
    private final OutputStream origin;
    private long numBytes = 0;

    public ByteCountOutputStream( OutputStream origin ){
        this.origin = origin;
    }

    /** @return How many bytes had flown through this stream. */
    public long getByteCount() { return numBytes; }

    @Override
    public void write( int b ) throws IOException {
        numBytes += 1;
        origin.write(b);
    }

    @Override
    public void write( byte[] b, int off, int len ) throws IOException {
        numBytes += len;
        origin.write(b, off, len);
    }

    @Override
    public void flush() throws IOException { origin.flush(); }

    @Override
    public void close() throws IOException { origin.close(); }

}
