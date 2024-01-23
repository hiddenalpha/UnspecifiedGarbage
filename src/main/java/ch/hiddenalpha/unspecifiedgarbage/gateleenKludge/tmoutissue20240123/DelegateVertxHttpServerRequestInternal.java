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

import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;
import javax.security.cert.X509Certificate;
import java.util.Map;
import java.util.Set;

public class DelegateVertxHttpServerRequestInternal implements HttpServerRequestInternal {

    private final HttpServerRequestInternal delegate;
    private final boolean isDebugging = true;

    public DelegateVertxHttpServerRequestInternal(HttpServerRequest delegate) {
        this.delegate = (HttpServerRequestInternal) delegate;
    }

    private void breakpoint(){
        try{
            throw new UnsupportedOperationException();
        }catch(UnsupportedOperationException ex){}
    }

    @Override
    public HttpServerRequest exceptionHandler(Handler<Throwable> handler) {
        if( isDebugging ) breakpoint();
        return delegate.exceptionHandler(handler);
    }

    @Override
    public HttpServerRequest handler(Handler<Buffer> handler) {
        if( isDebugging ) breakpoint();
        return delegate.handler(handler);
    }

    @Override
    public HttpServerRequest pause() {
        if( isDebugging ) breakpoint();
        return delegate.pause();
    }

    @Override
    public HttpServerRequest resume() {
        if( isDebugging ) breakpoint();
        return delegate.resume();
    }

    @Override
    public HttpServerRequest fetch(long amount) {
        if( isDebugging ) breakpoint();
        return delegate.fetch(amount);
    }

    @Override
    public HttpServerRequest endHandler(Handler<Void> endHandler) {
        if( isDebugging ) breakpoint();
        return delegate.endHandler(endHandler);
    }

    @Override
    public HttpVersion version() {
        if( isDebugging ) breakpoint();
        return delegate.version();
    }

    @Override
    public HttpMethod method() {
        if( isDebugging ) breakpoint();
        return delegate.method();
    }

    @Override
    public boolean isSSL() {
        if( isDebugging ) breakpoint();
        return delegate.isSSL();
    }

    @Override
    public String scheme() {
        if( isDebugging ) breakpoint();
        return delegate.scheme();
    }

    @Override
    public String uri() {
        if( isDebugging ) breakpoint();
        return delegate.uri();
    }

    @Override
    public String path() {
        if( isDebugging ) breakpoint();
        return delegate.path();
    }

    @Override
    public String query() {
        if( isDebugging ) breakpoint();
        return delegate.query();
    }

    @Override
    public String host() {
        if( isDebugging ) breakpoint();
        return delegate.host();
    }

    @Override
    public long bytesRead() {
        if( isDebugging ) breakpoint();
        return delegate.bytesRead();
    }

    @Override
    public HttpServerResponse response() {
        if( isDebugging ) breakpoint();
        return delegate.response();
    }

    @Override
    public MultiMap headers() {
        if( isDebugging ) breakpoint();
        return delegate.headers();
    }

    @Override
    public String getHeader(String headerName) {
        if( isDebugging ) breakpoint();
        return delegate.getHeader(headerName);
    }

    @Override
    public String getHeader(CharSequence headerName) {
        if( isDebugging ) breakpoint();
        return delegate.getHeader(headerName);
    }

    @Override
    public MultiMap params() {
        if( isDebugging ) breakpoint();
        return delegate.params();
    }

    @Override
    public String getParam(String paramName) {
        if( isDebugging ) breakpoint();
        return delegate.getParam(paramName);
    }

    @Override
    public String getParam(String paramName, String defaultValue) {
        if( isDebugging ) breakpoint();
        return delegate.getParam(paramName, defaultValue);
    }

    @Override
    public SocketAddress remoteAddress() {
        if( isDebugging ) breakpoint();
        return delegate.remoteAddress();
    }

    @Override
    public SocketAddress localAddress() {
        if( isDebugging ) breakpoint();
        return delegate.localAddress();
    }

    @Override
    public SSLSession sslSession() {
        if( isDebugging ) breakpoint();
        return delegate.sslSession();
    }

    @Override
    public X509Certificate[] peerCertificateChain() throws SSLPeerUnverifiedException {
        if( isDebugging ) breakpoint();
        return delegate.peerCertificateChain();
    }

    @Override
    public String absoluteURI() {
        if( isDebugging ) breakpoint();
        return delegate.absoluteURI();
    }

    @Override
    public HttpServerRequest bodyHandler(Handler<Buffer> bodyHandler) {
        if( isDebugging ) breakpoint();
        return delegate.bodyHandler(bodyHandler);
    }

    @Override
    public HttpServerRequest body(Handler<AsyncResult<Buffer>> handler) {
        if( isDebugging ) breakpoint();
        return delegate.body(handler);
    }

