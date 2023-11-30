package org.apache.logging.slf4j;

import org.apache.logging.log4j.spi.ExtendedLogger;
import org.slf4j.Marker;
import org.slf4j.event.Level;
import org.slf4j.spi.LocationAwareLogger;
import org.slf4j.spi.LoggingEventBuilder;

import java.io.Serializable;


/**
 * <p>FU** this fu***** damn sh** code that still tries to use log4j, no matter
 * how strong we tell it NOT to use it!</p>
 *
 * <p>This class only exists to prevent services from starting if IDEA still
 * did miss the dependency changes in pom and still tries to use the wrong
 * logger impl. So that I once and for all time can stop wasting my time
 * waiting for logs which never arive because the wrong logger still is used
 * somewhere.</p>
 */
public class Log4jLogger implements LocationAwareLogger, Serializable {

    private final org.slf4j.Logger log;

    Log4jLogger(final Log4jMarkerFactory markerFactory, final ExtendedLogger logger, final String name) {
        this.log = new org.slf4j.simple.SimpleLoggerFactory().getLogger(name);
    }

    @Override public void log(Marker marker, String s, int i, String s1, Object[] objects, Throwable throwable) {
        throw new UnsupportedOperationException(/*TODO*/"Not impl yet");
    }

    @Override public String getName() { return log.getName(); }
    @Override public LoggingEventBuilder makeLoggingEventBuilder(Level level) { return log.makeLoggingEventBuilder(level); }
    @Override public LoggingEventBuilder atLevel(Level level) { return log.atLevel(level); }
    @Override public boolean isEnabledForLevel(Level level) { return log.isEnabledForLevel(level); }
    @Override public boolean isTraceEnabled() { return log.isTraceEnabled(); }
    @Override public void trace(String s) { log.trace(s); }
    @Override public void trace(String s, Object o) { log.trace(s, o); }
    @Override public void trace(String s, Object o, Object o1) { log.trace(s, o, o1); }
    @Override public void trace(String s, Object... objects) { log.trace(s, objects); }
    @Override public void trace(String s, Throwable throwable) { log.trace(s, throwable); }
    @Override public boolean isTraceEnabled(Marker marker) { return log.isTraceEnabled(marker); }
    @Override public LoggingEventBuilder atTrace() { return log.atTrace(); }
    @Override public void trace(Marker marker, String s) { log.trace(marker, s); }
    @Override public void trace(Marker marker, String s, Object o) { log.trace(marker, s, o); }
    @Override public void trace(Marker marker, String s, Object o, Object o1) { log.trace(marker, s, o, o1); }
    @Override public void trace(Marker marker, String s, Object... objects) { log.trace(marker, s, objects); }
    @Override public void trace(Marker marker, String s, Throwable throwable) { log.trace(marker, s, throwable); }
    @Override public boolean isDebugEnabled() { return log.isDebugEnabled(); }
    @Override public void debug(String s) { log.debug(s); }
    @Override public void debug(String s, Object o) { log.debug(s, o); }
    @Override public void debug(String s, Object o, Object o1) { log.debug(s, o, o1); }
    @Override public void debug(String s, Object... objects) { log.debug(s, objects); }
    @Override public void debug(String s, Throwable throwable) { log.debug(s, throwable); }
    @Override public boolean isDebugEnabled(Marker marker) { return log.isDebugEnabled(marker); }
    @Override public void debug(Marker marker, String s) { log.debug(marker, s); }
    @Override public void debug(Marker marker, String s, Object o) { log.debug(marker, s, o); }
    @Override public void debug(Marker marker, String s, Object o, Object o1) { log.debug(marker, s, o, o1); }
    @Override public void debug(Marker marker, String s, Object... objects) { log.debug(marker, s, objects); }
    @Override public void debug(Marker marker, String s, Throwable throwable) { log.debug(marker, s, throwable); }
    @Override public LoggingEventBuilder atDebug() { return log.atDebug(); }
    @Override public boolean isInfoEnabled() { return log.isInfoEnabled(); }
    @Override public void info(String s) { log.info(s); }
    @Override public void info(String s, Object o) { log.info(s, o); }
    @Override public void info(String s, Object o, Object o1) { log.info(s, o, o1); }
    @Override public void info(String s, Object... objects) { log.info(s, objects); }
    @Override public void info(String s, Throwable throwable) { log.info(s, throwable); }
    @Override public boolean isInfoEnabled(Marker marker) { return log.isInfoEnabled(marker); }
    @Override public void info(Marker marker, String s) { log.info(marker, s); }
    @Override public void info(Marker marker, String s, Object o) { log.info(marker, s, o); }
    @Override public void info(Marker marker, String s, Object o, Object o1) { log.info(marker, s, o, o1); }
    @Override public void info(Marker marker, String s, Object... objects) { log.info(marker, s, objects); }
    @Override public void info(Marker marker, String s, Throwable throwable) { log.info(marker, s, throwable); }
    @Override public LoggingEventBuilder atInfo() { return log.atInfo(); }
    @Override public boolean isWarnEnabled() { return log.isWarnEnabled(); }
    @Override public void warn(String s) { log.warn(s); }
    @Override public void warn(String s, Object o) { log.warn(s, o); }
    @Override public void warn(String s, Object... objects) { log.warn(s, objects); }
    @Override public void warn(String s, Object o, Object o1) { log.warn(s, o, o1); }
    @Override public void warn(String s, Throwable throwable) { log.warn(s, throwable); }
    @Override public boolean isWarnEnabled(Marker marker) { return log.isWarnEnabled(marker); }
    @Override public void warn(Marker marker, String s) { log.warn(marker, s); }
    @Override public void warn(Marker marker, String s, Object o) { log.warn(marker, s, o); }
    @Override public void warn(Marker marker, String s, Object o, Object o1) { log.warn(marker, s, o, o1); }
    @Override public void warn(Marker marker, String s, Object... objects) { log.warn(marker, s, objects); }
    @Override public void warn(Marker marker, String s, Throwable throwable) { log.warn(marker, s, throwable); }
    @Override public LoggingEventBuilder atWarn() { return log.atWarn(); }
    @Override public boolean isErrorEnabled() { return log.isErrorEnabled(); }
    @Override public void error(String s) { log.error(s); }
    @Override public void error(String s, Object o) { log.error(s, o); }
    @Override public void error(String s, Object o, Object o1) { log.error(s, o, o1); }
    @Override public void error(String s, Object... objects) { log.error(s, objects); }
    @Override public void error(String s, Throwable throwable) { log.error(s, throwable); }
    @Override public boolean isErrorEnabled(Marker marker) { return log.isErrorEnabled(marker); }
    @Override public void error(Marker marker, String s) { log.error(marker, s); }
    @Override public void error(Marker marker, String s, Object o) { log.error(marker, s, o); }
    @Override public void error(Marker marker, String s, Object o, Object o1) { log.error(marker, s, o, o1); }
    @Override public void error(Marker marker, String s, Object... objects) { log.error(marker, s, objects); }
    @Override public void error(Marker marker, String s, Throwable throwable) { log.error(marker, s, throwable); }
    @Override public LoggingEventBuilder atError() { return log.atError(); }

}
