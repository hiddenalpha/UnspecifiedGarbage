package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge.tmoutissue20240123;

import io.netty.handler.codec.DecoderResult;
import io.vertx.core.AsyncResult;
import io.vertx.core.Context;
import io.vertx.core.Future;
import io.vertx.core.Handler;
import io.vertx.core.MultiMap;
import io.vertx.core.buffer.Buffer;
import io.vertx.core.http.Cookie;
import io.vertx.core.http.HttpConnection;
import io.vertx.core.http.HttpFrame;
import io.vertx.core.http.HttpMethod;
import io.vertx.core.http.HttpServerFileUpload;
import io.vertx.core.http.HttpServerRequest;
import io.vertx.core.http.HttpServerResponse;
import io.vertx.core.http.HttpVersion;
import io.vertx.core.http.ServerWebSocket;
import io.vertx.core.http.StreamPriority;
import io.vertx.core.http.impl.HttpServerRequestInternal;
import io.vertx.core.net.NetSocket;
import io.vertx.core.net.SocketAddress;
import io.vertx.core.streams.Pipe;
import io.vertx.core.streams.WriteStream;
import org.slf4j.Logger;

import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;
import javax.security.cert.X509Certificate;
import java.util.Map;
import java.util.Set;

import static org.slf4j.LoggerFactory.getLogger;

public class DelegateVertxHttpServerRequestInternal implements HttpServerRequestInternal {

    private static final Logger log = getLogger(DelegateVertxHttpServerRequestInternal.class);
    private final HttpServerRequestInternal delegate;
    private final boolean isDebugging = true;
    private final String dbgHint;

    public DelegateVertxHttpServerRequestInternal(String debugHint, HttpServerRequest delegate) {
        log.trace("{}: new DelegateVertxHttpServerRequestInternal()", debugHint);
        this.delegate = (HttpServerRequestInternal) delegate;
        this.dbgHint = debugHint;
    }

    private void breakpoint(){
        try{
            throw new UnsupportedOperationException();
        }catch(UnsupportedOperationException ex){}
    }

