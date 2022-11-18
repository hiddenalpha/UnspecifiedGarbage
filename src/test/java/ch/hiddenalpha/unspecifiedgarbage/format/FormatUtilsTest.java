package ch.hiddenalpha.unspecifiedgarbage.format;

import org.junit.Assert;
import org.junit.Test;


public class FormatUtilsTest {

    @Test(expected = IllegalArgumentException.class)
    public void worksAsExpectedWithN0() {
        FormatUtils.toStr(123F, 0);
    }

    @Test(expected = IllegalArgumentException.class)
    public void worksAsExpectedWithN8() {
        FormatUtils.toStr(123F, 8);
    }

    @Test
    public void shortensZero() {
        for( int i = 0 ; i < 7 ; ++i ){
            Assert.assertEquals("0", FormatUtils.toStr(0, i + 1));
        }
    }

    @Test
    public void worksAsExpectedWithN1() {
        Assert.assertEquals("1e-09", FormatUtils.toStr(0.0000000012345F, 1));
        Assert.assertEquals("1e-08", FormatUtils.toStr(0.000000012345F, 1));
        Assert.assertEquals("1e-07", FormatUtils.toStr(0.00000012345F, 1));
        Assert.assertEquals("1e-06", FormatUtils.toStr(0.0000012345F, 1));
        Assert.assertEquals("1e-05", FormatUtils.toStr(0.000012345F, 1));
        Assert.assertEquals("0.0001", FormatUtils.toStr(0.00012345F, 1));
        Assert.assertEquals("0.001", FormatUtils.toStr(0.0012345F, 1));
        Assert.assertEquals("0.01", FormatUtils.toStr(0.012345F, 1));
        Assert.assertEquals("0.1", FormatUtils.toStr(0.12345F, 1));
        Assert.assertEquals("1", FormatUtils.toStr(1.2345F, 1));
        Assert.assertEquals("12", FormatUtils.toStr(12.345F, 1));
        Assert.assertEquals("123", FormatUtils.toStr(123.45F, 1));
        Assert.assertEquals("1234", FormatUtils.toStr(1234.5F, 1));
        Assert.assertEquals("1e+04", FormatUtils.toStr(12345F, 1));
        Assert.assertEquals("1e+05", FormatUtils.toStr(123450F, 1));
        Assert.assertEquals("1e+06", FormatUtils.toStr(1234500F, 1));
        Assert.assertEquals("1e+07", FormatUtils.toStr(12345000F, 1));
        Assert.assertEquals("1e+08", FormatUtils.toStr(123450000F, 1));
        Assert.assertEquals("1e+09", FormatUtils.toStr(1234500000F, 1));
    }

    @Test
    public void worksAsExpectedWithN2() {
        Assert.assertEquals("1.2e-09", FormatUtils.toStr(0.0000000012345F, 2));
        Assert.assertEquals("1.2e-08", FormatUtils.toStr(0.000000012345F, 2));
        Assert.assertEquals("1.2e-07", FormatUtils.toStr(0.00000012345F, 2));
        Assert.assertEquals("1.2e-06", FormatUtils.toStr(0.0000012345F, 2));
        Assert.assertEquals("1.2e-05", FormatUtils.toStr(0.000012345F, 2));
        Assert.assertEquals("0.00012", FormatUtils.toStr(0.00012345F, 2));
        Assert.assertEquals("0.0012", FormatUtils.toStr(0.0012345F, 2));
        Assert.assertEquals("0.012", FormatUtils.toStr(0.012345F, 2));
        Assert.assertEquals("0.12", FormatUtils.toStr(0.12345F, 2));
        Assert.assertEquals("1.2", FormatUtils.toStr(1.2345F, 2));
        Assert.assertEquals("12", FormatUtils.toStr(12.345F, 2));
        Assert.assertEquals("123", FormatUtils.toStr(123.45F, 2));
        Assert.assertEquals("1234", FormatUtils.toStr(1234.5F, 2));
        Assert.assertEquals("12345", FormatUtils.toStr(12345F, 2));
        Assert.assertEquals("123450", FormatUtils.toStr(123450F, 2));
        Assert.assertEquals("1.2e+06", FormatUtils.toStr(1234500F, 2));
        Assert.assertEquals("1.2e+07", FormatUtils.toStr(12345000F, 2));
        Assert.assertEquals("1.2e+08", FormatUtils.toStr(123450000F, 2));
        Assert.assertEquals("1.2e+09", FormatUtils.toStr(1234500000F, 2));
    }

    @Test
    public void worksAsExpectedWithN3() {
        Assert.assertEquals("1.23e-09", FormatUtils.toStr(0.0000000012345F, 3));
        Assert.assertEquals("1.23e-08", FormatUtils.toStr(0.000000012345F, 3));
        Assert.assertEquals("1.23e-07", FormatUtils.toStr(0.00000012345F, 3));
        Assert.assertEquals("1.23e-06", FormatUtils.toStr(0.0000012345F, 3));
        Assert.assertEquals("1.23e-05", FormatUtils.toStr(0.000012345F, 3));
        Assert.assertEquals("0.000123", FormatUtils.toStr(0.00012345F, 3));
        Assert.assertEquals("0.00123", FormatUtils.toStr(0.0012345F, 3));
        Assert.assertEquals("0.0123", FormatUtils.toStr(0.012345F, 3));
        Assert.assertEquals("0.123", FormatUtils.toStr(0.12345F, 3));
        Assert.assertEquals("1.23", FormatUtils.toStr(1.2345F, 3));
        Assert.assertEquals("12.3", FormatUtils.toStr(12.345F, 3));
        Assert.assertEquals("123", FormatUtils.toStr(123.45F, 3));
        Assert.assertEquals("1234", FormatUtils.toStr(1234.5F, 3));
        Assert.assertEquals("12345", FormatUtils.toStr(12345F, 3));
        Assert.assertEquals("123450", FormatUtils.toStr(123450F, 3));
        Assert.assertEquals("1234500", FormatUtils.toStr(1234500F, 3));
        Assert.assertEquals("1.23e+07", FormatUtils.toStr(12345000F, 3));
        Assert.assertEquals("1.23e+08", FormatUtils.toStr(123450000F, 3));
        Assert.assertEquals("1.23e+09", FormatUtils.toStr(1234500000F, 3));
    }

    @Test
    public void worksAsExpectedWithN4() {
        Assert.assertEquals("1.234e-05", FormatUtils.toStr(0.000012345F, 4));
        Assert.assertEquals("0.0001234", FormatUtils.toStr(0.00012345F, 4));
        Assert.assertEquals("0.001234", FormatUtils.toStr(0.0012345F, 4));
        Assert.assertEquals("0.01235", FormatUtils.toStr(0.012345F, 4));
        Assert.assertEquals("0.1235", FormatUtils.toStr(0.12345F, 4));
        Assert.assertEquals("1.235", FormatUtils.toStr(1.2345F, 4));
        Assert.assertEquals("12.35", FormatUtils.toStr(12.345F, 4));
        Assert.assertEquals("123.4", FormatUtils.toStr(123.45F, 4));
        Assert.assertEquals("1234", FormatUtils.toStr(1234.5F, 4));
        Assert.assertEquals("12345", FormatUtils.toStr(12345F, 4));
        Assert.assertEquals("123450", FormatUtils.toStr(123450F, 4));
        Assert.assertEquals("1234500", FormatUtils.toStr(1234500F, 4));
        Assert.assertEquals("12345000", FormatUtils.toStr(12345000F, 4));
        Assert.assertEquals("1.235e+08", FormatUtils.toStr(123450000F, 4));
    }

}
