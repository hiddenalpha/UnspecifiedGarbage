package ch.hiddenalpha.unspecifiedgarbage.errorhandling;


public class DebugInfo {

    public static int __FILE__(){
        return Thread.currentThread().getStackTrace()[2].getFileName();
    }

    public static int __LINE__(){
        return Thread.currentThread().getStackTrace()[2].getLineNumber();
    }

    public static int __func__(){
        return Thread.currentThread().getStackTrace()[2].getMethodName();
    }

    public static int __CLASS__(){
        return Thread.currentThread().getStackTrace()[2].getClassName();
    }

    public static String __WHERE__() {
        var frame = Thread.currentThread().getStackTrace()[2];
        return frame.getClassName() + "." + frame.getMethodName() + "():L" + frame.getLineNumber();
    }

}

