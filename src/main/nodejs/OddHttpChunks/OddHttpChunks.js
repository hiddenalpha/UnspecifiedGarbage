;(function(){
    "use static";

    const MGET_CONTENT_CHUNK = 0x15;
    const MGET_CONTENT_TYPE = 0x0B;
    const MGET_EOF = 0x1B;
    const MGET_PATH = 0x01;
    const N = null;
    const assert = console.assert;
    const createConnection = require("net").createConnection;
    const createServer = require("http").createServer;
    const isBuffer = Buffer.isBuffer;
    const log = process.stderr;
    const out = process.stdout;


    function printHelp(){
        out.write("\n"
            +"  Send unluckily splitted multiget responses.\n"
            +"\n"
            +"  Options:\n"
            +"\n"
            +"    --host <str>\n"
            +"        Where to listen for nsync requests. Default 'localhost'.\n"
            +"\n"
            +"    --port <int>\n"
            +"        Server port to listen on. Default '8080'.\n"
            +"\n"
            +"\n");
    }


    function parseArgs( app, argv ){
        // defaults
        app.listenHost = "127.0.0.1";
        app.listenPort = 8080;
        //
        for( var iArg=2 ; iArg < argv.length ; ++iArg ){
            var arg = argv[iArg];
            if( !arg ){
                break;
            }else if( arg == "--help" ){
                app.isHelp = true;
                return 0;
            }else if( arg == "--host" ){
                arg = argv[++iArg];
                if( !arg ){ log.write("Arg --host needs value\n"); return -1; }
                app.listenHost = arg;
            }else if( arg == "--port" ){
                arg = argv[++iArg];
                if( isNaN(arg) ){ log.write("Arg --port needs integer value\n"); return -1; }
                app.listenPort = arg;
            }else{
                log.write("Bad arg: "+ arg +"\n");
                return -1;
            }
        }
        if( !app.listenHost ){ log.write("Arg --host missing\n"); return -1; }
        if( !app.listenPort ){ log.write("Arg --port missing\n"); return -1; }
        return 0;
    }


    function run( app ){
        app.server = createServer();
        app.server.on("request", onServerIncomingHttpRequest.bind(N, app));
        app.server.listen(app.listenPort, app.listenHost, onServerReady.bind(N, app));
    }


    function onServerReady( app ){
        log.write("Listening on "+ app.listenHost +":"+ app.listenPort +"\n");
    }


    function onServerIncomingHttpRequest( app, req, rsp ){
        log.write("< "+ req.method +" "+ req.url +"\n");
        var iBuf = 0;
        var chunk;
        var buf = Buffer.alloc(256);
        // first resource
        buf.writeUInt8(MGET_PATH, iBuf++);
        buf.writeUInt8(7, iBuf++);
        buf.write("/my/one", iBuf); iBuf += 7;
        buf.writeUInt8(MGET_CONTENT_CHUNK, iBuf++);
        buf.writeUInt8(7, iBuf++);
        buf.write("ABCDEFG", iBuf); iBuf += 7;
        // 2nd resource
        buf.writeUInt8(MGET_PATH, iBuf++);
        buf.writeUInt8(7, iBuf++);
        buf.write("/my/two", iBuf); iBuf += 7;
        buf.writeUInt8(MGET_CONTENT_CHUNK, iBuf++);
        buf.writeUInt8(9, iBuf++);
        buf.write("HIJKLMNOP", iBuf); iBuf += 9;
        //
        var sock = rsp.socket;
        sock.write("HTTP/1.1 200 OK\r\n"
            +"Content-Type: application/multiget-response\r\n"
            +"Content-Length: "+ iBuf +"\r\n"
            +"\r\n");
        // But now we ensure that resources are split unluckily in middle of
        // content chunk. This increases probability that the internal buffers
        // binally arriving in our client application are split in a similar
        // way.
        var splitOne = 14;
        var splitTwo = 34;
        var delayMs = 100;
        sock.write(buf.slice(0, splitOne));
        setTimeout(function(){
            sock.write(buf.slice(splitOne, splitTwo));
        }, delayMs);
        setTimeout(function(){
            sock.write(buf.slice(splitTwo, iBuf));
        }, 2*delayMs);
    }


    const newMultigetEncoder = (function(){
        return function( opts ){
            const mGetEnc = {
                buf: Buffer.alloc(130),
                remainBodyLen: 0,
                cb_cls: opts.cls,
                cb_onChunk: opts.onChunk,
                cb_onFlush: opts.onFlush,
            };
            return Object.defineProperties({}, {
                "writePathFull": { value: onWritePathFull.bind(N, mGetEnc) },
                "beginContent": { value: onBeginContent.bind(N, mGetEnc) },
                "writeBodyChunk": { value: onWriteBodyChunk.bind(N, mGetEnc) },
                "flush": { value: function(){ mGetEnc.cb_onFlush(mGetEnc.cb_cls); } },
            });
        };
        function onWritePathFull( mGetEnc, path ){
            assert(mGetEnc.remainBodyLen === 0);
            var pathBuf = Buffer.from(path, "UTF-8");
            assert(pathBuf.length < 127);
            var buf = Buffer.alloc(2 + pathBuf.length);
            buf.writeUInt8(MGET_PATH, 0);
            buf.writeUInt8(pathBuf.length, 1);
            pathBuf.copy(buf, 2);
            mGetEnc.cb_onChunk(buf, mGetEnc.cb_cls);
        }
        function onBeginContent( mGetEnc, body_len ){
            assert(!isNaN(body_len));
            var num_len;
            assert(body_len < 127); /*not impl yet*/
            var buf = Buffer.alloc(2);
            buf.writeUInt8(MGET_CONTENT_CHUNK, 0);
            buf.writeUInt8(body_len, 1);
            mGetEnc.remainBodyLen = body_len;
            mGetEnc.cb_onChunk(buf, mGetEnc.cb_cls);
        }
        function onWriteBodyChunk( mGetEnc, buf ){
            assert(isBuffer(buf));
            mGetEnc.remainBodyLen -= buf.length;
            assert(mGetEnc.remainBodyLen >= 0);
            mGetEnc.cb_onChunk(buf, mGetEnc.cb_cls);
        }
    }());


    //function sendSyncRegistration( app ){
    //}


    function main(){
        const app = {
            isHelp: false,
            listenHost: null,
            listenPort: null,
            sock: null,
            server: null,
        };
        if( parseArgs(app, process.argv) != 0 ){ process.exit(1); }
        if( app.isHelp ){ printHelp(app); process.exit(0); }
        run(app);
    }


    setTimeout(main);

}());
