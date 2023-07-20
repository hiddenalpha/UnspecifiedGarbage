package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * <p>Suppresses to close the underlying stream when close gets called.</p>
 */
public class IgnoreCloseInputStream extends java.io.FilterInputStream {

    public IgnoreCloseInputStream( java.io.InputStream in ) {
        super(in);
    }

    @Override public void close() {/*no-op*/}

}