    @Override
    public HttpServerRequest exceptionHandler(Handler<Throwable> handler) {
        log.trace("{}: exceptionHandler(Hdlr<Ex>)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.exceptionHandler(handler);
    }

    @Override
    public HttpServerRequest handler(Handler<Buffer> handler) {
        log.trace("{}: handler(Hdlr<Buf>)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.handler(handler);
    }

    @Override
    public HttpServerRequest pause() {
        log.trace("{}: pause()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.pause();
    }

    @Override
    public HttpServerRequest resume() {
        log.trace("{}: resume()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.resume();
    }

    @Override
    public HttpServerRequest fetch(long amount) {
        log.trace("{}: fetch({})", dbgHint, amount);
        if( isDebugging ) breakpoint();
        return delegate.fetch(amount);
    }

    @Override
    public HttpServerRequest endHandler(Handler<Void> endHandler) {
        log.trace("{}: endHandler(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.endHandler(endHandler);
    }

    @Override
    public HttpVersion version() {
        log.trace("{}: version()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.version();
    }

    @Override
    public HttpMethod method() {
        log.trace("{}: method()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.method();
    }

    @Override
    public boolean isSSL() {
        log.trace("{}: isSSL()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.isSSL();
    }

    @Override
    public String scheme() {
        log.trace("{}: scheme()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.scheme();
    }

    @Override
    public String uri() {
        log.trace("{}: uri()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.uri();
    }

    @Override
    public String path() {
        log.trace("{}: path()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.path();
    }

    @Override
    public String query() {
        log.trace("{}: query()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.query();
    }

    @Override
    public String host() {
        log.trace("{}: host()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.host();
    }

    @Override
    public long bytesRead() {
        log.trace("{}: bytesRead()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.bytesRead();
    }

    @Override
    public HttpServerResponse response() {
        log.trace("{}: response()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.response();
    }

    @Override
    public MultiMap headers() {
        log.trace("{}: headers()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.headers();
    }

    @Override
    public String getHeader(String headerName) {
        log.trace("{}: getHeader(\"{}\")", dbgHint, headerName);
        if( isDebugging ) breakpoint();
        return delegate.getHeader(headerName);
    }

    @Override
    public String getHeader(CharSequence headerName) {
        log.trace("{}: getHeader(\"{}\")", dbgHint, headerName);
        if( isDebugging ) breakpoint();
        return delegate.getHeader(headerName);
    }

    @Override
    public MultiMap params() {
        log.trace("{}: params()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.params();
    }

    @Override
    public String getParam(String paramName) {
        log.trace("{}: getParam(\"{}\")", dbgHint, paramName);
        if( isDebugging ) breakpoint();
        return delegate.getParam(paramName);
    }

    @Override
    public String getParam(String paramName, String defaultValue) {
        log.trace("{}: getParam(\"{}\", \"{}\")", dbgHint, paramName, defaultValue);
        if( isDebugging ) breakpoint();
        return delegate.getParam(paramName, defaultValue);
    }

    @Override
    public SocketAddress remoteAddress() {
        log.trace("{}: remoteAddress()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.remoteAddress();
    }

    @Override
    public SocketAddress localAddress() {
        log.trace("{}: localAddress()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.localAddress();
    }

    @Override
    public SSLSession sslSession() {
        log.trace("{}: sslSession()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.sslSession();
    }

    @Override
    public X509Certificate[] peerCertificateChain() throws SSLPeerUnverifiedException {
        log.trace("{}: peerCertificateChain()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.peerCertificateChain();
    }

    @Override
    public String absoluteURI() {
        log.trace("{}: absoluteURI()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.absoluteURI();
    }

    @Override
    public HttpServerRequest bodyHandler(Handler<Buffer> bodyHandler) {
        log.trace("{}: bodyHandler(Hdlr<Buf>)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.bodyHandler(bodyHandler);
    }

    @Override
    public HttpServerRequest body(Handler<AsyncResult<Buffer>> handler) {
        log.trace("{}: body(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.body(handler);
    }

    @Override
    public Future<Buffer> body() {
        log.trace("{}: body(void)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.body();
    }

    @Override
    public void end(Handler<AsyncResult<Void>> handler) {
        log.trace("{}: end(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        delegate.end(handler);
    }

    @Override
    public Future<Void> end() {
        log.trace("{}: end(void)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.end();
    }

    @Override
    public void toNetSocket(Handler<AsyncResult<NetSocket>> handler) {
        log.trace("{}: toNetSocket(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        delegate.toNetSocket(handler);
    }

    @Override
    public Future<NetSocket> toNetSocket() {
        log.trace("{}: toNetSocket(void)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.toNetSocket();
    }

    @Override
    public HttpServerRequest setExpectMultipart(boolean expect) {
        log.trace("{}: toNetSocket({})", dbgHint, expect);
        if( isDebugging ) breakpoint();
        return delegate.setExpectMultipart(expect);
    }

    @Override
    public boolean isExpectMultipart() {
        log.trace("{}: isExpectMultipart()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.isExpectMultipart();
    }

    @Override
    public HttpServerRequest uploadHandler(Handler<HttpServerFileUpload> uploadHandler) {
        log.trace("{}: uploadHandler(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.uploadHandler(uploadHandler);
    }

    @Override
    public MultiMap formAttributes() {
        log.trace("{}: formAttributes()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.formAttributes();
    }

    @Override
    public String getFormAttribute(String attributeName) {
        log.trace("{}: getFormAttribute(\"{}\")", dbgHint, attributeName);
        if( isDebugging ) breakpoint();
        return delegate.getFormAttribute(attributeName);
    }

    @Override
    public int streamId() {
        log.trace("{}: streamId()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.streamId();
    }

    @Override
    public void toWebSocket(Handler<AsyncResult<ServerWebSocket>> handler) {
        log.trace("{}: toWebSocket(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        delegate.toWebSocket(handler);
    }

    @Override
    public Future<ServerWebSocket> toWebSocket() {
        log.trace("{}: toWebSocket()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.toWebSocket();
    }

    @Override
    public boolean isEnded() {
        log.trace("{}: isEnded()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.isEnded();
    }

    @Override
    public HttpServerRequest customFrameHandler(Handler<HttpFrame> handler) {
        log.trace("{}: customFrameHandler(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.customFrameHandler(handler);
    }

    @Override
    public HttpConnection connection() {
        log.trace("{}: connection()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.connection();
    }

    @Override
    public StreamPriority streamPriority() {
        log.trace("{}: streamPriority()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.streamPriority();
    }

    @Override
    public HttpServerRequest streamPriorityHandler(Handler<StreamPriority> handler) {
        log.trace("{}: streamPriorityHandler(Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.streamPriorityHandler(handler);
    }

    @Override
    public DecoderResult decoderResult() {
        log.trace("{}: decoderResult()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.decoderResult();
    }

    @Override
    public Cookie getCookie(String name) {
        log.trace("{}: getCookie(\"{}\")", dbgHint, name);
        if( isDebugging ) breakpoint();
        return delegate.getCookie(name);
    }

    @Override
    public Cookie getCookie(String name, String domain, String path) {
        log.trace("{}: getCookie(\"{}\", Str, Str)", dbgHint, name);
        if( isDebugging ) breakpoint();
        return delegate.getCookie(name, domain, path);
    }

    @Override
    public int cookieCount() {
        log.trace("{}: cookieCount()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.cookieCount();
    }

    @Override
    @Deprecated
    public Map<String, Cookie> cookieMap() {
        log.trace("{}: cookieMap()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.cookieMap();
    }

    @Override
    public Set<Cookie> cookies(String name) {
        log.trace("{}: cookies(\"{}\")", dbgHint, name);
        if( isDebugging ) breakpoint();
        return delegate.cookies(name);
    }

    @Override
    public Set<Cookie> cookies() {
        log.trace("{}: cookies(void)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.cookies();
    }

    @Override
    public HttpServerRequest routed(String route) {
        log.trace("{}: routed(\"{}\")", dbgHint, route);
        if( isDebugging ) breakpoint();
        return delegate.routed(route);
    }

    @Override
    public Pipe<Buffer> pipe() {
        log.trace("{}: pipe()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.pipe();
    }

    @Override
    public Future<Void> pipeTo(WriteStream<Buffer> dst) {
        log.trace("{}: pipeTo(WrStrm<Buf>)", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.pipeTo(dst);
    }

    @Override
    public void pipeTo(WriteStream<Buffer> dst, Handler<AsyncResult<Void>> handler) {
        log.trace("{}: pipeTo(WrStrm<Buf>,Hdlr)", dbgHint);
        if( isDebugging ) breakpoint();
        delegate.pipeTo(dst, handler);
    }

    @Override
    public Context context() {
        log.trace("{}: context()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.context();
    }

    @Override
    public Object metric() {
        log.trace("{}: metric()", dbgHint);
        if( isDebugging ) breakpoint();
        return delegate.metric();
    }

}
