package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge.tmoutissue20240123;

import io.vertx.core.http.HttpMethod;
import io.vertx.core.http.HttpServerRequest;
import io.vertx.core.http.HttpServerResponse;
import org.slf4j.Logger;

import java.lang.reflect.Field;
import java.util.NoSuchElementException;

import static java.lang.System.currentTimeMillis;
import static org.slf4j.LoggerFactory.getLogger;


/**
 * <p>This class got introduced to trace timings of "/houston/server/info"
 * requests. It is optimized for exactly this purpose AND NOTHING ELSE! It was
 * introduced because SDCISA-13746 is only observable on PROD. It does not
 * reproduce locally, and not even on TEST, INT or PREPROD. So we do not really
 * have another choice but tracing down this bug directly on PROD itself.
 * Unluckily it is not that simple to do so. First debugging/testing on PROD env
 * always has some risk. Plus, also our feedback-loop is terribly slow due to our
 * heavyweight deployment process. So to be able to see if this code actually does
 * what it should, we likely have to wait up to SEVERAL MONTHS.</p>
 */
public class HoustonInfoRequestTracer implements org.swisspush.gateleen.core.debug.InfoRequestTracer {

    private static final Logger log = getLogger(HoustonInfoRequestTracer.class);
    private static final String INFO_URI = "/houston/server/info";
    private static final int MAX_REQUESTS = 8; /*WARN: do NOT go too high*/
    private static final Long NO_VALUE = Long.MIN_VALUE / 2;
    private static final Class<?> wrapperClazz;
    private static final Field delegateField;
    private static final int
            FLG_WritingHttpResponseHasReturned = 1 << 0,
            FLG_WritingHttpResponseEnd = 1 << 1,
            FLG_slotIsBusy = 1 << 2;
    private final int requestDurationBailTresholdLowMs = 42; /* requests faster than 42 millis likely not interesting*/
    private final Object requestSlotLock = new Object();
    private final HttpServerRequest[]
            requestInstances = new HttpServerRequest[MAX_REQUESTS];
    private int slotReUseOffset;
    private final int[]
            requestFlg = new int[MAX_REQUESTS];
    private final long[]
            requestNewHttpReqEpochMs = new long[MAX_REQUESTS],
            authorizerBeginMs = new long[MAX_REQUESTS],
            authorizerEndMs = new long[MAX_REQUESTS],
            beforeCatchallRouting = new long[MAX_REQUESTS],
            responseGotRequestedMs = new long[MAX_REQUESTS],
            writingResponseBeginMs = new long[MAX_REQUESTS],
            writingResponseHasReturnedMs = new long[MAX_REQUESTS],
            writingResponseEndMs = new long[MAX_REQUESTS],
            requestDoneMs = new long[MAX_REQUESTS];

    static {
        try {
            wrapperClazz = Class.forName("io.vertx.ext.web.impl.HttpServerRequestWrapper");
            delegateField = wrapperClazz.getDeclaredField("delegate");
            delegateField.setAccessible(true);
        } catch (ClassNotFoundException | NoSuchFieldException ex) {
            assert false : "TODO_395w8zuj";
            throw new UnsupportedOperationException(/*TODO*/"Not impl yet", ex);
        }
    }

    public void onNewHttpRequest(HttpServerRequest req) {
        if( !isOfInterestEvenReqNotYetSeen(req) ) return;
        req = unwrap(req);
        int reqIdx;
        synchronized (requestSlotLock){
            reqIdx = getFreeSlotIdx();
            if( reqIdx == -2 ) {
                log.debug("No more space to trace yet another request");
                return;
            }
            assert reqIdx >= 0 && reqIdx < MAX_REQUESTS;
            assert !alreadyKnowRequest(req) : "TODO what if..";
            requestFlg[reqIdx] = FLG_slotIsBusy;
        }
        requestInstances[reqIdx] = req;
        requestNewHttpReqEpochMs[reqIdx] = currentTimeMillis();
        authorizerBeginMs[reqIdx] = NO_VALUE;
        authorizerEndMs[reqIdx] = NO_VALUE;
        beforeCatchallRouting[reqIdx] = NO_VALUE;
        responseGotRequestedMs[reqIdx] = NO_VALUE;
        writingResponseBeginMs[reqIdx] = NO_VALUE;
        writingResponseHasReturnedMs[reqIdx] = NO_VALUE;
        writingResponseEndMs[reqIdx] = NO_VALUE;
        requestDoneMs[reqIdx] = NO_VALUE;
    }

    public void onHttpRequestError(HttpServerRequest req, Throwable ex) {
        if( !isOfInterest(req) ) return;
        int reqIdx = getIdxOf(req);
        long durMs = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
        throw new UnsupportedOperationException(/*TODO*/"Not impl yet. Took "+durMs+"ms", ex);
    }

    public void onAuthorizerBegin(HttpServerRequest req) {
        if( !isOfInterest(req) ) return;
        int reqIdx = getIdxOf(req);
        authorizerBeginMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
    }

    public void onAuthorizerEnd(HttpServerRequest req) {
        if( !isOfInterest(req) ) return;
        int reqIdx = getIdxOf(req);
        authorizerEndMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
    }

