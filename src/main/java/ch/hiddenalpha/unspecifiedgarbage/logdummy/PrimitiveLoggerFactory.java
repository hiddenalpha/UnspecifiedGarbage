package ch.hiddenalpha.unspecifiedgarbage.logdummy;

import org.slf4j.ILoggerFactory;
import org.slf4j.Logger;
import org.slf4j.Marker;


/**
 * 1. Put this class somewhere.
 * 2. Then move all classes from '..mocks' to 'org.slf4j'.
 */
public class PrimitiveLoggerFactory {

    private static final LoggerFactoryImpl loggerFactory = new LoggerFactoryImpl();

    public static ILoggerFactory getILoggerFactory(){ return loggerFactory; }

    public static Logger getLogger( String name ){
        return loggerFactory.getLogger(name);
    }

}


class LoggerFactoryImpl implements  ILoggerFactory {

    @Override
    public Logger getLogger( String name ){
        return new PrimitiveLogger(name);
    }

}


class PrimitiveLogger implements Logger {
    private final String name;

    PrimitiveLogger( String name ){ this.name = name; }

    @Override public String getName() { return name; }

    @Override public boolean isTraceEnabled() { return false; }
    @Override public boolean isDebugEnabled() { return false; }
    @Override public boolean isInfoEnabled() { return false; }
    @Override public boolean isWarnEnabled() { return false; }
    @Override public boolean isErrorEnabled() { return false; }

    @Override public boolean isTraceEnabled(Marker marker) { return false; }
    @Override public boolean isDebugEnabled(Marker marker) { return false; }
    @Override public boolean isInfoEnabled(Marker marker) { return false; }
    @Override public boolean isWarnEnabled(Marker marker) { return false; }
    @Override public boolean isErrorEnabled(Marker marker) { return false; }

    @Override public void trace(String s) { }
    @Override public void trace(String s, Object o) { }
    @Override public void trace(String s, Object o, Object o1) { }
    @Override public void trace(String s, Object... objects) { }
    @Override public void trace(String s, Throwable throwable) { }

    @Override public void trace(Marker marker, String s) { }
    @Override public void trace(Marker marker, String s, Object o) { }
    @Override public void trace(Marker marker, String s, Object o, Object o1) { }
    @Override public void trace(Marker marker, String s, Object... objects) { }
    @Override public void trace(Marker marker, String s, Throwable throwable) { }

    @Override public void debug(String s) { }
    @Override public void debug(String s, Object o) { }
    @Override public void debug(String s, Object o, Object o1) { }
    @Override public void debug(String s, Object... objects) { }
    @Override public void debug(String s, Throwable throwable) { }

    @Override public void debug(Marker marker, String s) { }
    @Override public void debug(Marker marker, String s, Object o) { }
    @Override public void debug(Marker marker, String s, Object o, Object o1) { }
    @Override public void debug(Marker marker, String s, Object... objects) { }
    @Override public void debug(Marker marker, String s, Throwable throwable) { }

    @Override public void info(String s) { }
    @Override public void info(String s, Object o) { }
    @Override public void info(String s, Object o, Object o1) { }
    @Override public void info(String s, Object... objects) { }
    @Override public void info(String s, Throwable throwable) { }

    @Override public void info(Marker marker, String s) { }
    @Override public void info(Marker marker, String s, Object o) { }
    @Override public void info(Marker marker, String s, Object o, Object o1) { }
    @Override public void info(Marker marker, String s, Object... objects) { }
    @Override public void info(Marker marker, String s, Throwable throwable) { }

    @Override public void warn(String s) { }
    @Override public void warn(String s, Object o) { }
    @Override public void warn(String s, Object... objects) { }
    @Override public void warn(String s, Object o, Object o1) { }
    @Override public void warn(String s, Throwable throwable) { }

    @Override public void warn(Marker marker, String s) { }
    @Override public void warn(Marker marker, String s, Object o) { }
    @Override public void warn(Marker marker, String s, Object o, Object o1) { }
    @Override public void warn(Marker marker, String s, Object... objects) { }
    @Override public void warn(Marker marker, String s, Throwable throwable) { }

    @Override public void error(String s) { }
    @Override public void error(String s, Object o) { }
    @Override public void error(String s, Object o, Object o1) { }
    @Override public void error(String s, Object... objects) { }
    @Override public void error(String s, Throwable throwable) { }

    @Override public void error(Marker marker, String s) { }
    @Override public void error(Marker marker, String s, Object o) { }
    @Override public void error(Marker marker, String s, Object o, Object o1) { }
    @Override public void error(Marker marker, String s, Object... objects) { }
    @Override public void error(Marker marker, String s, Throwable throwable) { }

}
