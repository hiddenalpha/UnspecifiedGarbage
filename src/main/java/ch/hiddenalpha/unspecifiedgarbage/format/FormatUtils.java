package ch.hiddenalpha.unspecifiedgarbage.format;


public class FormatUtils {

    /**
     * Tries to format 'val' as a small integer. If not possible falls back
     * to decimal representation. If also not possible, falls back to scientific
     * notation.
     *
     * Handy in cases where we need to "just print that number" without having
     * stupid amount of nonsense decimal places or bother readers with
     * scientific notation where "just an int" would perfectly do the job.
     *
     * @param val
     *      The number to format.
     *
     * @param ndig
     *      How many significant digits to be printed. MUST be in range 1..7.
     */
    public static String toStr(float val, int ndig) {
        int exp;
        float limit;
        if (val == 0) return "0";
        switch (ndig) {
            case 1: exp = 1; limit = 1e4F; break;
            case 2: exp = 10; limit = 1e6F; break;
            case 3: exp = 100; limit = 1e7F; break;
            case 4: exp = 1000; limit = 1e8F; break;
            case 5: exp = 10000; limit = 1e9F; break;
            case 6: exp = 100000; limit = 1e10F; break;
            case 7: exp = 1000000; limit = 1e11F; break;
            default: throw new IllegalArgumentException("ndig " + ndig + " not in expected range 1..7");
        }
        if (val >= exp && val <= limit) {
            // Just print as an int.
            return String.valueOf((int) val);
        } else {
            String fmt;
            switch (ndig) { // Select an appropriate format.
                case 1: fmt = "%.1g"; break;
                case 2: fmt = "%.2g"; break;
                case 3: fmt = "%.3g"; break;
                case 4: fmt = "%.4g"; break;
                case 5: fmt = "%.5g"; break;
                case 6: fmt = "%.6g"; break;
                case 7: fmt = "%.7g"; break;
                default: throw new IllegalArgumentException("ndig " + ndig + " not in expected range 1..7");
            }
            return String.format(fmt, val).replace(',', '.').replace("'", "");
        }
    }

}
