package ch.hiddenalpha.unspecifiedgarbage.shell;


public class ShellUtils {

    /**
     * Escapes the string so we can use the result in a
     * <a href="https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_02_03">double-quoted shell string</a>.
     * But keeps <a href="https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_06_02">parameter expansion</a>
     * alive.
     * Example usage:
     * <code>
     *   String path = "pâth \\with ${varToResolve} but a|so €vil chars like spaces, p|pes or * asterisk";<br/>
     *   cmd = "ls \""+ escapeForDblQuotButParams(path) +"\"";<br/>
     * </code>
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
     * <code>
     *   String path = "pâth \\with ${MustNotResolveThisVar} and a|so €vil chars like spaces, p|pes or * asterisk";<br/>
     *   cmd = "ls '"+ escapeForSnglQuotEverything(path) +"'";<br/>
     * </code>
     * <p>For a more detailed explanation see <a
     * href="https://hiddenalpha.ch/slnk/id/1-ea62ea0b8635c39#f4a94246c53735a69">How
     * to escape shell commands</a>.</p>
     */
    public static String escapeForSingleQuotEverything( String s ){
        return s.replace("'", "'\"'\"'");
    }

}
