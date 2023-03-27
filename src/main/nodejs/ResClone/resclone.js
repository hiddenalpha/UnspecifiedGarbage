;(function(){ "use strict";


const Agent = require("http").Agent;
const N = null;
const URL = require("url").URL;
const assert = require("assert");
const fs = require("fs");
const http = require("http");
const isArray = Array.isArray;
const isBuffer = Buffer.isBuffer;
const isInteger = Number.isInteger;
const log = process.stderr;

const MODE_PULL = 1;
const MODE_PUSH = 2;


function printHelp( app ){
    process.stdout.write("\n"
        +"  Clone Gateleen subtrees\n"
        +"  \n"
        +"  Options:\n"
        +"  \n"
        +"      --pull / --push\n"
        +"          Choose to download or upload.\n"
        +"  \n"
        +"      --url <url>\n"
        +"          Root node of remote tree.\n"
        +"  \n"
// TODO impl         +"      --filter-part <path-filter>\n"
// TODO impl         +"          Regex pattern applied as predicate to the path starting after\n"
// TODO impl         +"          the path specified in '--url'. Each path segment will be\n"
// TODO impl         +"          handled as its individual pattern. If there are longer paths\n"
// TODO impl         +"          to process, they will be accepted, as long they at least\n"
// TODO impl         +"          start-with specified filter.\n"
// TODO impl         +"          Example:  /foo/[0-9]+/bar\n"
// TODO impl         +"  \n"
// TODO impl         +"      --filter-full <path-filter>\n"
// TODO impl         +"          Nearly same as '--filter-part'. But paths with more segments\n"
// TODO impl         +"          than the pattern, will be rejected.\n"
// TODO impl         +"  \n"
        +"      --stdio\n"
        +"          Use stdio instead of 'file'.\n"
        +"  \n"
        +"      --file <path.tar>\n"
        +"          (optional) Path to archive to read/write.\n"
        +"\n");
}


function parseArgs( app, argv ){
    var dst = process.stdout;
    if( argv.length <= 2 ){ dst.write("Args missing\n"); return -1; }
    for( var iA = 2 ;; ++iA ){
        var arg = argv[iA];
        if( arg === undefined ){
            break;
        }else if( arg == "--help" ){
            app.isHelp = true;
            return 0;
        }else if( arg == "--pull" ){
            if( app.mode != null ){ dst.write("Arg --pull conflict\n"); return -1; }
            app.mode = MODE_PULL;
        }else if( arg == "--push" ){
            if( app.mode != null ){ dst.write("Arg --push conflict\n"); return -1; }
            app.mode = MODE_PUSH;
        }else if( arg == "--url" ){
            app.url = argv[++iA];
            if( !app.url ){ dst.write("Arg --url needs value\n"); return -1; }
        }else if( arg == "--stdio" ){
            app.isStdio = true;
        }else if( arg == "--file" ){
            app.archivePath = argv[++iA];
            if( !app.archivePath ){ dst.write("Arg --file needs value\n"); return -1; }
        }else{
            dst.write("Unexpected arg: "+ arg +"\n");
            return -1;
        }
    }
    if( app.mode != MODE_PULL && app.mode != MODE_PUSH ){
        dst.write("Arg --pull (or --push) missing.\n");
        return -1;
    }
    if( !app.url ){
        dst.write("Arg --url missing.\n");
        return -1;
    }
    if( !app.archivePath && !app.isStdio ){
        dst.write("Arg --stdio or --file missing. Don't know where to keep data.\n");
        return -1;
    }
    return 0;
}


function run( app ){
    assert(app.httpAgent == null);
    app.httpAgent = new Agent({
        keepAlive: true,
        maxSockets: 4, // DON'T kill houston
    });
    const rootNode = newNode();
    rootNode.url = app.url;
    fetchCollection(app, rootNode);
}


function newNode(){
    return Object.seal({
        parentNode: null,
        url: null,
        isLeaf: null,
        childNodes: null,
    });
}


function fetchCollection( app, node ){
    assert(typeof(node.url) == "string", "typeof(node.url) == 'string'");

    app.numPendingCollectionRequests += 1;

    const collection = Object.seal({
        base: null,
        app: app,
        node: node,
        bodyChunks: [],
    });
    log.write("> GET "+ node.url +"\n");
    collection.base = http.get(node.url, {agent:app.httpAgent}, onCollectionResponseHdr.bind(N, collection));
    collection.base.on("error", function( ex ){ throw ex; });
    collection.base.end();
}


function onCollectionResponseHdr( collection, rsp ){
    if( rsp.statusCode != 200 ){
        log.write("< HTTP "+ rsp.statusCode +"\n");
        Object.keys(rsp.headers).forEach(function( key ){
            log.write("< "+ key +": "+ rsp.headers[key] +"\n");
        });
        log.write("< \n");
        return;
    }
    rsp.on("data", onCollectionResponseChunk.bind(N, collection));
    rsp.on("end", onCollectionResponseEnd.bind(N, collection));
}


function onCollectionResponseChunk( collection, buf ){
    collection.bodyChunks.push(buf);
}


function onCollectionResponseEnd( collection ){
    const node = collection.node;
    const app = collection.app;

    // concat whole body and parse it as ONE json
    const bodyBuf = (collection.bodyChunks.length == 1)
        ? collection.bodyChunks[0]
        : Buffer.concat(collection.bodyChunks);
        ;
    collection.bodyChunks = null;
    const body = JSON.parse(bodyBuf);
    assert(collection.childNames == null);
    const childNames = body[Object.keys(body)[0]];
    if( ! isArray(childNames) ){ throw Error("TODO_20230309150005"); }

    // Use listing to setup child nodes
    const childNodes = [];
    childNames.forEach(function( childName ){
        const child = newNode();
        child.parentNode = node;
        child.url = node.url;
        if( !child.url.endsWith('/') ){ child.url += "/"; }
        child.url += childName;
        child.isLeaf = (childName.endsWith("/") == false);
        childNodes.push(child);
    });
    assert(node.childNodes == null);
    node.childNodes = childNodes;

    // Recurse into childs
    node.childNodes.forEach(function( child ){
        if( child.isLeaf !== true ){
            fetchCollection(app, child);
        }
    });

    app.numPendingCollectionRequests -= 1;
    if( app.numPendingCollectionRequests == 0 ){
        var rootNode = node;
        while( rootNode.parentNode != null ){
            rootNode = rootNode.parentNode;
        }
        packResourcesIntoTar(app, rootNode);
    }
}


function packResourcesIntoTar( app, rootNode ){
    if( app.isStdio ){
        onTarArchiveFdOpened(app, rootNode, process.stdout.fd);
    }else{
        fs.open(app.archivePath, "wb", onTarArchiveFdOpened.bind(N, app, rootNode));
    }
}


function onTarArchiveFdOpened( app, rootNode, fd ){
    assert(app.archiveFd === null);
    app.archiveFd = fd;
    const tar = newTarWriter( app, {
        cls: app,
        onChunk: onTarChunk,
        onEnd: onTarEnd,
    });
    // Overcount by one to have the whole process itself covered too. Gets
    // decremented in onTarEnd.
    app.numPendingTarWriteRequests += 1;
    const iter = newPreAndPostOrderIterator(app, rootNode);
    const holder = [null];
    (function loop(){
        while( iter.next(holder) ){
            const node = holder[0];
            if( ! node.isLeaf ){
                continue; // We only care about resources. Collections have no relevance.
            }
            var path = node.url;
            path = path.substring(rootNode.url.length);
            while( path.charAt(0) == "/" ){ path = path.substring(1); }
            assert(path.indexOf("?") === -1);
            tar.writeHdr({
                path: path,
                size: 42, // TODO
            });
        }
        throw Error("TODO_20230309172911");
    }());
}


function onTarChunk( buf, app ){
    app.numPendingTarWriteRequests += 1;
    fs.write(app.archiveFd, buf, function(err, bytesWritten){
        if( --app.numPendingTarWriteRequests == 0 ){
            onTarWritten(app);
        }
    });
}


function onTarEnd( app ){
    if( --app.numPendingTarWriteRequests ){
        onTarWritten(app);
    }
}


function onTarWritten( app ){
    throw Error("TODO_20230309190730");
}


const newPreAndPostOrderIterator = (function(){
    return function ( app, rootNode ){
        const iterCls = Object.seal({
            handle: {},
            stack: [],
        });
        const rootFrame = newFrame();
        rootFrame.node = rootNode;
        iterCls.stack.push(rootFrame);
        Object.defineProperties(iterCls.handle, {

            /* places next element at 'dstArr[0]' and advances state by one element.
             * Returns true on success or false if no more elements. */
            "next": { value: next.bind(N, iterCls) },

        });
        return iterCls.handle;
    }

    function next( iterCls, dstArr ){
        assert(isArray(dstArr));
        while(true){
            const frame = iterCls.stack[iterCls.stack.length - 1];
            if( ! frame ){
                return false; // No more elements. EndOfIteration reached.
            }
            if( frame.node.isLeaf === true ){
                // Just publish ourself as leaf.
                dstArr[0] = frame.node;
                iterCls.stack.pop(); // Prepare next turn
                assert(dstArr[0]);
                return true;
            }
            if( frame.currentChild == -1 ){
                // preOrder. Aka publish node itself
                dstArr[0] = frame.node;
                frame.currentChild += 1;
                assert(dstArr[0]);
                return true;
            }
            if( frame.currentChild < frame.node.childNodes.length ){
                // publish next child (recursively)
                const childFrame = newFrame();
                childFrame.node = frame.node.childNodes[frame.currentChild];
                frame.currentChild += 1;
                iterCls.stack.push(childFrame);
                continue;
            }else{
                // No more childs. Publish postOrder, aka node itself.
                dstArr[0] = frame.node;
                // Then step one level back of our recursion.
                iterCls.stack.pop();
                assert(dstArr[0]);
                return true;
            }
            throw Error("TODO_20230309161935");
        }
    }

    function newFrame(){
        return Object.seal({
            parentFrame: null,
            /* -1 means preOrder, positive means nth child */
            currentChild: -1,
            node: null,
        });
    }

}());


const newTarWriter = (function(){
    return function( app, opts ){
        assert(opts.onChunk);
        const tarCls = Object.seal({
            handle: {},
            remainingBodyBytes: 0,
            bytesToFillForAlignment: 0,
            cb_cls: opts.cls,
            cb_onChunk: opts.onChunk,
            cb_onEnd: opts.onEnd,
        });
        Object.defineProperties(tarCls.handle, {
            "writeHdr": { value: writeHdr.bind(N, tarCls) },
            "writeBodyChunk": { value: writeBodyChunk.bind(N, tarCls) },
            "closeSnk": { value: closeSnk.bind(N, tarCls) },
        });
        return tarCls.handle;
    };

    function writeHdr( tarCls, opts ){
        var tmp;
        const path = opts.path;
        const size = opts.size;
        assert(tarCls.remainingBodyBytes == 0);
        assert(typeof(path) == "string");
        assert(typeof(size) == "number");
        assert(size >= 0 && isInteger(size));
        const path_len = lengthInUtf8Bytes(path);
        assert(path_len <= 100); // TODO use gnu extension to allow longer names.
        const hdr = Buffer.alloc(512, 0);
        hdr.write(path, 0);
        hdr.write("0000644\0", 100, 8); // mode
        hdr.write("0000000\0", 108, 8); // userId
        hdr.write("0000000\0", 116, 8); // groupId
        tmp = ("000000000000"+ size.toString(8)).slice(-11) +"\0";
        hdr.write(tmp, 124, 12); // File size in bytes
        tmp = Math.floor(Date.now() / 1000);
        tmp = ("000000000000"+ tmp.toString(8)).slice(-11) +"\0";
        hdr.write(tmp, 136, 12); // mtime epochSec
        hdr.write(" 0", 155, 2); // Link indicator (0="regular file")
        hdr.write("ustar  \0", 257, 8); // magic
        /* checksum */ {
            tmp = 0;
            for( const byt of hdr ){
                tmp += byt;
            }
            while( tmp >= 0x1FFFF ){ tmp -= 0x1FFFF; } // TODO don't be silly
            tmp = ("0000000"+ tmp).slice(-6) +"\0";
            hdr.write(tmp, 148, 6); // Checksum
        }
        // Align before write header
        fillZeroUpToBlockBoundary(tarCls);
        tarCls.remainingBodyBytes = size;
        tarCls.bytesToFillForAlignment = size;
        while( tarCls.bytesToFillForAlignment >= 512 ){ // TODO don't be silly
            tarCls.bytesToFillForAlignment -= 512;
        }
        publishBuf(tarCls, hdr);
    }

    function writeBodyChunk( tarCls, buf ){
        assert(isBuffer(buf));
        tarCls.remainingBodyBytes -= len;
        assert(tarCls.remainingBodyBytes >= 0);
        publishBuf(tarCls, buf);
    }

    function closeSnk( tarCls ){
        fillZeroUpToBlockBoundary(tarCls);
        for( var i=0 ; i < 2 ; ++i ){
            var zeroBuf = Buffer.alloc(512);
            publishBuf(tarCls, zeroBuf);
        }
        tarCls.cb_onEnd(tarCls.cb_cls);
    }

    function fillZeroUpToBlockBoundary( tarCls ){
        var tmp = tarCls.bytesToFillForAlignment;
        tarCls.bytesToFillForAlignment = 0;
        if( tmp != 0 ){
            const align = Buffer.alloc(tmp);
            tarCls.cb_onChunk(align, tarCls.cb_cls);
        }
    }

    function publishBuf( tarCls, buf ){
        tarCls.cb_onChunk(buf, tarCls.cb_cls);
    }

}());


// Source: https://stackoverflow.com/a/5515960/4415884
function lengthInUtf8Bytes( str ){
    // Matches only the 10.. bytes that are non-initial characters in a multi-byte sequence.
    var m = encodeURIComponent(str).match(/%[89ABab]/g);
    return str.length + (m ? m.length : 0);
}


function main( argv ){
    var app = Object.seal({
        isHelp: false,
        mode: null,
        url: null,
        isStdio: false,
        archivePath: null,
        archiveFd: null,
        httpAgent: null,
        numPendingCollectionRequests: 0,
        numPendingTarWriteRequests: 0,
    });
    if( parseArgs(app, argv) != 0 ){ process.exit(1); }
    if( app.isHelp ){ printHelp(app); return 0; }
    run(app);
}


setTimeout(main, 0, process.argv);

}());
