package ch.hiddenalpha.unspecifiedgarbage.stream;

import java.util.Iterator;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import java.util.function.Predicate;


public class StreamUtils {

    /**
     * Copies 'is' to 'os' until end of 'is' is reached. (Blocking)
     * @return
     *      Count of copied bytes.
     */
    public static long copy(java.io.InputStream is, java.io.OutputStream os) throws java.io.IOException {
        byte[] buffer = new byte[1024];
        long totalBytes = 0;
        int readLen;
        while( -1 != (readLen=is.read(buffer,0,buffer.length)) ){
            totalBytes += readLen;
            os.write( buffer , 0 , readLen );
        }
        return totalBytes;
    }

    public static <SRC,DST> java.util.Iterator<DST> map(java.util.Iterator<SRC> src , java.util.function.Function<SRC,DST> mapper) {
        return new Iterator<DST>() {
            @Override public boolean hasNext() {
                return src.hasNext();
            }
            @Override public DST next() {
                return mapper.apply(src.next());
            }
        };
    }

    public static <T> Predicate<T> distinctBy(Function<? super T, ?> keyExtractor) {
        Set<Object> seen = ConcurrentHashMap.newKeySet();
        return t -> seen.add(keyExtractor.apply(t));
    }

    public static <T> Predicate<T> not(Predicate<T> p){
        return e -> !p.test(e);
    }

}
