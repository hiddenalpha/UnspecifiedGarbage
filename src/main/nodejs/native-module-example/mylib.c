
#include <limits.h>

#include <node_api.h>

#ifdef __cplusplus
extern "C" {
#endif


static int
sum( int a, int b ){
	return a + b;
}


static napi_value
sumForNode( napi_env env, napi_callback_info info ){
	/* get incoming args */
	napi_status status;
	size_t const argc = 2;
	napi_value this_, args[2]; void *ctx;
	status = napi_get_cb_info(env, info, &argc, args, &this_, &ctx);
	if( status != napi_ok ){
		napi_throw_error(env, "EINVAL", "Something wrong with args");
		return NULL;
	}
	/* convert args to native types from nodejs types */
	double a, b;
	status = napi_get_value_double(env, args[0], &a);
	if( status != napi_ok ){
		napi_throw_type_error(env, "EINVAL", "Couldn't get arg 1 as number");
		return NULL;
	}
	status = napi_get_value_double(env, args[1], &b);
	if( status != napi_ok ){
		napi_throw_type_error(env, "EINVAL", "Couldn't get arg 2 as number");
		return NULL;
	}
	if( a < INT_MIN || a > INT_MAX || b < INT_MIN || b > INT_MAX ){
		napi_throw_error(env, "EINVAL", "args out of range");
		return NULL;
	}
	/* Do the actual work. */
	int result = sum(a, b);
	/* convert return value into a nodejs type. */
	napi_value napi_result;
	status = napi_create_int32(env, result, &napi_result);
	if( status != napi_ok ){
		napi_throw_error(env, NULL, "Failed to alloc return value");
		return NULL;
	}
	return napi_result;
}


static napi_value
init( napi_env env, napi_value exports ){
	void *ctx = NULL;
	napi_value fn;
	napi_status s;
	/**/
	s = napi_create_function(env, NULL, 0, sumForNode, ctx, &fn);
	if( s ){ napi_throw_error(env, NULL, "BAD: napi_create_function has failed"); return NULL; }
	s = napi_set_named_property(env, exports, "sum", fn);
	if( s ){ napi_throw_error(env, NULL, "BAD: napi_set_named_property(sum)"); return NULL; }
	/**/
	return exports;
}
NAPI_MODULE(NODE_GYP_MODULE_NAME, init)


#ifdef __cplusplus
} /* extern "C" */
#endif
