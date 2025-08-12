package ch.hiddenalpha.unspecifiedgarbage.logdummy.mocks;
// package org.slf4j;

public interface LoggerFactory {
    static org.slf4j.Logger getLogger( Class clazz ){
        return getLogger(clazz.getCanonicalName());
    }
    static org.slf4j.Logger getLogger( String name ){
        return ch.hiddenalpha.unspecifiedgarbage.logdummy
                .PrimitiveLoggerFactory.getLogger(name);
    }
}
