/*

Related:
- [Remove Slim Packaging](SDCISA-15648)

*/
;(function(){ "use-strict";

    const child_process = require("child_process");
    const fs = require("fs");
    const promisify = require("util").promisify;
    const zlib = require("zlib");
    const noop = function(){};
    const log = process.stderr;
    const out = process.stdout;
    const logAsString = function( buf ){ log.write(buf.toString()); };

    setImmediate(main);


    function printHelp( argv, app ){
        process.stdout.write("  \n"
            +"  Autmoate some steps that are tedious manually.\n"
            +"  \n"
            +"  Options:\n"
            +"  \n"
            +"    --fetch\n"
            +"      Update local repos from remote.\n"
            +"  \n"
            +"    --reset-hard\n"
            +"      Reset worktree to develop.\n"
            +"  \n"
            +"    --patch-platform\n"
            +"      Remove slim packaging from patform and set snapshot version.\n"
            +"  \n"
            +"    --patch-services\n"
            +"      Disable slim packaging in Jenkinsfile and use platform snapshot in\n"
            +"      pom.\n"
            +"  \n"
            +"    --commit\n"
            +"      Create a git commit with our changes.\n"
            +"  \n"
            +"    --push | --push-force\n"
            +"      Create commits for patched services and push them to upstream. If\n"
            +"      not given, the change is only made locally (aka without cluttering\n"
            +"      remote git repo). The force variant will replace existing branches\n"
            +"      on the remnote. If given multiple times, less-invasive wins.\n"
            +"  \n"
            +"    --print-isa-version\n"
            +"      Prints an isaVersion JSON that can be fed to preflux.\n"
            +"  \n"
            // not impl yet
            //+"    --max-parallel <int>\n"
            //+"      How many tasks to run concurrently. Defaults to 1. Which means to\n"
            //+"      do all the work sequentially (HINT: very handy for debugging).\n"
            //+"  \n"
        );
    }


    function parseArgs( argv, app ){
        if( argv.length <= 2 ){
            log.write("EINVAL: Refuse to produce damage with zero args.\n");
            return -1;
        }
        for( var iA = 2 ; iA < argv.length ; ++iA ){
            var arg = argv[iA];
            if( arg == "--help" ){
                app.isHelp = true; return 0;
            }else if( arg == "--fetch" ){
                app.isFetch = true;
            }else if( arg == "--reset-hard" ){
                app.isResetHard = true;
            }else if( arg == "--patch-platform" ){
                app.isPatchPlatform = true;
            }else if( arg == "--patch-services" ){
                app.isPatchServices = true;
            }else if( arg == "--commit" ){
                app.isCommit = true;
            }else if( arg == "--push" ){
                if( app.isPushForce ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPush = true;
            }else if( arg == "--push-force" ){
                if( app.isPush ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPushForce = true;
            }else if( arg == "--print-isa-version" ){
                app.isPrintIsaVersion = true;
            //}else if( arg == "--max-parallel" ){
            //    arg = argv[++iA];
            //    if( !/^[0-9]+$/.test(arg) ){ log.write("EINVAL: --max-parallel "+ arg +"\n"); return -1; }
            //    app.maxParallel = 0 + arg;
            }else{
                log.write("EINVAL: "+ arg +"\n");
                return -1;
            }
        }
        return 0;
    }


    function isThingyNameValid( app, thingyName ){
        if( typeof thingyName !== "string" ) return false;
        if( !/^[a-z-]+$/.test(thingyName) ) return false;
        return true;
    }


    function workdirOfSync( app, thingyName ){
        if( !isThingyNameValid(app, thingyName) ) throw TypeError(thingyName);
        return app.workdir +"/"+ thingyName;
    }


    function gitUrlOfSync( app, thingyName ){
        if( !isThingyNameValid(app, thingyName) ) throw TypeError(thingyName);
        return "https://gitit.post.ch/scm/isa/"+ thingyName +".git";
    }


    function isCloned( app, thingyName, onDone){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var child = child_process.spawn(
            "git", ["status", "--porcelain"],
            { cwd: workdirOfSync(app, thingyName), }
        );
        child.on("error", console.error.bind(console));
        child.stdout.on("data", noop);
        child.stderr.on("data", logAsString);
        child.on("close", function( code, signal ){
            if( code !== 0 || signal !== null ){
                onDone(Error("code "+ code +", signal "+ signal));
            }else{
                onDone(null, true);
            }
        });
    }


    function isWorktreeClean( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var isStdoutDirty = false;
        var child = child_process.spawn(
            "git", ["status", "--porcelain"],
            { cwd: workdirOfSync(app, thingyName), }
        );
        child.on("error", console.error.bind(console));
        child.stdout.on("data", function(){ isStdoutDirty = true; });
        child.stderr.on("data", logAsString);
        child.on("close", function( code, signal ){
            if( signal !== null ){
                throw Error("code "+ code +", signal "+ signal +"");
            }else{
                onDone(null, !isStdoutDirty);
            }
        });
    }


    function getDropSlimArtifactsTagInPlatformPatch( app, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        /* patch which empties the <slimArtifacts> tag in
         * "poms/service/paisa-service-superpom/pom.xml" as described in
         * SDCISA-15648 */
        var patch = ""
            +"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"
        ;
        patch = Buffer.from(patch, 'base64');
        patch = zlib.inflateRaw(patch, function( ex, patch ){
            if( ex ){ throw ex; }
            setImmediate(onDone, null, patch);
        });
    }


    function getJettyServiceNamesAsArray( app, onDone ){
        setImmediate(onDone, null, [ /*TODO get via args/file */
            TODO_GX0CAJ9hAgCNRAIA9hgCAP5jAgDGCgIA
        ]);
    }


    function getVersionByServiceName(app, svcName, onDone){
        /* if we did patch services, we already know the version without
         * lookup. This is a performance optimization, because maven performs
         * absolutely terrible. Performance DOES matter! */
        //if( app.isPatchServices ){
            setImmediate(onDone, null, app.jenkinsSnapVersion);
        //}else{
        //    wasteOurTimeBecausePerformanceDoesNotMatter();
        //}
        //function wasteOurTimeBecausePerformanceDoesNotMatter( ex ){
        //    if( ex ) throw ex;
        //    var stdoutBufs = [];
        //    /* SHOULD start maven with low prio to not kill windoof. But I
        //     * guess spawning a process with other prio is YAGNI, and so we're
        //     * now fucked. Therefore I wish you happy time-wasting, as the only
        //     * option left is to NOT start too many maven childs
        //     * simultaneously. */
        //    var child = child_process.spawn(
        //        "mvn", ["help:evaluate", "-o", "-q", "-DforceStdout", "-Dexpression=project.version"],
        //        { cwd:workdirOfSync(app, svcName) }
        //    );
        //    child.on("error", console.error.bind(console));
        //    child.stderr.on("data", logAsString);
        //    child.stdout.on("data", stdoutBufs.push.bind(stdoutBufs));
        //    child.on("close", function( code, signal ){
        //        if( code !== 0 || signal !== null ){
        //            endFn(Error("code="+ code +", signal="+ signal +""));
        //            return;
        //        }
        //        if( stdoutBufs.length <= 0 ) throw Error("maven has failed");
        //        var version = stdoutBufs.join().trim();
        //        onDone(null, version);
        //    });
        //}
    }


    function printIsaVersion( app, onDone ){
        var iSvcQuery = 0, iSvcPrinted = 0;
        printIntro();
        function printIntro( ex ){
            if( ex ) throw ex;
            var epochMs = Date.now();
            out.write('{\n');
            out.write('  "timestamp": "'+ new Date().toISOString() +'",\n');
            out.write('  "isaVersionId": "SDCISA-15648-'+ epochMs +'",\n');
            out.write('  "isaVersionName": "SDCISA-15648-'+ epochMs +'",\n');
            out.write('  "trial": true,\n');
            out.write('  "services": [\n');
            out.write('    { "name": "eagle", "version": "02.23.01.00" },\n');
            out.write('    { "name": "storage", "version": "00.25.00.02" },\n');
            out.write('    { "name": "platform", "version": "'+ app.platformJenkinsVersion +'" }');
            /* maven performance is an absolute terrible monster.
             * Problem 1: Doing this sequentially takes forever.
             * Problem 2: Doing this parallel for all makes windoof freeze.
             * Workaround: Do at most a few of them in parallel. */
            for( var i = 3 ; i ; --i ) nextService();
        }
        function nextService( ex ){
            if( ex ) throw ex;
            if( iSvcQuery >= app.services.length ){ /*printTail();*/ return; }
            var svcName = app.services[iSvcQuery++];
            getVersionByServiceName(app, svcName, function(e,r){ printService(e,r,svcName); });
        }
        function printService( ex, svcVersion, svcName ){
            if( ex ) throw ex;
            if( typeof svcVersion != "string") throw Error(svcVersion);
            iSvcPrinted += 1;
            out.write(",\n    ");
            out.write('{ "name": "'+ svcName +'", "version": "'+ svcVersion +'" }');
            if( iSvcPrinted >= app.services.length ){ printTail(); }else{ nextService(); }
        }
        function printTail( ex ){
            if( ex ) throw ex;
            out.write('\n');
            out.write('  ],\n');
            out.write('  "featureSwitches": [],\n');
            out.write('  "mergedBundles": []\n');
            out.write('}\n');
            onDone(/*ex*/null, /*ret*/null);
        }
    }


    function pushService( app, thingyName, onDone ){
        if( typeof onDone != "function" ){ throw TypeError("onDone"); }
        var iRemoteNameToTry = 0;
        push();
        function push( ex, isClean ){
            if( ex ) throw ex;
            var remoteName = app.remoteNamesToTry[iRemoteNameToTry++];
            if( remoteName === undefined ){ endFn(Error("No more remote names. s="+ thingyName +"")); return; }
            log.write("[DEBUG] "+ thingyName +" - git push "+ remoteName +" "
                + app.branchName +(app.isPushForce?" --force":"")+"\n");
            argv = ["push", remoteName, "refs/heads/"+app.branchName +":refs/heads/"+ app.branchName];
            if( app.isPushForce ) argv.push("--force");
            var child = child_process.spawn(
                "git", argv,
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code === 128 ){ /* retry with next upstream name */
                    push(); return;
                }else if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                endFn();
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function commitService( app, thingyName, onDone ){
        if( typeof onDone != "function" ){ throw Error("onDone"); }
        incrNumTasks(app);
        isWorktreeClean(app, thingyName, gitAdd);
        function gitAdd( ex, isClean ){
            if( ex ) throw ex;
            if( isClean ){
                log.write("[INFO ] Nothing to commit in \""+ thingyName +"\"\n");
                endFn(null, null); return;
            }
            log.write("[DEBUG] "+ thingyName +"$ git add Jenkinsfile\n");
            var child = child_process.spawn(
                "git", ["add", "--", "."],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                gitCommit();
            });
        }
        function gitCommit( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git commit -m \""+ app.commitMsg +"\"\n");
            var child = child_process.spawn(
                "git", ["commit", "-m", app.commitMsg],
                { cwd:workdirOfSync(app, thingyName) }
            );
            var stdoutBufs = [];
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.stdout.on("data", function( buf ){ stdoutBufs.push(buf); });
            child.on("exit", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    var stdoutStr = "";
                    for( var buf in stdoutBufs ){ log.write(buf.toString()); }
                    endFn(Error("code="+ code +", signal="+ signal));
                    return;
                }
                createBranch(); return;
            });
        }
        function createBranch( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git branch "+ app.branchName +"\n");
            var child = child_process.spawn(
                "git", ["branch", "-f", app.branchName],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("exit", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                endFn(); return;
            });
        }
        function endFn( ex, ret ){
            decrNumTasks(app);
            onDone(ex, ret);
        }
    }


    function commitAllServices( app, onDone ){
        var iSvc = 0;
        var services;
        incrNumTasks(app);
        getJettyServiceNamesAsArray(app, onGetJettyServiceNamesAsArrayDone);
        function onGetJettyServiceNamesAsArrayDone( ex, ret ){
            if( ex ) throw ex;
            services = ret;
            nextService(null);
        }
        function nextService( ex ){
            if( ex ) throw ex;
            if( iSvc >= services.length ){ endFn(null); return; }
            var thingyName = services[iSvc++];
            if( !thingyName ) throw Error("assert(thingyName != NULL)");
            commitService(app, thingyName, nextService);
        }
        function endFn( ex ){
            decrNumTasks(app);
            if( ex ) throw ex;
            log.write("[DEBUG] No more services to commit\n");
            onDone(null, null);
        }
    }


    function giveServiceOurSpecialVersion( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        doit();
        function doit( ex ){
            if( ex ) throw ex;
            var child = child_process.spawn(
                "mvn", ["versions:set", "-DgenerateBackupPoms=false", "-DallowSnapshots=true",
                    "-DnewVersion="+ app.serviceSnapVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                onDone();
            });
        }
    }


    function setPlatformVersionInService( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        updateParent();
        function updateParent(){
            log.write("[DEBUG] "+ thingyName +" - Set platform version "+ app.parentVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:update-parent", "-DgenerateBackupPoms=false", "-DallowDowngrade=true",
                    "-DallowSnapshots=true", "-DforceUpdate=true", "-DskipResolution=true",
                    "-DparentVersion="+app.parentVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                updateProperty();
            });
        }
        function updateProperty( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +" - Set parent.version "+ app.parentVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:set-property", "-DgenerateBackupPoms=false", "-DallowSnapshots=true",
                    "-Dproperty=platform.version", "-DnewVersion="+ app.parentVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                onDone();
            });
        }
    }


    function dropSlimFromAllJenkinsfiles( app, onDone ){
        var iSvc = -1;
        var jettyServices;
        var jettyService;
        incrNumTasks(app);
        getJettyServiceNamesAsArray(app, function( ex, jettyServices_ ){
            if( ex ) throw ex;
            jettyServices = jettyServices_;
            nextJettyService();
        });
        function nextJettyService( ex ){
            decrNumTasks(app);
            if( ex ) throw ex;
            if( ++iSvc >= jettyServices.length ){ onNoMoreJettyServices(); return; }
            incrNumTasks(app);
            jettyService = jettyServices[iSvc];
            isWorktreeClean(app, jettyService, onIsWorktreeCleanRsp);
        }
        function onIsWorktreeCleanRsp( ex, isClean ){
            if( ex ) throw ex;
            if( !isClean ){
                log.write("[WARN ] Wont patch: Worktree not clean: "+ jettyService +"\n");
                nextJettyService();
                return;
            }
            log.write("[DEBUG] Patching \""+ jettyService +"/Jenkinsfile\"\n");
            var child = child_process.spawn(
                "sed", [ "-i", "-E", "s_^(.*?buildMaven.*?),? *slim: *true,? *(.*?)$_\\1\\2_", "Jenkinsfile" ],
                { cwd: workdirOfSync(app, jettyService) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", removeEmptyArray);
        }
        /* Pipeline is too dump for an empty array */
        function removeEmptyArray( ex ){
            if( ex ) throw ex;
            var child = child_process.spawn(
                "sed", [ "-i", "-E", "s_^(.*?).buildMaven\\(\\[\\]\\))(.*?)$_\\1\\2_", "Jenkinsfile" ],
                { cwd: workdirOfSync(app, jettyService) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", nextJettyService);
        }
        function onNoMoreJettyServices(){
            onDone(null, null);
        }
    }


    function checkoutUpstreamDevelop( app, thingyName, onDone){
        var iRemoteName = 0;
        checkout();
        function checkout(){
            var remoteName = app.remoteNamesToTry[iRemoteName];
            if( remoteName === undefined ){ onDone(Error("No more remote names for "+ thingyName)); return; }
            log.write("[DEBUG] git checkout "+ thingyName +" "+ remoteName +"/develop\n");
            var child = child_process.spawn(
                "git", ["checkout", remoteName+"/develop"],
                { cwd: workdirOfSync(app, thingyName), });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( !"TODO_GlACAIQoAgDMTwIAIh8CAOJvAgALLgIA" ){
                    checkout(); /* try next remote name */
                }else if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    onDone(null, null);
                }
            });
        }
    }


    function fetchChangesFromGitit( app, thingyName, onDone ){
        var child;
        var iRemoteName = 0;
        mkAppWorkdir();
        function mkAppWorkdir( ex ){
            if( ex ) throw ex;
            fs.mkdir(app.workdir, {recursive:true}, checkRepoExists);
        }
        function checkRepoExists( ex ){
            if( ex ) throw ex;
            fs.exists(workdirOfSync(app, thingyName) +"/.git", function( isLocalCloneExists ){
                isLocalCloneExists ? fetch() : clone();
            });
        }
        function clone( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] git clone "+ thingyName +"\n");
            var child = child_process.spawn(
                "git", ["clone", "--no-single-branch", "--depth", "4", gitUrlOfSync(app, thingyName)],
                { cwd: app.workdir });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal)); return;
                }
                onDone(null, null);
            });
        }
        function fetch( ex ){
            if( ex ) throw ex;
            var remoteName = app.remoteNamesToTry[iRemoteName++];
            if( remoteName === undefined ){
                onDone(Error("No more remotes to try for "+ thingyName)); return; }
            log.write("[DEBUG] "+ thingyName +" - git fetch "+ remoteName +"\n");
            var child = child_process.spawn(
                "git", ["fetch", remoteName],
                { cwd: workdirOfSync(app, thingyName), });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal)); return;
                }
                onDone(null, null);
            });
        }
    }


    function setVersionInPlatform( app, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        setVersion();
        function setVersion(){
            log.write("[DEBUG] platform - mvn versions:set "+ app.platformSnapVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:set", "-DgenerateBackupPoms=false", "-DnewVersion="+app.platformSnapVersion],
                { cwd: workdirOfSync(app, "platform"), }
            );
            child.on("error", console.error.bind(console));
            child.stdout.on("data", noop);
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code "+ code +", signal "+ signal));
                    return;
                }
                endFn();
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function patchAwaySlimPackagingInPlatform( app, onDone ){
        var onDoneCalledNTimes = 0;
        incrNumTasks(app);
        isWorktreeClean(app, "platform", function( ex, isClean ){
            if( ex ) throw ex;
            if( !isClean ){ log.write("[WARN ] Skip platform patch: Worktree not clean\n");
                endFn(); return; }
            getDropSlimArtifactsTagInPlatformPatch(app, onPatchBufReady);
        });
        function onPatchBufReady( ex, patch ){
            if( ex ) throw ex;
            var stdoutBufs = [];
            var gitApply = child_process.spawn(
                "git", ["apply"],
                { cwd: workdirOfSync(app, "platform"), });
            gitApply.on("error", console.error.bind(console));
            gitApply.stderr.on("data", logAsString);
            gitApply.stdout.on("data", stdoutBufs.push.bind(stdoutBufs));
            gitApply.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    for( var buf in stdoutBufs ){ log.write(buf.toString()); }
                    throw Error(""+ code +", "+ signal +"");
                }
                endFn(null, null);
            });
            setTimeout/*TODO why?*/(function(){
                gitApply.stdin.write(patch);
                gitApply.stdin.end();
            }, 42);
        }
        function endFn( ex, ret ){
            if( onDoneCalledNTimes !== 0 ){ throw Error("assert(onDoneCalledNTimes == 0)"); }
            onDoneCalledNTimes += 1;
            decrNumTasks(app);
            onDone(ex, ret);
        }
    }


    function incrNumTasks( app ){
        //if( app.numRunningTasks >= app.maxParallel ){
        //    throw Error("assert(app.numRunningTasks < app.maxParallel)");
        //}
        app.numRunningTasks += 1;
    }


    function decrNumTasks( app ){
        if( app.numRunningTasks <= 0 ) throw Error("assert(app.numRunningTasks > 0)");
        app.numRunningTasks -= 1;
    }


    function forEachInArrayDo( app, array, onService, onDone ){
        var iE = 0;
        var isOnDoneCalled = false;
        nextElem();
        function nextElem( ex ){
            if( ex ){ endFn(ex); return; }
            if( iE >= array.length ){ endFn(); return; }
            onService(app, array[iE++], nextElem);
        }
        function endFn( ex ){
            if( isOnDoneCalled ){
                throw (ex) ? ex : Error("onDone MUST be called ONCE only");
            }else{
                isOnDoneCalled = true;
                onDone(ex);
            }
        }
    }


    function forEachJettyService( app, onService, onDone ){
        getJettyServiceNamesAsArray(app, onServicesArrived);
        function onServicesArrived( ex, services ){
            if( ex ) throw ex;
            forEachInArrayDo(app, services, onService, onDone);
        }
    }


    function resetHardToDevelop( app, thingyName, onDone ){
        var iRemoteName = 0;
        if( typeof onDone !== "function" ) throw Error("onDone");
        detach();
        function detach(){
            log.write("[DEBUG] "+ thingyName +"$ git checkout --detach\n");
            var child = child_process.spawn(
                "git", ["checkout", "--detach"],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    tryResetHard();
                }
            });
        }
        function tryResetHard(){
            var remoteName = app.remoteNamesToTry[iRemoteName++];
            if( remoteName === undefined ){ onDone(Error("no usable remote found")); return; }
            log.write("[DEBUG] "+ thingyName +"$ git reset --hard "+ remoteName +"/develop\n");
            var child = child_process.spawn(
                "git", ["reset", "--hard", remoteName +"/develop"],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else if( code !== 0 ){
                    tryResetHard(); /*try next remoteName*/
                }else{
                    wipeWorktree();
                }
            });
        }
        function wipeWorktree(){
            log.write("[DEBUG] "+ thingyName +"$ git rimraf\n");
            var child = child_process.spawn(
                "git", ["rimraf"/*TODO make portable*/],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    deleteBranch();
                }
            });
        }
        function deleteBranch( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git branch --delete --force "+ app.branchName +"\n");
            var child = child_process.spawn(
                "git", ["branch", "--delete", "--force", app.branchName],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code == 1 ){ /* assume branch doesnt exist*/
                    log.write("[INFO ] Ignore: Failed to delete branch '"+ app.branchName +"' in '"
                        + thingyName +"'.\n");
                    endFn(null, null);
                }else if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    endFn(null, null);
                }
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function setPlatformVersionInAllServices( app, onDone ){
        forEachJettyService(app, setPlatformVersionInService, onDone);
    }


    function fetchRemoteChanges( app, onDone ){
        var platformAndServices = app.services.slice(0);
        platformAndServices.unshift("platform");
        forEachInArrayDo(app, platformAndServices, fetchChangesFromGitit, onDone);
    }


    function fetchListOfServices( app, onDone ){
        getJettyServiceNamesAsArray(app, function( ex, ret ){
            if( ex ) throw ex;
            app.services = ret;
            onDone();
        });
    }


    function run( app ){
        var actions = [ fetchListOfServices ];
        if( app.isFetch ){ actions.push(fetchRemoteChanges); }
        if( app.isResetHard ){
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, checkoutUpstreamDevelop, onDone);
            });
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, resetHardToDevelop, onDone);
            });
        }
        if( app.isPatchPlatform ){
            actions.push(patchAwaySlimPackagingInPlatform);
            actions.push(setVersionInPlatform);
        }
        if( app.isPatchServices ){
            actions.push(dropSlimFromAllJenkinsfiles);
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, giveServiceOurSpecialVersion, onDone);
            });
        }
        if( app.isCommit ) actions.push(function( app, onDone ){
            forEachInArrayDo(app, app.services, commitService, onDone);
        });
        if( app.isPush || app.isPushForce ){
            actions.push(function( app, onDone ){
                forEachJettyService(app, pushService, onDone);
            });
        }
        if( app.isPrintIsaVersion ){ actions.push(printIsaVersion); }
        actions.push(function( app, onDone ){
            log.write("[INFO ] App done\n");
        });
        triggerNextAction();
        function triggerNextAction( ex ){
            if( ex ) throw ex;
            var action = actions.shift();
            if( action === undefined ){ endFn(); return; }
            action(app, triggerNextAction);
        }
    }


    function main(){
        const app = {
            isHelp: false,
            isFetch: false,
            isResetHard: false,
            isPatchPlatform: false,
            isPatchServices: false,
            iscommit: false,
            isPush: false,
            isPushForce: false,
            isPrintIsaVersion: false,
            remoteNamesToTry: ["origin"],
            workdir: "C:/work/tmp/git-scripted",
            maxParallel:  1,
            numRunningTasks: 0,
            services: null,
            branchName: "SDCISA-15648-RemoveSlimPackaging-n1",
            commitMsg: "[SDCISA-15648] Remove slim packaging",
            platformSnapVersion: "0.0.0-SNAPSHOT",
            serviceSnapVersion: "0.0.0-SNAPSHOT",
            platformJenkinsVersion: "0.0.0-SDCISA-15648-RemoveSlimPackaging-n1-SNAPSHOT",
            jenkinsSnapVersion: "0.0.0-SDCISA-15648-RemoveSlimPackaging-n1-SNAPSHOT",
            parentVersion: null,
        };
        app.parentVersion = "0.0.0-"+ app.branchName +"-SNAPSHOT";
        if( parseArgs(process.argv, app) !== 0 ){ process.exit(1); }
        if( app.isHelp ){ printHelp(); return; }
        run(app);
    }


}());
