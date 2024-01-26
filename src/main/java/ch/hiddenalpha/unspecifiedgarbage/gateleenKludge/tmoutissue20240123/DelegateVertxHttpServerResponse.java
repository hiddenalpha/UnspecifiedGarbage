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

import java.util.Set;

public class DelegateVertxHttpServerResponse implements HttpServerResponse {

    private final HttpServerResponse delegate;

    public DelegateVertxHttpServerResponse(HttpServerResponse delegate) {
        this.delegate = delegate;
    }

    @Override public HttpServerResponse exceptionHandler(Handler<Throwable> handler) { return delegate.exceptionHandler(handler); }
    @Override public HttpServerResponse setWriteQueueMaxSize(int maxSize) { return delegate.setWriteQueueMaxSize(maxSize); }
    @Override public HttpServerResponse drainHandler(Handler<Void> handler) { return delegate.drainHandler(handler); }
    @Override public int getStatusCode() { return delegate.getStatusCode(); }
    @Override public HttpServerResponse setStatusCode(int statusCode) { return delegate.setStatusCode(statusCode); }
    @Override public String getStatusMessage() { return delegate.getStatusMessage(); }
    @Override public HttpServerResponse setStatusMessage(String statusMessage) { return delegate.setStatusMessage(statusMessage); }
    @Override public HttpServerResponse setChunked(boolean chunked) { return delegate.setChunked(chunked); }
    @Override public boolean isChunked() { return delegate.isChunked(); }
    @Override public MultiMap headers() { return delegate.headers(); }
    @Override public HttpServerResponse putHeader(String name, String value) { return delegate.putHeader(name, value); }
    @Override public HttpServerResponse putHeader(CharSequence name, CharSequence value) { return delegate.putHeader(name, value); }
    @Override public HttpServerResponse putHeader(String name, Iterable<String> values) { return delegate.putHeader(name, values); }
    @Override public HttpServerResponse putHeader(CharSequence name, Iterable<CharSequence> values) { return delegate.putHeader(name, values); }
    @Override public MultiMap trailers() { return delegate.trailers(); }
    @Override public HttpServerResponse putTrailer(String name, String value) { return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse putTrailer(CharSequence name, CharSequence value) { return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse putTrailer(String name, Iterable<String> values) { return delegate.putTrailer(name, values); }
    @Override public HttpServerResponse putTrailer(CharSequence name, Iterable<CharSequence> value) { return delegate.putTrailer(name, value); }
    @Override public HttpServerResponse closeHandler(Handler<Void> handler) { return delegate.closeHandler(handler); }
    @Override public HttpServerResponse endHandler(Handler<Void> handler) { return delegate.endHandler(handler); }
    @Override public Future<Void> write(String chunk, String enc) { return delegate.write(chunk, enc); }
    @Override public void write(String chunk, String enc, Handler<AsyncResult<Void>> handler) { delegate.write(chunk, enc, handler); }
    @Override public Future<Void> write(String chunk) { return delegate.write(chunk); }
    @Override public void write(String chunk, Handler<AsyncResult<Void>> handler) { delegate.write(chunk, handler); }
    @Override public HttpServerResponse writeContinue() { return delegate.writeContinue(); }
    @Override public Future<Void> end(String chunk) { return delegate.end(chunk); }
    @Override public void end(String chunk, Handler<AsyncResult<Void>> handler) { delegate.end(chunk, handler); }
    @Override public Future<Void> end(String chunk, String enc) { return delegate.end(chunk, enc); }
    @Override public void end(String chunk, String enc, Handler<AsyncResult<Void>> handler) { delegate.end(chunk, enc, handler); }
    @Override public Future<Void> end(Buffer chunk) { return delegate.end(chunk); }
    @Override public void end(Buffer chunk, Handler<AsyncResult<Void>> handler) { delegate.end(chunk, handler); }
    @Override public Future<Void> end() { return delegate.end(); }
    @Override public void send(Handler<AsyncResult<Void>> handler) { delegate.send(handler); }
    @Override public Future<Void> send() { return delegate.send(); }
    @Override public void send(String body, Handler<AsyncResult<Void>> handler) { delegate.send(body, handler); }
    @Override public Future<Void> send(String body) { return delegate.send(body); }
    @Override public void send(Buffer body, Handler<AsyncResult<Void>> handler) { delegate.send(body, handler); }
    @Override public Future<Void> send(Buffer body) { return delegate.send(body); }
    @Override public void send(ReadStream<Buffer> body, Handler<AsyncResult<Void>> handler) { delegate.send(body, handler); }
    @Override public Future<Void> send(ReadStream<Buffer> body) { return delegate.send(body); }
    @Override public Future<Void> sendFile(String filename) { return delegate.sendFile(filename); }
    @Override public Future<Void> sendFile(String filename, long offset) { return delegate.sendFile(filename, offset); }
    @Override public Future<Void> sendFile(String filename, long offset, long length) { return delegate.sendFile(filename, offset, length); }
    @Override public HttpServerResponse sendFile(String filename, Handler<AsyncResult<Void>> resultHandler) { return delegate.sendFile(filename, resultHandler); }
    @Override public HttpServerResponse sendFile(String filename, long offset, Handler<AsyncResult<Void>> resultHandler) { return delegate.sendFile(filename, offset, resultHandler); }
    @Override public HttpServerResponse sendFile(String filename, long offset, long length, Handler<AsyncResult<Void>> resultHandler) { return delegate.sendFile(filename, offset, length, resultHandler); }
    @Override public void close() { delegate.close(); }
    @Override public boolean ended() { return delegate.ended(); }
    @Override public boolean closed() { return delegate.closed(); }
    @Override public boolean headWritten() { return delegate.headWritten(); }
    @Override public HttpServerResponse headersEndHandler(Handler<Void> handler) { return delegate.headersEndHandler(handler); }
    @Override public HttpServerResponse bodyEndHandler(Handler<Void> handler) { return delegate.bodyEndHandler(handler); }
    @Override public long bytesWritten() { return delegate.bytesWritten(); }
    @Override public int streamId() { return delegate.streamId(); }
    @Override public HttpServerResponse push(HttpMethod method, String host, String path, Handler<AsyncResult<HttpServerResponse>> handler) { return delegate.push(method, host, path, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String host, String path) { return delegate.push(method, host, path); }
    @Override public HttpServerResponse push(HttpMethod method, String path, MultiMap headers, Handler<AsyncResult<HttpServerResponse>> handler) { return delegate.push(method, path, headers, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String path, MultiMap headers) { return delegate.push(method, path, headers); }
    @Override public HttpServerResponse push(HttpMethod method, String path, Handler<AsyncResult<HttpServerResponse>> handler) { return delegate.push(method, path, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String path) { return delegate.push(method, path); }
    @Override public HttpServerResponse push(HttpMethod method, String host, String path, MultiMap headers, Handler<AsyncResult<HttpServerResponse>> handler) { return delegate.push(method, host, path, headers, handler); }
    @Override public Future<HttpServerResponse> push(HttpMethod method, String host, String path, MultiMap headers) { return delegate.push(method, host, path, headers); }
    @Override public boolean reset() { return delegate.reset(); }
    @Override public boolean reset(long code) { return delegate.reset(code); }
    @Override public HttpServerResponse writeCustomFrame(int type, int flags, Buffer payload) { return delegate.writeCustomFrame(type, flags, payload); }
    @Override public HttpServerResponse writeCustomFrame(HttpFrame frame) { return delegate.writeCustomFrame(frame); }
    @Override public HttpServerResponse setStreamPriority(StreamPriority streamPriority) { return delegate.setStreamPriority(streamPriority); }
    @Override public HttpServerResponse addCookie(Cookie cookie) { return delegate.addCookie(cookie); }
    @Override public Cookie removeCookie(String name) { return delegate.removeCookie(name); }
    @Override public Cookie removeCookie(String name, boolean invalidate) { return delegate.removeCookie(name, invalidate); }
    @Override public Set<Cookie> removeCookies(String name) { return delegate.removeCookies(name); }
    @Override public Set<Cookie> removeCookies(String name, boolean invalidate) { return delegate.removeCookies(name, invalidate); }
    @Override public Cookie removeCookie(String name, String domain, String path) { return delegate.removeCookie(name, domain, path); }
    @Override public Cookie removeCookie(String name, String domain, String path, boolean invalidate) { return delegate.removeCookie(name, domain, path, invalidate); }
    @Override public Future<Void> write(Buffer data) { return delegate.write(data); }
    @Override public void write(Buffer data, Handler<AsyncResult<Void>> handler) { delegate.write(data, handler); }
    @Override public void end(Handler<AsyncResult<Void>> handler) { delegate.end(handler); }
    @Override public boolean writeQueueFull() { return delegate.writeQueueFull(); }

}
