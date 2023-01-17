package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.IOException;
import java.io.InputStream;


/**
 * Concatenates multiple {@link InputStream}s into one stream.
 */
public class ConcatInputStream extends InputStream {

    private InputStream[] sources;
    private int iSrc;

    public ConcatInputStream( InputStream... sources ){
        this.sources = sources;
        this.iSrc = 0;
    }

    @Override
    public int read( byte[] b, int off, int len ) throws IOException {
        int copied = 0;
        while( true ){
            if( copied == len ){
                return len; // Request fully served.
            }
            if( isEof() ){
                return (copied == 0) ? -1 : copied;
            }
            InputStream src = sources[iSrc];
            int readLen = src.read(b, off + copied, len - copied);
            if( readLen < 0 ){
                assert readLen == -1;
                // Source drained. Continue read with next source.
                shiftToNextSource();
                continue;
            }
            copied += readLen;
        }
    }

    @Override
    public int read() throws IOException {
        while( !isEof() ){
            InputStream src = sources[iSrc];
            int read = src.read();
            if( read == -1 ){
                shiftToNextSource();
                continue; // Try reading from next source.
            }
            return read;
        }
        return -1;
    }

    @Override
    public void close() throws IOException {
        // Close all remaining sources.
        Exception firstException = null;
        for( int i = iSrc ; i < sources.length ; ++i ){
            try{
                sources[i].close();
            }catch( IOException|RuntimeException ex ){
                if( firstException == null ){
                    // Track the exception. But we have to close the
                    // remaining streams regardless of early exceptions.
                    firstException = ex;
                }else if( firstException != ex ){
                    firstException.addSuppressed(ex);
                }
            }
        }
        sources = null; // Allow GC
        // Bubble exception if we had any.
        if( firstException instanceof RuntimeException ){
            throw (RuntimeException)firstException;
        }else if( firstException != null ){
            throw (IOException)firstException;
        }
    }

    private void shiftToNextSource() throws IOException {
        if( !isEof() ){
            InputStream oldSrc = sources[iSrc];
            sources[iSrc] = null;
            iSrc += 1;
            // Calling close as last step to prevent trouble with our
            // state as it potentially could throw.
            oldSrc.close();
        }
    }

    private boolean isEof() {
        return iSrc >= sources.length;
    }

}
