package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge.tmoutissue20240123;

import io.vertx.core.AsyncResult;
import io.vertx.core.Future;
import io.vertx.core.Handler;
import io.vertx.core.MultiMap;
import io.vertx.core.buffer.Buffer;
import io.vertx.core.http.Cookie;
import io.vertx.core.http.HttpFrame;
import io.vertx.core.http.HttpMethod;
import io.vertx.core.http.HttpServerResponse;
import io.vertx.core.http.StreamPriority;
import io.vertx.core.streams.ReadStream;
import org.slf4j.Logger;

import java.util.Set;

import static org.slf4j.LoggerFactory.getLogger;

public class DelegateVertxHttpServerResponse implements HttpServerResponse {

    private static final Logger log = getLogger(DelegateVertxHttpServerResponse.class);
    private final HttpServerResponse delegate;
    private final String dbgHint;

    public DelegateVertxHttpServerResponse(String debugHint, HttpServerResponse delegate) {
        this.dbgHint = debugHint;
        this.delegate = delegate;
    }

    @Override public HttpServerResponse exceptionHandler(Handler<Throwable> handler) { log.trace("{}: exceptionHandler()", dbgHint); return delegate.exceptionHandler(handler); }
    @Override public HttpServerResponse setWriteQueueMaxSize(int maxSize) { log.trace("{}: setWriteQueueMaxSize()", dbgHint); return delegate.setWriteQueueMaxSize(maxSize); }
    @Override public HttpServerResponse drainHandler(Handler<Void> handler) { log.trace("{}: drainHandler()", dbgHint); return delegate.drainHandler(handler); }
    @Override public int getStatusCode() { log.trace("{}: getStatusCode()", dbgHint); return delegate.getStatusCode(); }
    @Override public HttpServerResponse setStatusCode(int statusCode) { log.trace("{}: setStatusCode()", dbgHint); return delegate.setStatusCode(statusCode); }
    @Override public String getStatusMessage() { log.trace("{}: getStatusMessage()", dbgHint); return delegate.getStatusMessage(); }
    @Override public HttpServerResponse setStatusMessage(String statusMessage) { log.trace("{}: setStatusMessage()", dbgHint); return delegate.setStatusMessage(statusMessage); }
    @Override public HttpServerResponse setChunked(boolean chunked) { log.trace("{}: setChunked()", dbgHint); return delegate.setChunked(chunked); }
    @Override public boolean isChunked() { log.trace("{}: isChunked()", dbgHint); return delegate.isChunked(); }
    @Override public MultiMap headers() { log.trace("{}: headers()", dbgHint); return delegate.headers(); }
    @Override public HttpServerResponse putHeader(String name, String value) { log.trace("{}: putHeader(Str,Str)", dbgHint); return delegate.putHeader(name, value); }
    @Override public HttpServerResponse putHeader(CharSequence name, CharSequence value) { log.trace("{}: putHeader(ChrSeq,ChrSeq)", dbgHint); return delegate.putHeader(name, value); }
    @Override public HttpServerResponse putHeader(String name, Iterable<String> values) { log.trace("{}: putHeader(Str,Iter<Str>)", dbgHint); return delegate.putHeader(name, values); }
    @Override public HttpServerResponse putHeader(CharSequence name, Iterable<CharSequence> values) { log.trace("{}: putHeader(ChrSeq,Iter<ChrSeq>)", dbgHint); return delegate.putHeader(name, values); }
    @Override public MultiMap trailers() { log.trace("{}: trailers()", dbgHint); return delegate.trailers(); }
    @Override public HttpServerResponse putTrailer(String name, String value) { log.trace("{}: putTrailer(Str,Str)", dbgHint); return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse putTrailer(CharSequence name, CharSequence value) { log.trace("{}: putTrailer(ChrSeq,ChrSeq)", dbgHint); return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse putTrailer(String name, Iterable<String> values) { log.trace("{}: putTrailer(Str,Iter<Str>)", dbgHint); return delegate.putTrailer(name, values); }
    @Override public HttpServerResponse putTrailer(CharSequence name, Iterable<CharSequence> value) { log.trace("{}: putTrailer(ChrSeq,Iter<ChrSeq>)", dbgHint); return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse closeHandler(Handler<Void> handler) { log.trace("{}: closeHandler()", dbgHint); return delegate.closeHandler(handler); }
    @Override public HttpServerResponse endHandler(Handler<Void> handler) { log.trace("{}: endHandler()", dbgHint); return delegate.endHandler(handler); }
    @Override public Future<Void> write(String chunk, String enc) { log.trace("{}: write(Str,Str)", dbgHint); return delegate.write(chunk, enc); }
    @Override public void write(String chunk, String enc, Handler<AsyncResult<Void>> handler) { log.trace("{}: write(Str,Str,Hdlr)", dbgHint); delegate.write(chunk, enc, handler); }
    @Override public Future<Void> write(String chunk) { log.trace("{}: write(Str)", dbgHint); return delegate.write(chunk); }
    @Override public void write(String chunk, Handler<AsyncResult<Void>> handler) { log.trace("{}: write(Str,Hdlr)", dbgHint); delegate.write(chunk, handler); }
    @Override public HttpServerResponse writeContinue() { log.trace("{}: writeContinue()", dbgHint); return delegate.writeContinue(); }
    @Override public Future<Void> end(String chunk) { log.trace("{}: end(Str)", dbgHint); return delegate.end(chunk); }
    @Override public void end(String chunk, Handler<AsyncResult<Void>> handler) { log.trace("{}: end(Str,Hdlr)", dbgHint); delegate.end(chunk, handler); }
    @Override public Future<Void> end(String chunk, String enc) { log.trace("{}: end(Str,Str)", dbgHint); return delegate.end(chunk, enc); }
    @Override public void end(String chunk, String enc, Handler<AsyncResult<Void>> handler) { log.trace("{}: end(Str,Str,Hdlr)", dbgHint); delegate.end(chunk, enc, handler); }
    @Override public Future<Void> end(Buffer chunk) { log.trace("{}: end(Buf)", dbgHint); return delegate.end(chunk); }
    @Override public void end(Buffer chunk, Handler<AsyncResult<Void>> handler) { log.trace("{}: end(Buf,Hdlr)", dbgHint); delegate.end(chunk, handler); }
    @Override public Future<Void> end() { log.trace("{}: end(void)", dbgHint); return delegate.end(); }
    @Override public void send(Handler<AsyncResult<Void>> handler) { log.trace("{}: send(Hdlr)", dbgHint); delegate.send(handler); }
    @Override public Future<Void> send() { log.trace("{}: send(void)", dbgHint); return delegate.send(); }
    @Override public void send(String body, Handler<AsyncResult<Void>> handler) { log.trace("{}: send(Str,Hdlr)", dbgHint); delegate.send(body, handler); }
    @Override public Future<Void> send(String body) { log.trace("{}: send(Str)", dbgHint); return delegate.send(body); }
    @Override public void send(Buffer body, Handler<AsyncResult<Void>> handler) { log.trace("{}: send(Buf,Hdlr)", dbgHint); delegate.send(body, handler); }
    @Override public Future<Void> send(Buffer body) { log.trace("{}: send(Buf)", dbgHint); return delegate.send(body); }
    @Override public void send(ReadStream<Buffer> body, Handler<AsyncResult<Void>> handler) { log.trace("{}: send(RdStr<Buf>,Hdlr)", dbgHint); delegate.send(body, handler); }
    @Override public Future<Void> send(ReadStream<Buffer> body) { log.trace("{}: send(RdStr<Buf>)", dbgHint); return delegate.send(body); }
    @Override public Future<Void> sendFile(String filename) { log.trace("{}: sendFile(Str)", dbgHint); return delegate.sendFile(filename); }
    @Override public Future<Void> sendFile(String filename, long offset) { log.trace("{}: sendFile(Str,lng)", dbgHint); return delegate.sendFile(filename, offset); }
    @Override public Future<Void> sendFile(String filename, long offset, long length) { log.trace("{}: sendFile(Str,lng,lng)", dbgHint); return delegate.sendFile(filename, offset, length); }
    @Override public HttpServerResponse sendFile(String filename, Handler<AsyncResult<Void>> resultHandler) { log.trace("{}: sendFile(Str,Hdlr)", dbgHint); return delegate.sendFile(filename, resultHandler); }
    @Override public HttpServerResponse sendFile(String filename, long offset, Handler<AsyncResult<Void>> resultHandler) { log.trace("{}: sendFile(Str,lng,Hdlr)", dbgHint); return delegate.sendFile(filename, offset, resultHandler); }
    @Override public HttpServerResponse sendFile(String filename, long offset, long length, Handler<AsyncResult<Void>> resultHandler) { log.trace("{}: sendFile(Str,lng,lng,Hdlr)", dbgHint); return delegate.sendFile(filename, offset, length, resultHandler); }
    @Override public void close() { log.trace("{}: close()", dbgHint); delegate.close(); }
    @Override public boolean ended() { log.trace("{}: ended()", dbgHint); return delegate.ended(); }
    @Override public boolean closed() { log.trace("{}: closed()", dbgHint); return delegate.closed(); }
    @Override public boolean headWritten() { log.trace("{}: headWritten()", dbgHint); return delegate.headWritten(); }
    @Override public HttpServerResponse headersEndHandler(Handler<Void> handler) { log.trace("{}: headersEndHandler()", dbgHint); return delegate.headersEndHandler(handler); }
    @Override public HttpServerResponse bodyEndHandler(Handler<Void> handler) { log.trace("{}: bodyEndHandler()", dbgHint); return delegate.bodyEndHandler(handler); }
    @Override public long bytesWritten() { log.trace("{}: bytesWritten()", dbgHint); return delegate.bytesWritten(); }
    @Override public int streamId() { log.trace("{}: streamId()", dbgHint); return delegate.streamId(); }
    @Override public HttpServerResponse push(HttpMethod method, String host, String path, Handler<AsyncResult<HttpServerResponse>> handler) { log.trace("{}: push(Mthd,Str,Str,Hdlr)", dbgHint); return delegate.push(method, host, path, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String host, String path) { log.trace("{}: push(Mthd,Str,Str)", dbgHint); return delegate.push(method, host, path); }
    @Override public HttpServerResponse push(HttpMethod method, String path, MultiMap headers, Handler<AsyncResult<HttpServerResponse>> handler) { log.trace("{}: push(Mthd,Str,Map,Hdlr)", dbgHint); return delegate.push(method, path, headers, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String path, MultiMap headers) { log.trace("{}: push(Mthd,Str,Map)", dbgHint); return delegate.push(method, path, headers); }
    @Override public HttpServerResponse push(HttpMethod method, String path, Handler<AsyncResult<HttpServerResponse>> handler) { log.trace("{}: push(Mthd,Str,Hdlr)", dbgHint); return delegate.push(method, path, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String path) { log.trace("{}: push(Mthd,Str)", dbgHint); return delegate.push(method, path); }
    @Override public HttpServerResponse push(HttpMethod method, String host, String path, MultiMap headers, Handler<AsyncResult<HttpServerResponse>> handler) { log.trace("{}: push(Mthd,Str,Str,Map,Hdlr)", dbgHint); return delegate.push(method, host, path, headers, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String host, String path, MultiMap headers) { log.trace("{}: push(Mthd,Str,Str,Map)", dbgHint); return delegate.push(method, host, path, headers); }
    @Override public boolean reset() { log.trace("{}: reset(void)", dbgHint); return delegate.reset(); }
    @Override public boolean reset(long code) { log.trace("{}: reset({})", dbgHint, code); return delegate.reset(code); }
    @Override public HttpServerResponse writeCustomFrame(int type, int flags, Buffer payload) { log.trace("{}: writeCustomFrame({}, {}, Buf)", dbgHint, type, flags); return delegate.writeCustomFrame(type, flags, payload); }
    @Override public HttpServerResponse writeCustomFrame(HttpFrame frame) { log.trace("{}: writeCustomFrame()", dbgHint); return delegate.writeCustomFrame(frame); }
    @Override public HttpServerResponse setStreamPriority(StreamPriority streamPriority) { log.trace("{}: setStreamPriority()", dbgHint); return delegate.setStreamPriority(streamPriority); }
    @Override public HttpServerResponse addCookie(Cookie cookie) { log.trace("{}: addCookie()", dbgHint); return delegate.addCookie(cookie); }
    @Override public Cookie removeCookie(String name) { log.trace("{}: removeCookie({})", dbgHint, name); return delegate.removeCookie(name); }
    @Override public Cookie removeCookie(String name, boolean invalidate) { log.trace("{}: removeCookie({}, {})", dbgHint, name, invalidate); return delegate.removeCookie(name, invalidate); }
    @Override public Set<Cookie> removeCookies(String name) { log.trace("{}: removeCookies({})", dbgHint, name); return delegate.removeCookies(name); }
    @Override public Set<Cookie> removeCookies(String name, boolean invalidate) { log.trace("{}: removeCookies({}, {})", dbgHint, name, invalidate); return delegate.removeCookies(name, invalidate); }
    @Override public Cookie removeCookie(String name, String domain, String path) { log.trace("{}: removeCookie({}, Str, Str)", dbgHint, name); return delegate.removeCookie(name, domain, path); }
    @Override public Cookie removeCookie(String name, String domain, String path, boolean invalidate) { log.trace("{}: removeCookie({}, Str, Str, {})", dbgHint, name, invalidate); return delegate.removeCookie(name, domain, path, invalidate); }
    @Override public Future<Void> write(Buffer data) { log.trace("{}: write(Buf)", dbgHint); return delegate.write(data); }
    @Override public void write(Buffer data, Handler<AsyncResult<Void>> handler) { log.trace("{}: write(Buf, Hdlr)", dbgHint); delegate.write(data, handler); }
    @Override public void end(Handler<AsyncResult<Void>> handler) { log.trace("{}: end(Hdlr)", dbgHint); delegate.end(handler); }
    @Override public boolean writeQueueFull() { log.trace("{}: writeQueueFull()", dbgHint); return delegate.writeQueueFull(); }

}
