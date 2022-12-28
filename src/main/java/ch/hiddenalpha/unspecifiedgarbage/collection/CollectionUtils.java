package ch.hiddenalpha.unspecifiedgarbage.collection;


public class CollectionUtils {

    /**
     * @param haystack
     *      The array to search in (aka haystack).
     * @param needle
     *      The element to search for (aka needle).
     * @param equals
     *      Predicate which decides if two elements are equal.
     * @param <T>
     *     Type of the elements we are working with.
     */
    public static <T> boolean contains( T[] haystack, T needle, java.util.function.BiPredicate<T, T> equals ){
        for( T t : haystack ){
            if( equals.test(needle, t) ){
                return true;
            }
        }
        return false;
    }

}

