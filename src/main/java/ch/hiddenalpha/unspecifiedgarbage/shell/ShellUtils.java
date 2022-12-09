package ch.hiddenalpha.unspecifiedgarbage.shell;


public class ShellUtils {

    /**
     * Escapes the string so we can use the result in a
     * <a href="https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_02_03">double-quoted shell string</a>.
     * But keeps <a href="https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_06_02">parameter expansion</a> alive.
     * Example usage:
     *   String path = "pâth \\with ${varToResolve} but a|so €vil chars like spaces, p|pes or * asterisk";
     *   cmd = "ls '"+ escapeForSnglQuotEverything(path) +"'";
     */
    public static String escapeForDblQuotButParams( String s ){
        s = s.replace("\\", "\\\\");
        s = s.replace("\"", "\\\"");
        s = s.replace("`", "\\`");
        // do NOT escape '$' as we want to keep parameter expansion.
        return s;
    }

    /**
     * Escapes the string so we can use result in a
     * <a href="https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_02_02">single-quoted shell string</a>.
     * Example usage:
     *   String path = "pâth \\with ${MustNotResolveThisVar} and a|so €vil chars like spaces, p|pes or * asterisk";
     *   cmd = "ls '"+ escapeForSnglQuotEverything(path) +"'";
     */
    public static String escapeForSingleQuotEverything( String s ){
        // Cited from "Single-Quotes" in "https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html":
        //   Enclosing characters in single-quotes shall preserve the literal
        //   value of each character within the single-quotes. A single-quote
        //   cannot occur within single-quotes.
        // Cited from "Double-Quotes" in "https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html":
        //   Enclosing characters in double-quotes ( "" ) shall preserve the
        //   literal value of all characters within the double-quotes, with the
        //   exception of the characters dollar sign, backquote, and backslash
        return s.replace("'", "'\"'\"'");
    }

}