    @Override
    public Future<Buffer> body() {
        if( isDebugging ) breakpoint();
        return delegate.body();
    }

    @Override
    public void end(Handler<AsyncResult<Void>> handler) {
        if( isDebugging ) breakpoint();
        delegate.end(handler);
    }

    @Override
    public Future<Void> end() {
        if( isDebugging ) breakpoint();
        return delegate.end();
    }

    @Override
    public void toNetSocket(Handler<AsyncResult<NetSocket>> handler) {
        if( isDebugging ) breakpoint();
        delegate.toNetSocket(handler);
    }

    @Override
    public Future<NetSocket> toNetSocket() {
        if( isDebugging ) breakpoint();
        return delegate.toNetSocket();
    }

    @Override
    public HttpServerRequest setExpectMultipart(boolean expect) {
        if( isDebugging ) breakpoint();
        return delegate.setExpectMultipart(expect);
    }

    @Override
    public boolean isExpectMultipart() {
        if( isDebugging ) breakpoint();
        return delegate.isExpectMultipart();
    }

    @Override
    public HttpServerRequest uploadHandler(Handler<HttpServerFileUpload> uploadHandler) {
        if( isDebugging ) breakpoint();
        return delegate.uploadHandler(uploadHandler);
    }

    @Override
    public MultiMap formAttributes() {
        if( isDebugging ) breakpoint();
        return delegate.formAttributes();
    }

    @Override
    public String getFormAttribute(String attributeName) {
        if( isDebugging ) breakpoint();
        return delegate.getFormAttribute(attributeName);
    }

    @Override
    public int streamId() {
        if( isDebugging ) breakpoint();
        return delegate.streamId();
    }

    @Override
    public void toWebSocket(Handler<AsyncResult<ServerWebSocket>> handler) {
        if( isDebugging ) breakpoint();
        delegate.toWebSocket(handler);
    }

    @Override
    public Future<ServerWebSocket> toWebSocket() {
        if( isDebugging ) breakpoint();
        return delegate.toWebSocket();
    }

    @Override
    public boolean isEnded() {
        if( isDebugging ) breakpoint();
        return delegate.isEnded();
    }

    @Override
    public HttpServerRequest customFrameHandler(Handler<HttpFrame> handler) {
        if( isDebugging ) breakpoint();
        return delegate.customFrameHandler(handler);
    }

    @Override
    public HttpConnection connection() {
        if( isDebugging ) breakpoint();
        return delegate.connection();
    }

    @Override
    public StreamPriority streamPriority() {
        if( isDebugging ) breakpoint();
        return delegate.streamPriority();
    }

    @Override
    public HttpServerRequest streamPriorityHandler(Handler<StreamPriority> handler) {
        if( isDebugging ) breakpoint();
        return delegate.streamPriorityHandler(handler);
    }

    @Override
    public DecoderResult decoderResult() {
        if( isDebugging ) breakpoint();
        return delegate.decoderResult();
    }

    @Override
    public Cookie getCookie(String name) {
        if( isDebugging ) breakpoint();
        return delegate.getCookie(name);
    }

    @Override
    public Cookie getCookie(String name, String domain, String path) {
        if( isDebugging ) breakpoint();
        return delegate.getCookie(name, domain, path);
    }

    @Override
    public int cookieCount() {
        if( isDebugging ) breakpoint();
        return delegate.cookieCount();
    }

    @Override
    @Deprecated
    public Map<String, Cookie> cookieMap() {
        if( isDebugging ) breakpoint();
        return delegate.cookieMap();
    }

    @Override
    public Set<Cookie> cookies(String name) {
        if( isDebugging ) breakpoint();
        return delegate.cookies(name);
    }

    @Override
    public Set<Cookie> cookies() {
        if( isDebugging ) breakpoint();
        return delegate.cookies();
    }

    @Override
    public HttpServerRequest routed(String route) {
        if( isDebugging ) breakpoint();
        return delegate.routed(route);
    }

    @Override
    public Pipe<Buffer> pipe() {
        if( isDebugging ) breakpoint();
        return delegate.pipe();
    }

    @Override
    public Future<Void> pipeTo(WriteStream<Buffer> dst) {
        if( isDebugging ) breakpoint();
        return delegate.pipeTo(dst);
    }

    @Override
    public void pipeTo(WriteStream<Buffer> dst, Handler<AsyncResult<Void>> handler) {
        if( isDebugging ) breakpoint();
        delegate.pipeTo(dst, handler);
    }

    @Override
    public Context context() {
        if( isDebugging ) breakpoint();
        return delegate.context();
    }

    @Override
    public Object metric() {
        if( isDebugging ) breakpoint();
        return delegate.metric();
    }

}
