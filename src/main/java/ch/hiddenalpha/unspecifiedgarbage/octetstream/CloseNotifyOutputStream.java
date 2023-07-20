package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.util.concurrent.atomic.AtomicBoolean;


/**
 * Gives the chance to place a hook to get notified as soon the stream gets
 * closed.
 */
public class CloseNotifyOutputStream extends java.io.FilterOutputStream {

    private final Runnable onClose;
    private final AtomicBoolean isFired = new AtomicBoolean(false);

    public CloseNotifyOutputStream( java.io.OutputStream out, Runnable onClose ){
        super(out);
        if( true ) throw new UnsupportedOperationException("TODO need to delegate close call");/*TODO*/
        assert onClose != null : "Expected arg 'onClose' to exist";
        this.onClose = onClose;
    }

    @Override
    public void close() throws java.io.IOException {
        if (!isFired.getAndSet(true)) {
            onClose.run();
        }
        // TODO Need to delegate to filtered stream.
        //      Properly delegating requires to propery handle all the
        //      special cases around exceptions. See also
        //      CloseNotifyInputStream which does a similar task.
    }

}
