package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import org.slf4j.ILoggerFactory;
import org.slf4j.Logger;


/** Filters away broken newlines. */
public class CRLFtoLFOutputStream extends FilterOutputStream {

    private static final int EMPTY = -42;
    private final Logger log;
    private int previous = EMPTY;

    /**
     * @param dst
     *      Destination where the result will be written to.
     */
    public CRLFtoLFOutputStream( OutputStream dst ) {
        this(dst, null);
    }

    /**
     * @param dst
     *      Destination where the result will be written to.
     */
    public CRLFtoLFOutputStream( OutputStream dst, ILoggerFactory lf ) {
        super(dst);
        this.log = (lf == null) ? null : lf.getLogger(CRLFtoLFOutputStream.class.getName());
    }

    @Override
    public void write( int current ) throws IOException {
        // We're allowed to ignore the three high octets (See doc of "OutputStream#write").
        // This allows us to assign special meanings to those values internally (eg our
        // 'EMPTY' value). For this to work, we clear the high bits to not get confused
        // just in case someone really passes such values.
        current &= 0xFF;

        if( previous == '\r' && current == '\n' ){
            // Ignore the CR and only write the LF.
            super.write(current);
            previous = EMPTY;
        }else if( previous == EMPTY ){
            // Just fill our "buffer".
            previous = current;
        }else{
            // Not a CRLF sequence. So shift a byte forward.
            super.write(previous);
            previous = current;
        }
    }

    // TODO we should override this.
    //@Override
    //public void write( byte[] buf, int off, int len ) throws IOException {
    //    throw new UnsupportedOperationException("TODO impl");/*TODO*/
    //}

    @Override
    public void flush() throws IOException {
        if( previous == '\r' ){
            log.debug("Have to flush a CR byte without knowing if the next byte might be a LF");
        }
        if( previous != EMPTY ){
            int tmp = previous;
            previous = EMPTY;
            super.write(tmp);
        }
        super.flush();
    }

}
