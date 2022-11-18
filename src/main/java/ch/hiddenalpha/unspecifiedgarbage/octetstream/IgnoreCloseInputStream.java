package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.FilterInputStream;
import java.io.InputStream;


/**
 * Suppresses to close the underlying stream when close gets called.
 */
public class IgnoreCloseInputStream extends FilterInputStream {

    public IgnoreCloseInputStream( InputStream in ) {
        super(in);
    }

    @Override
    public void close() {
        // NOOP. Do NOT close the stream.
    }

}
