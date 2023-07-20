package ch.hiddenalpha.unspecifiedgarbage.json;

import java.util.Map;


public class JsonUtils {

    /**
     * Exampe usage:
     *
     *   com.fasterxml.jackson.core.JsonParser parser = ;
     *   com.fasterxml.jackson.databind.JsonNode node = ;
     *   Map<String, Object> result;
     *   result = JsonUtils.decodeMap(parser.getCodec()::treeToValue, node, String.class, Object.class);
     *
     * @param mapNode   Node to parse as a map.
     * @param keyType   Expected type of map key.
     * @param valueType Expected type of map value.
     * @param <K>       Corresponds with 'keyType'.
     * @param <V>       Corresponds with 'valueType'.
     * @return Parsed map.
     */
    public static
    <TreeToValueFunc extends ObjectCodecIface<JsonNode, Map>, JsonNode, K, V>
    Map<K, V> decodeMap( TreeToValueFunc treeToValueFunc, JsonNode mapNode, Class<K> keyType, Class<V> valueType ) throws java.io.IOException {
        final Map<K, V> envVars;
        if( mapNode == null ){
            envVars = new java.util.LinkedHashMap<>();
        }else{
            envVars = treeToValueFunc.treeToValue(mapNode, Map.class);
        }
        return envVars;
    }

    public static interface ObjectCodecIface<TreeNode, Value> {
        Value treeToValue( TreeNode input, Class<Map> returnType ) throws java.io.IOException;
    }


    // Notes for Vertx

    //public static <T> T fromJsonObject( io.vertx.core.json.JsonObject jsonObject , Class<T> targetType ) {
    //    return io.vertx.core.json.Json.decodeValue( jsonObject.encode() , targetType );
    //}

    //public static io.vertx.core.json.JsonObject toJsonObject( Object obj ) {
    //    return io.vertx.core.json.JsonObject.mapFrom( obj );
    //}

}
