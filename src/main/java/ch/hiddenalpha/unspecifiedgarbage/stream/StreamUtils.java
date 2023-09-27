package ch.hiddenalpha.unspecifiedgarbage.stream;


public class StreamUtils {

    /**
     * Copies 'is' to 'os' until end of 'is' is reached. (Blocking)
     *
     * <p>BTW: Using this function makes no longer sense in projects using java
     * 9 or later. Just use {@link java.io.InputStream#transferTo(java.io.OutputStream)}
     * instead.</p>
     *
     * @return
     *      Count of copied bytes.
     */
    public static long copy( java.io.InputStream is, java.io.OutputStream os ) throws java.io.IOException {
        byte[] buffer = new byte[1<<14];
        long totalBytes = 0;
        while( true ){
            int readLen = is.read(buffer, 0, buffer.length);
            if( readLen == -1 ) break; /* EOF */
            totalBytes += readLen;
            os.write(buffer, 0, readLen);
        }
        return totalBytes;
    }

    public static Runnable newCopyTask(java.io.InputStream src, java.io.OutputStream dst, boolean doCloseDst){
        return ()->{
            try{
                for( byte[] buf = new byte[8291] ;; ){
                    int readLen = src.read(buf, 0, buf.length);
                    if( readLen == -1 ) break;
                    dst.write(buf, 0, readLen);
                }
                if( doCloseDst ) dst.close();
            }catch( java.io.IOException ex ){
                throw new RuntimeException(ex);
            }
        };
    }

    public static <SRC,DST> java.util.Iterator<DST> map( java.util.Iterator<SRC> src , java.util.function.Function<SRC,DST> mapper ) {
        return new java.util.Iterator<DST>() {
            @Override public boolean hasNext() { return src.hasNext(); }
            @Override public DST next() { return mapper.apply(src.next()); }
        };
    }

    public static <T> java.util.function.Predicate<T> distinctBy( java.util.function.Function<? super T, ?> keyExtractor ) {
        java.util.Set<Object> seen = java.util.concurrent.ConcurrentHashMap.newKeySet();
        return t -> seen.add(keyExtractor.apply(t));
    }

    public static <T> java.util.function.Predicate<T> not( java.util.function.Predicate<T> p ){
        return e -> !p.test(e);
    }

}
