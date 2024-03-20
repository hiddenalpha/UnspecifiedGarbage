package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge;

import io.vertx.core.json.JsonObject;
import io.vertx.core.metrics.MetricsOptions;
import io.vertx.core.spi.VertxMetricsFactory;


public class FailFastMetricsOptions extends io.vertx.core.metrics.MetricsOptions {

    private final String dbgMsg;

    public FailFastMetricsOptions( String dbgMsg ){ this.dbgMsg = dbgMsg; }

    public FailFastMetricsOptions(){ this(failCtor()); }

    private FailFastMetricsOptions( MetricsOptions o ){ this(failCtor()); }

    private FailFastMetricsOptions( JsonObject json ){ this(failCtor()); }

    private static String failCtor(){ throw new IllegalStateException("Do NOT use this ctor!"); }

    @Override public boolean isEnabled(){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public MetricsOptions setEnabled(boolean en){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public VertxMetricsFactory getFactory(){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public MetricsOptions setFactory( VertxMetricsFactory f ){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public JsonObject toJson(){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public String toString(){ throw new UnsupportedOperationException(dbgMsg); }

}

