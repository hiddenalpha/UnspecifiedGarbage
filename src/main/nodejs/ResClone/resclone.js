;(function(){ "use strict";


const Agent = require("http").Agent;
const N = null;
const URL = require("url").URL;
const assert = require("assert");
const http = require("http");
const isArray = Array.isArray;
const log = process.stderr;

const MODE_PULL = 1;
const MODE_PUSH = 2;


setTimeout(main);


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
        +"          (optional) Path to archive file to read/write. Defaults to\n"
        +"          stdin/stdout.\n"
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
            app.file = argv[++iA];
            if( !app.file ){ dst.write("Arg --file needs value\n"); return -1; }
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
    if( !app.file && !app.isStdio ){
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
    collection.base.on("error", function( ex ){ console.error(ex); });
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
        streamResources(app, rootNode);
    }
}


function streamResources( app, rootNode ){
    const iter = newPreAndPostOrderIterator( app, rootNode );
    for( const holder=[null] ; iter.next(holder) ;){
        const node = holder[0];
        console.log(node.url);
    }
    throw Error("TODO_20230309144518");
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
        const frame = iterCls.stack[iterCls.stack.length - 1];
        if( ! frame ){
            return false; // No more elements. EndOfIteration reached.
        }
        if( frame.currentChild == -1 ){
            // preOrder. Aka publish node itself
            dstArr[0] = frame.node;
            frame.currentChild += 1;
            assert(dstArr[0]);
            return true;
        }
        if( frame.currentChild < frame.node.childNodes.length ){
            // publish next child
            dstArr[0] = frame.node.childNodes[frame.currentChild];
            frame.currentChild += 1;
            assert(dstArr[0]);
            return true;
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

    function newFrame(){
        return Object.seal({
            parentFrame: null,
            /* -1 means preOrder, positive means nth child */
            currentChild: -1,
            node: null,
        });
    }

}());


function main(){
    var app = Object.seal({
        isHelp: false,
        mode: null,
        url: null,
        isStdio: false,
        file: null,
        httpAgent: null,
        numPendingCollectionRequests: 0,
    });
    if( parseArgs(app,process.argv) != 0 ){ process.exit(1); }
    if( app.isHelp ){ printHelp(app); return 0; }
    run(app);
}


}());
