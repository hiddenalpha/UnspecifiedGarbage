package ch.hiddenalpha.unspecifiedgarbage.octetstream;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;


/** Allows to get notified when stream gets closed. */
public class CloseNotifyInputStream extends FilterInputStream {

    private final Runnable onClose;
    private final AtomicBoolean isFired = new AtomicBoolean(false);

    public CloseNotifyInputStream( InputStream src, Runnable onClose ){
        super(src);
        assert onClose != null : "onClose expected to exist";
        this.onClose = onClose;
    }

    @Override
    public void close() throws IOException {
        Exception byObserver = null, bySrc = null;
        if( !isFired.getAndSet(true) ){
            try{
                in.close();
            }catch( IOException | RuntimeException ex ){
                bySrc = ex;
            }
            try{
                onClose.run();
            }catch( RuntimeException ex ){
                byObserver = ex;
            }
            if( byObserver != null && bySrc != null && (byObserver != bySrc) ){
                bySrc.addSuppressed(byObserver);
            }else if( bySrc == null ){
                bySrc = byObserver;
            }
            if( bySrc instanceof IOException ){
                throw (IOException)bySrc;
            }else if ( bySrc != null ){
                throw (RuntimeException)bySrc;
            }
        }
    }

}
