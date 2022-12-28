package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.concurrent.atomic.AtomicBoolean;

import static java.util.Objects.requireNonNull;


/**
 * Gives the chance to place a hook to get notified as soon the stream gets
 * closed.
 */
public class CloseNotifyOutputStream extends FilterOutputStream {

    private final Runnable onClose;
    private final AtomicBoolean isFired = new AtomicBoolean(false);

    public CloseNotifyOutputStream( OutputStream out, Runnable onClose ){
        super(out);
        if( true ) throw new UnsupportedOperationException("TODO need to delegate close call");/*TODO*/
        this.onClose = requireNonNull(onClose);
    }

    @Override
    public void close() throws IOException {
        if (!isFired.getAndSet(true)) {
            onClose.run();
        }
        // TODO Need to delegate to filtered stream.
        //      Properly delegating requires to propery handle all the
        //      special cases around exceptions. See also
        //      CloseNotifyInputStream which does a similar task.
    }

}
