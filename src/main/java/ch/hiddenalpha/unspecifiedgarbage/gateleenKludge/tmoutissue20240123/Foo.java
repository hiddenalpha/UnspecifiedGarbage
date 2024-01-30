package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge.tmoutissue20240123;

import io.vertx.core.http.HttpServerRequest;
import io.vertx.ext.web.RoutingContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static java.lang.System.currentTimeMillis;


public class Foo {

    private static final Logger log = Foo.getLogger(Foo.class);
    private static final boolean assertRequestEquality = true;
    private static HttpServerRequest serverInfoRequest;
    private static io.vertx.core.http.impl.HttpServerRequestInternal restStorageEvBusAdaptMappdHttpServReq;
    private static long onBeginRouteEpochMs;

    public static synchronized void onNewServerInfoRequst(HttpServerRequest request){
        if( !isServerInfoRequst(request) ) return;
        //assert serverInfoRequest == null;
        log.trace("onNewServerInfoRequst()");
        serverInfoRequest = request;
    }

    public static void downReqBegin(HttpServerRequest req) {
        if( !isServerInfoRequst(req) ) return;
        log.trace("downReqBegin()");
        assert !assertRequestEquality || serverInfoRequest == req;
    }

    public static void downReqAuthorized(HttpServerRequest req) {
        if( !isServerInfoRequst(req) ) return;
        log.trace("downReqAuthorized()");
        assert !assertRequestEquality || serverInfoRequest == req;
    }

    public static void onBeforeMainVerticleRouteGeneric(HttpServerRequest req) {
        if( !isServerInfoRequst(req) ) return;
        log.trace("onBeforeMainVerticleRouteGeneric()");
        onBeginRouteEpochMs = currentTimeMillis();
        assert !assertRequestEquality || serverInfoRequest == req;
    }

    public static Logger getLogger(Class<?> clazz) {
        assert clazz != null;
        return getLogger(clazz.getName());
    }

    public static Logger getLogger(String name) {
        assert name != null;
        return LoggerFactory.getLogger("FOO."+ name);
    }

    public static boolean isServerInfoRequst(HttpServerRequest request) {
        return isServerInfoRequst(request.uri());
    }

    private static boolean isServerInfoRequst(String uri) {
        assert uri != null;
        assert uri.startsWith("/");
        try{
            if( "/houston/server/info".equals(uri) ){
                //log.trace("true <- isServerInfoRequst({})", uri);
                return true;
            }
            //log.trace("false <- isServerInfoRequst({})", uri);
            return false;
        }catch(Throwable ex){
            assert false;
            throw ex;
        }
    }

    public static void onBeforeEvBusAdapterDataHandler(String uri) {
        if( !isServerInfoRequst(uri) ) return;
        log.trace("onBeforeEvBusAdapterDataHandler({})", uri);
        assert false;
    }

    public static void onBeforeEvBusAdapterEndHandler(String uri) {
        if( !isServerInfoRequst(uri)) return;
        log.trace("onBeforeEvBusAdapterEndHandler({})", uri);
        assert false;
    }

    public static void onEvBusAdapterHandle(io.vertx.core.http.impl.HttpServerRequestInternal req) {
        if( !isServerInfoRequst(req.uri()) ) return;
        assert !assertRequestEquality || serverInfoRequest != req;
        assert restStorageEvBusAdaptMappdHttpServReq == null;
        log.trace("onEvBusAdapterHandle({})", req.uri());
        restStorageEvBusAdaptMappdHttpServReq = req;
    }

    public static void onEvBusAdapterError(Throwable ex) {
        log.error("onEvBusAdapterError()", new Exception("stacktrace", ex));
    }

    public static void onRestStorageHandlerHandle(HttpServerRequest req) {
        if( !isServerInfoRequst(req) ) return;
        log.trace("onRestStorageHandlerHandle({})", req.uri());
        assert !assertRequestEquality || serverInfoRequest == req;
    }

    public static void onRestStorageHandler_getResource(io.vertx.ext.web.RoutingContext ctx) {
        if( !isServerInfoRequst(ctx.request()) ) return;
        assert !assertRequestEquality || serverInfoRequest == ctx.request();
        log.trace("onRestStorageHandler_getResource({})", ctx.request().uri());
    }

    public static void onRestStorageHandler_getResource_before_storage_get(String path, int offset, int limit) {
        //log.trace("onRestStorageHandler_getResource_before_storage_get({}, {}, {})", path, offset, limit);
    }

    public static void onRestStorageHandler_getResource_after_storage_get(String path, int offset, int limit, Object/*org.swisspush.reststorage.Resource*/ resource) {
        //log.trace("onRestStorageHandler_getResource_after_storage_get({})", path);
    }

    public static void onGetHoustonServerInfo(RoutingContext ctx) {
        var req = ctx.request();
        log.trace("onGetHoustonServerInfo({})", req.uri());
        assert !assertRequestEquality || serverInfoRequest != req;
    }

    public static void onEndCompleted(long responseBegEpochMs){
        long nowEpochMs = currentTimeMillis();
        log.debug("Request took {}ms and {}ms", nowEpochMs - onBeginRouteEpochMs, nowEpochMs - responseBegEpochMs);
    }

}

