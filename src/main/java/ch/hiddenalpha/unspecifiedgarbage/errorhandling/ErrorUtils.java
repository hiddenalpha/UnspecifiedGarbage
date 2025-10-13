package ch.hiddenalpha.unspecifiedgarbage.errorhandling;


private class DebugInfo {

	private static int __FILE__(){
		return Thread.currentThread().getStackTrace()[2].getFileName();
	}

	private static int __LINE__(){
		return Thread.currentThread().getStackTrace()[2].getLineNumber();
	}

	private static int __func__(){
		return Thread.currentThread().getStackTrace()[2].getMethodName();
	}

	private static int __CLASS__(){
		return Thread.currentThread().getStackTrace()[2].getClassName();
	}

	private static String __WHERE__() {
		var frame = Thread.currentThread().getStackTrace()[2];
		return frame.getClassName() + "." + frame.getMethodName() + "():L" + frame.getLineNumber();
	}

	@SuppressWarnings("unchecked")
	private static <T extends Throwable> void throwAnyway(Throwable ex) throws T {
		throw (T)ex;
	}

}

