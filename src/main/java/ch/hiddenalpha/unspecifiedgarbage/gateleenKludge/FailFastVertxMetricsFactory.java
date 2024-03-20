package ch.hiddenalpha.unspecifiedgarbage.gateleenKludge;

import io.vertx.core.VertxOptions;
import io.vertx.core.impl.VertxBuilder;
import io.vertx.core.json.JsonObject;
import io.vertx.core.metrics.MetricsOptions;
import io.vertx.core.spi.metrics.VertxMetrics;


public class FailFastVertxMetricsFactory implements io.vertx.core.spi.VertxMetricsFactory {

    private final String dbgMsg;

    public FailFastVertxMetricsFactory(String dbgMsg ){ this.dbgMsg = dbgMsg; }

    @Override public void init(VertxBuilder b) { throw new UnsupportedOperationException(dbgMsg); }

    @Override public VertxMetrics metrics(VertxOptions o){ throw new UnsupportedOperationException(dbgMsg); }

    @Override public MetricsOptions newOptions() { throw new UnsupportedOperationException(dbgMsg); }

    @Override public MetricsOptions newOptions(MetricsOptions o) { throw new UnsupportedOperationException(dbgMsg); }

    @Override public MetricsOptions newOptions(JsonObject j) { throw new UnsupportedOperationException(dbgMsg); }

}

