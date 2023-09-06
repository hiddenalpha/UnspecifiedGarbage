package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * <p>Suppresses to close the underlying {@link java.io.OutputStream} when
 * close gets called.</p>
 *
 * <p>This can be needed for example we get a outputStream passed from caller
 * and we have to pass it further down to another callee. Which may close the
 * passed stream. But this is unlucky if our caller (or we ourself) needs to
 * continue writing to the original stream after we have completed writing what
 * we were supposed to write.</p>
 *
 * <p>For example imagine we're creating a tar archive and pass our
 * outputStream down to some source which will write a tar entries payload to
 * the stream and in the end closes the sink. This would make it impossible for
 * us to write any more entries to that stream.</p>
 *
 * <p>WARN: Think before using this filter! Blindly using it without
 * understanding what this is for, you risk to produce resource-leaks.</p>
 */
public class IgnoreCloseOutputStream extends java.io.FilterOutputStream {

  public IgnoreCloseOutputStream(java.io.OutputStream out) {
    super(out);
  }

  @Override public void close() {/*no-op*/}

}

