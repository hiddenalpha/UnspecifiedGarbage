package ch.hiddenalpha.unspecifiedgarbage.octetstream;


/**
 * Same idea as {@link java.io.InputStream#nullInputStream()} but serving an empty gzip
 * instead.
 */
public class EmptyGzipInputStream extends java.io.ByteArrayInputStream {

    private static final byte[] EMPTY_GZIP = {
        0x1F, (byte) 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // gzip header
        0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // empty deflate stream
    };

    /** Count of bytes this stream will serve */
    public static final int length = EMPTY_GZIP.length;

    public EmptyGzipInputStream() {
        super(EMPTY_GZIP);
    }

}