    public HttpServerRequest filterRequestBeforeCallingCatchallRouter(HttpServerRequest req) {
        if( !isOfInterest(req) ) return req;
        int reqIdx = getIdxOf(req);
        beforeCatchallRouting[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
        return new InterceptingServerRequest("ai9oh8urtgj", req);
    }

    private void onHttpResponseGotRequested(HttpServerRequest req) {
        assert isOfInterest(req);
        int reqIdx = getIdxOf(req);
        responseGotRequestedMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
    }

    public void onWritingHttpResponseBegin(HttpServerRequest req) {
        int reqIdx = getIdxOf(req);
        writingResponseBeginMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
    }

    public void onWritingHttpResponseHasReturned(HttpServerRequest req) {
        assert isOfInterest(req);
        int reqIdx = getIdxOf(req);
        writingResponseHasReturnedMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
        requestFlg[reqIdx] |= FLG_WritingHttpResponseHasReturned;
        tryCompletingRequest(reqIdx);
    }

    public void onWritingHttpResponseEnd(Throwable ex, HttpServerRequest req) {
        assert ex == null;
        assert isOfInterest(req);
        int reqIdx = getIdxOf(req);
        writingResponseEndMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
        requestFlg[reqIdx] |= FLG_WritingHttpResponseEnd;
        tryCompletingRequest(reqIdx);
    }

    private void tryCompletingRequest(int reqIdx) {
        int requestIsDoneMask = FLG_WritingHttpResponseHasReturned | FLG_WritingHttpResponseEnd;
        if ((requestFlg[reqIdx] & requestIsDoneMask) != requestIsDoneMask) return;
        requestDoneMs[reqIdx] = currentTimeMillis() - requestNewHttpReqEpochMs[reqIdx];
        report(reqIdx);
        /* free our slot */
        synchronized (requestSlotLock){
            requestFlg[reqIdx] &= ~FLG_slotIsBusy;
            requestInstances[reqIdx] = null;
        }
    }

    private void report(int reqIdx) {
        if( requestDoneMs[reqIdx] < requestDurationBailTresholdLowMs ){
            /*fast requests usually are not worth logging, we're interested in the slow requests only*/
            if (log.isTraceEnabled()) log.trace(
                    "Req took {}ms (authBeg={}ms, authEnd={}ms, route={}ms, getRsp={}ms, wrBeg={}ms, wrRet={}ms, wrEnd={}ms)",
                    requestDoneMs[reqIdx],
                    authorizerBeginMs[reqIdx],
                    authorizerEndMs[reqIdx],
                    beforeCatchallRouting[reqIdx],
                    responseGotRequestedMs[reqIdx],
                    writingResponseBeginMs[reqIdx],
                    writingResponseHasReturnedMs[reqIdx],
                    writingResponseEndMs[reqIdx]);
        }else{
            /*slow requests are interesting*/
            log.info("Req took {}ms (authBeg={}ms, authEnd={}ms, route={}ms, getRsp={}ms, wrBeg={}ms, wrRet={}ms, wrEnd={}ms)",
                    requestDoneMs[reqIdx],
                    authorizerBeginMs[reqIdx],
                    authorizerEndMs[reqIdx],
                    beforeCatchallRouting[reqIdx],
                    responseGotRequestedMs[reqIdx],
                    writingResponseBeginMs[reqIdx],
                    writingResponseHasReturnedMs[reqIdx],
                    writingResponseEndMs[reqIdx]);
        }
    }

    private boolean isOfInterest(HttpServerRequest req){
        if( !isOfInterestEvenReqNotYetSeen(req) ) return false;
        if( !alreadyKnowRequest(req) ) return false; // Without start point, we cannot report anything useful
        return true;
    }

    private boolean isOfInterestEvenReqNotYetSeen(HttpServerRequest req) {
        if( !log.isInfoEnabled() ) return false; // if we produce no output, makes no sense to burn CPU for it
        if( !HttpMethod.GET.equals(req.method()) ) return false; // Only GET is interesting for us
        if( !INFO_URI.equals(req.uri()) ) return false; // Only this specific URI is of interest
        return true;
    }

    private int getIdxOf(HttpServerRequest req) {
        req = unwrap(req);
        for( int idx = 0 ; idx < MAX_REQUESTS ; ++idx ){
            if( requestInstances[idx] == req ) return idx;
        }
        assert false : "why does this happen?";
        throw new NoSuchElementException(/*TODO*/"Not impl yet");
    }

    /** @return either index of free slot or -2 if no slot available */
    private int getFreeSlotIdx() {
        for( int i = 0 ; i < MAX_REQUESTS ; ++i ){
            if( (requestFlg[i+slotReUseOffset%MAX_REQUESTS] & FLG_slotIsBusy) == 0 ) {
                slotReUseOffset = i + 1;
                return i;
            }
        }
        return -2;
    }

    private boolean alreadyKnowRequest(HttpServerRequest req) {
        req = unwrap(req);
        for( int i = 0 ; i < (0 + MAX_REQUESTS) ; ++i ){
            if((requestFlg[i] & FLG_slotIsBusy) == 0) continue;
            if( requestInstances[i] == req ) return true;
        }
        return false;
    }

    private HttpServerRequest unwrap(HttpServerRequest req){
        for( boolean hasChanged = true ; hasChanged ;){
            hasChanged = false;
            while (req instanceof InterceptingServerRequest) {
                hasChanged = true;
                req = ((InterceptingServerRequest) req).delegate;
            }
            while(wrapperClazz.isInstance(req)){
                hasChanged = true;
                try {
                    req = (HttpServerRequest) delegateField.get(req);
                } catch (IllegalAccessException ex) {
                    throw new UnsupportedOperationException(/*TODO*/"Not impl yet", ex);
                }
            }
        }
        assert req != null;
        return req;
    }

    private class InterceptingServerRequest extends DelegateVertxHttpServerRequestInternal {
        private final HttpServerRequest delegate;

        public InterceptingServerRequest(String debugHint, HttpServerRequest delegate) {
            super(debugHint, delegate);
            assert isOfInterest(delegate);
            this.delegate = delegate;
        }

        @Override public HttpServerResponse response() {
            assert isOfInterest(delegate);
            onHttpResponseGotRequested(delegate);
            return super.response();
        }
    }


}
