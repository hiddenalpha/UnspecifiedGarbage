package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * Converts an octet-stream to a push-source of byte-arrays.
 */
public class ByteChunkOStream extends java.io.OutputStream {

    private final int chunkSize; // Hint of how large our produced chunks should be.
    private byte[] buf;
    private int bufUsedBytes; // How many bytes actually are in-use.
    private final ChunkHandler onChunk;
    private EndHandler onEnd;

    public ByteChunkOStream( int chunkSize, ChunkHandler onChunk, EndHandler onEnd ){
        assert onChunk != null : "ChunkHandler cannot be null";
        assert chunkSize >= 1 : "chunk size too small: "+ chunkSize;
        this.chunkSize = chunkSize;
        this.buf = new byte[chunkSize];
        this.onChunk = onChunk;
        this.onEnd = onEnd;
    }

    @Override
    public void write( byte[] b, int off, int len ) throws java.io.IOException {
        int remainingBytes = len;
        while( true ){
            int appendedBytes = appendToBuffer(b, off, len);
            remainingBytes -= appendedBytes;
            if( remainingBytes > 0 ){
                publishBuffer();
                // Adjust cursors then loop and continue write remainder.
                off += appendedBytes;
                len -= appendedBytes;
            }else if( remainingBytes == 0 ){
                break; // Done :)
            }else{
                throw new UnsupportedOperationException("Huh?!? why is remainingBytes "+ remainingBytes +"?");
            }
        }
    }

    @Override
    public void write( int b ) throws java.io.IOException {
        while( true ){
            if( appendToBuffer(b) == 0 ){
                publishBuffer();
                // try append again. Should work now as buffer is empty.
            }else{
                break; // Done :)
            }
        }
    }

    @Override
    public void flush() throws java.io.IOException {
        publishBuffer();
    }

    @Override
    public void close() throws java.io.IOException {
        flush();
        buf = null; // Think for GC
        EndHandler tmp = onEnd;
        onEnd = null; // Reduce probability of calling it multiple times
        if( tmp != null ){
            tmp.run();
        }
    }

    /**
     * Appends as many bytes as possible to the internal buffer.
     * @return
     *      Number of bytes effectively copied.
     */
    private int appendToBuffer( byte[] b, int off, int len ) {
        int availSpace = buf.length - bufUsedBytes;
        int bytesToCopy = Math.min(availSpace, len);
        System.arraycopy(b, off, buf, bufUsedBytes, bytesToCopy);
        bufUsedBytes += bytesToCopy;
        return bytesToCopy;
    }

    /** Same as {@link #appendToBuffer(byte[], int, int)} but for appending a single byte */
    private int appendToBuffer( int b ) {
        if( bufUsedBytes < buf.length ){
            buf[bufUsedBytes++] = (byte)b;
            return 1;
        }else{
            return 0;
        }
    }

    private void publishBuffer() throws java.io.IOException {
        if( bufUsedBytes == 0 ){
            return; // Nothing to do.
        }
        byte[] bufToPublish;
        if( bufUsedBytes == buf.length ){
            // No need to copy stuff around.
            bufToPublish = buf;
            buf = new byte[chunkSize];
        }else{
            // Buffer is not completely full. So we have to make a copy so
            // buf.length does report the correct value to callee. That implies
            // that we can continue using our existing buffer for ourself.
            bufToPublish = java.util.Arrays.copyOfRange(this.buf, 0, bufUsedBytes);
        }
        bufUsedBytes = 0; // Our internal buffer is now empty.
        onChunk.accept(bufToPublish);
    }


    /** Inspired by {@link java.util.function.Consumer} */
    public static interface ChunkHandler {
        void accept( byte[] bytes ) throws java.io.IOException;
    }


    /** Inspired by {@link java.util.function.Runnable#run()} */
    public static interface EndHandler {
        void run() throws java.io.IOException;
    }

}
