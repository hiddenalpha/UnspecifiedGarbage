package ch.hiddenalpha.unspecifiedgarbage.format;


/** Obsolete: This class did migrate to "xtra4j" */
@Deprecated
public class FormatUtils {

    /* TODO should we move this to xtra4j? */
    public static String getAsHexStr( byte[] src, int srcOff, int len ){
        byte[] tmp = new byte[len * 2];
        for( int i = 0 ; i < len ; ++i ){
            int lo = src[srcOff + i] & 0x0F, hi = (src[srcOff + i] >>> 4) & 0x0F;
            tmp[2 * i] = (byte)( (hi <= 9) ? hi + '0' : hi + 'A' - 10 );
            tmp[2 * i + 1] = (byte)( (lo <= 9) ? lo + '0' : lo + 'A' - 10 );
        }
        return new String(tmp, US_ASCII);
    }

}
