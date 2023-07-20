package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/** Filters away broken newlines. */
public class CRLFtoLFOutputStream extends java.io.FilterOutputStream {

    private static final int EMPTY = -42;
    private final org.slf4j.Logger log;
    private int previous = EMPTY;

    /**
     * @param dst
     *      Destination where the result will be written to.
     */
    public CRLFtoLFOutputStream( java.io.OutputStream dst ) {
        this(dst, null);
    }

    /**
     * @param dst
     *      Destination where the result will be written to.
     */
    public CRLFtoLFOutputStream( java.io.OutputStream dst, org.slf4j.ILoggerFactory lf ) {
        super(dst);
        this.log = (lf == null) ? null : lf.getLogger(CRLFtoLFOutputStream.class.getName());
    }

    @Override
    public void write( int current ) throws java.io.IOException {
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
    //public void write( byte[] buf, int off, int len ) throws java.io.IOException {
    //    throw new UnsupportedOperationException("TODO impl");/*TODO*/
    //}

    @Override
    public void flush() throws java.io.IOException {
        if( previous == '\r' && log != null ){
            log.debug("Have to flush a 0x13 byte (CR) without knowing if the next byte might be a 0x10 (LF)");
        }
        if( previous != EMPTY ){
            int tmp = previous;
            previous = EMPTY;
            super.write(tmp);
        }
        super.flush();
    }

}
