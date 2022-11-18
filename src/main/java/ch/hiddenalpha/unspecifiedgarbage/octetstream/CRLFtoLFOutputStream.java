package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;


/**
 * Filter to fix broken newlines.
 */
public class CRLFtoLFOutputStream extends FilterOutputStream {

    private static final int EMPTY = -42;
    private int previous = EMPTY;

    /**
     * @param dst
     *      Destination where the result will be written to.
     */
    public CRLFtoLFOutputStream( OutputStream dst ) {
        super(dst);
    }

    @Override
    public void write( int current ) throws IOException {
        // We're allowed to ignore the three high octets (See doc of "OutputStream#write").
        // This allows us to assign special meanings to those values internally (eg our
        // 'EMPTY' value). For this to work, we clear the high bits to not get confused
        // just in case someone really passes such values.
        current = current & 0xFF;

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

    @Override
    public void flush() throws IOException {
        if( previous == '\r' ){
            //log.warn("Have to flush a CR byte without knowing if the next byte might be a LF");
        }
        if( previous != EMPTY ){
            super.write(previous);
            previous = EMPTY;
        }
        super.flush();
    }

}
