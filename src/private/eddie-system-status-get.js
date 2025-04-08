;(function(){


const http = require("http");
const sprintf = require("util").format;
const isArray = Array.isArray;
const log = process.stderr;


function parseArgs( app ){
    app.host = "eddie00849"; /*TODO*/
    app.port = 7012; /*TODO*/
    app.requestQueue_tokens = 1; /*TODO*/
}


function assert( expr, msg ){ if( !expr ){ throw Error("assertion failed: "+ msg); } return expr; }


function getListOfServices( app, onDone, onDoneArg ){
    assert(app, "app");  assert(onDone, "onDone");
    var serviceArr;
    var rspBodyChunks = [];
    var onRequestDone;
    requestQueue_push(app, function( onRequestDone_ ){
        onRequestDone = onRequestDone_;
        var req = http.request({
            method: "GET",
            host: assert(app.host, "app.host"),
            port: 7012,
            path: "/eagle/services",
        }, fpQ4AAKgHAACyOgAA);
        req.on("error", console.error.bind(console));
        req.end();
    });
    function fpQ4AAKgHAACyOgAA( rsp ){
        if( rsp.statusCode !== 200 ){ onDone(); throw Error("HTTP "+ rsp.statusCode); }
        rsp.on("data", onRspBodyChunk);
        rsp.on("end", onRspEnd);
    }
    function onRspBodyChunk( chunk ){
        rspBodyChunks.push(chunk);
    }
    function onRspEnd(){
        serviceArr = JSON.parse(rspBodyChunks.join()).services;
        for( var i = 0 ; i < serviceArr.length ; ++i ){
            serviceArr[i] = serviceArr[i].substr(0, serviceArr[i].length-1);
        }
        assert(serviceArr);
        onRequestDone();
        onDone(serviceArr, onDoneArg);
    }
}


function getServiceInfoByServiceNm( app, svcNm, onDone, onDoneArg ){
    assert(svcNm, "svcNm"); assert(onDone, "onDone");
    var path;
    var onRequestDone;
    var componentIds;
    //log.write("getServiceInfoByServiceNm()\n");
    requestQueue_push(app, function( onRequestDone_ ){
        onRequestDone = onRequestDone_;
        var req = http.request({
            method: "GET",
            host: assert(app.host, "app.host"),
            port: assert(app.port, "app.port"),
            path: path = "/eagle/system/status/v1/services/"+ svcNm +"/info",
        }, onRsp);
        req.on("error", console.error.bind(console));
        req.end();
    });
    function onRsp( rsp ){
        if( rsp.statusCode != 200 ){
            onRequestDone();
            onDone(Error("HTTP "+ rsp.statusCode), onDoneArg);
            return;
        }
        rsp.on("data", onRspData);
        rsp.on("end", onRspEnd);
    }
    function onRspData( body ){
        try{
            var info = JSON.parse(body);
        }catch( ex ){
            setTimeout(onRequestDone);
            console.error("svcNm: "+ svcNm);
            throw ex;
        }
        componentIds = info.componentIds;
        assert(isArray(componentIds));
    }
    function onRspEnd(){
        setTimeout(onRequestDone);
        onDone({ componentIds:componentIds }, onDoneArg);
    }
}


function getComponentStatus( app, svcNm, cpmNm, onDone, onDoneArg ){
    assert(app, "app"); assert(svcNm, "svcNm"); assert(cpmNm, "cpmNm"); assert(onDone, "onDone");
    var onRequestDone;
    var rspBodyChunks = [];
    requestQueue_push(app, function( onRequestDone_ ){
        onRequestDone = onRequestDone_;
        var path = "/eagle/system/status/v1/services/"+ svcNm +"/components/"+ cpmNm +"/status";
        //log.write("GET "+ path +"\n");
        var req = http.request({
            method: "GET",
            host: assert(app.host, "app.host"),
            port: assert(app.port, "app.port"),
            path: path,
        }, onRsp);
        req.on("error", console.error.bind(console));
        req.end();
    });
    function onRsp( rsp ){
        if( rsp.statusCode != 200 ){ onRequestDone(); throw Error("HTTP "+ rsp.statusCode); }
        rsp.on("data", onRspData);
        rsp.on("end", onRspEnd);
    }
    function onRspData( chunk ){
        rspBodyChunks.push(chunk);
    }
    function onRspEnd(){
        try{
            var rspJson = JSON.parse(rspBodyChunks.join());
        }catch( ex ){
            setTimeout(onRequestDone);
            console.error("svcNm: "+ svcNm);
            throw ex;
        }
        setTimeout(onRequestDone);
        onDone({ status:rspJson.status, }, onDoneArg);
    }
}


function requestQueue_push( app, task ){
    app.requestQueue.push(task);
    triggerRequestQueueConsumer(app);
}


function triggerRequestQueueConsumer(app){
    while(true){
        if( app.requestQueue_tokens <= 0 ) return;
        var task = app.requestQueue.shift();
        if( !task ) return;
        app.requestQueue_tokens -= 1;
        //log.write("[DEBUG] requestQueue_tokens := "+ app.requestQueue_tokens +"\n");
        setTimeout(task, 0, onTaskDone.bind(0, {nTokens:1}));
    }
    function onTaskDone( ctx ){
        if( ctx.nTokens <= 0 ){ console.warn("MUST NOT CALL onDone MULTIPLE TIMES!!"); return; }
        ctx.nTokens -= 1;
        app.requestQueue_tokens += 1;
        //log.write("[DEBUG] requestQueue_tokens := "+ app.requestQueue_tokens +"\n");
        triggerRequestQueueConsumer(app);
    }
}


function run( app ){
    assert(app);
    //log.write("getListOfServices() ...\n");
    var svcInfo;
    getListOfServices(app, frx8AABZQAAA8XAAA, app);
    function frx8AABZQAAA8XAAA( serviceArr, app ){
        //log.write("getListOfServices() -> [len="+ serviceArr.length +"]\n");
        for( svcNm of serviceArr ){
            if( svcNm == "caveman" ) continue; /* TODO why is caveman rspJson broken? */
            if( svcNm == "fenchurch" ) continue; /* TODO says 404? */
            getServiceInfoByServiceNm(app, svcNm, onServiceInfo, svcNm);
        }
    }
    function onServiceInfo( svcInfo_, svcNm ){
        svcInfo = svcInfo_;
        //log.write("onServiceInfo( "+ svcNm +" )\n");
        if( svcInfo instanceof Error && (svcInfo.message.startsWith("HTTP 404") || svcInfo.message.startsWith("HTTP 503")) ){
            log.write("Ignore "+ svcInfo.message +" for ServiceInfo of '"+ svcNm +"'\n");
            return;
        }
        if( svcInfo instanceof Error ){ throw svcInfo; }
        log.write("SvcStatus: "+ (svcNm +"                ").substring(0, 16) +" OK\n");
        for( cpmNm of svcInfo.componentIds ){
            getComponentStatus(app, svcNm, cpmNm, onComponentStatus, {svcNm:svcNm, cpmNm:cpmNm});
        }
    }
    function onComponentStatus( cpmStatus, cls ){
        var svcNm = cls.svcNm;
        var cpmNm = cls.cpmNm;
        //log.write("onComponentStatus( "+ svcNm +"/"+ cpmNm +" )\n");
        cls = null;
        svcNm = (svcNm +"                ").substring(0, 16);
        cpmNm = (cpmNm +" . . . . . . . . . . . . . . . .").substring(0, 32);
        log.write("CpmStatus: "+ svcNm +" "+ cpmNm +" "+ cpmStatus.status +"\n");
    }
}


function main(){
    var app = Object.seal({
        isHelp: null,
        host: null,
        port: null,
        requestQueue: [],
        requestQueue_tokens: null,
    });
    if( parseArgs(app) ) return;
    if( app.isHelp ){ printHelp(); return; }
    run(app);
}


main();


}());
