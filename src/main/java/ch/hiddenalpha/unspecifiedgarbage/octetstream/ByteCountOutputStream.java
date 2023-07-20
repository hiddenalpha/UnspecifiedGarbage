package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * {@link java.io.OutputStream} decorator to count bytes flowed through the stream.
 */
public class ByteCountOutputStream extends java.io.OutputStream {

    private final java.io.OutputStream origin;
    private long numBytes = 0;

    public ByteCountOutputStream( java.io.OutputStream origin ){
        this.origin = origin;
    }

    /** @return How many bytes had flown through this stream. */
    public long getByteCount() { return numBytes; }

    @Override
    public void write( int b ) throws java.io.IOException {
        numBytes += 1;
        origin.write(b);
    }

    @Override
    public void write( byte[] b, int off, int len ) throws java.io.IOException {
        numBytes += len;
        origin.write(b, off, len);
    }

    @Override
    public void flush() throws java.io.IOException { origin.flush(); }

    @Override
    public void close() throws java.io.IOException { origin.close(); }

}
