;(function(){ "use-strict";

    const child_process = require("child_process");
    const fs = require("fs");
    const promisify = require("util").promisify;
    const zlib = require("zlib");
    const noop = function(){};
    const log = process.stderr;
    const logAsString = function( buf ){ log.write(buf.toString()); };

    setImmediate(main);


    function printHelp( argv, app ){
        process.stdout.write("  \n"
            +"  Autmoate some steps that are tedious manually.\n"
            +"  \n"
            +"  Options:\n"
            +"  \n"
            +"    --default\n"
            +"      Perform default action (whatever default means).\n"
            +"  \n"
            +"    --print-isaVersion\n"
            +"      Print a preflux isaVersion to stdout filled with the patched\n"
            +"      services.\n"
            +"  \n"
            +"    --reset-hard-to-develop\n"
            +"      Resets all the services back to develop. WARN if you've uncommitted\n"
            +"      work in some of those repos, IT WILL BE LOST!\n"
            +"  \n"
            +"    --push | --push-force\n"
            +"      Create commits for patched services and push them to upstream. If\n"
            +"      not given, the change is only made locally (aka without cluttering\n"
            +"      remote git repo). The force variant will replace existing branches\n"
            +"      on the remnote. If given multiple times, less-invasive wins.\n"
            +"  \n"
            // not impl yet
            //+"    --max-parallel <int>\n"
            //+"      How many tasks to run concurrently. Defaults to 1. Which means to\n"
            //+"      do all the work sequentially (HINT: very handy for debugging).\n"
            //+"  \n"
        );
    }


    function parseArgs( argv, app ){
        var hasArgs = false;
        for( var iA = 2 ; iA < argv.length ; ++iA ){
            var arg = argv[iA];
            if( arg == "--help" ){
                app.isHelp = true; return 0;
            }else if( arg == "--default" ){
                hasArgs = true;
            }else if( arg == "--push" ){
                if( app.isPushForce ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPush = true;
                hasArgs = true;
            }else if( arg == "--push-force" ){
                if( app.isPush ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPushForce = true;
                hasArgs = true;
            }else if( arg == "--print-isaVersion" ){
                app.isPrintIsaVersion = true;
                hasArgs = true;
            }else if( arg == "--reset-hard-to-develop" ){
                app.isResetHardToDevelop = true;
                hasArgs = true;
            //}else if( arg == "--max-parallel" ){
            //    arg = argv[++iA];
            //    if( !/^[0-9]+$/.test(arg) ){ log.write("EINVAL: --max-parallel "+ arg +"\n"); return -1; }
            //    app.maxParallel = 0 + arg;
            }else{
                log.write("EINVAL: "+ arg +"\n");
                return -1;
            }
        }
        if( !hasArgs ){
            log.write("EINVAL: Refuse to produce damage with zero args.\n");
            return -1;
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
        return "https://example.com/scm/isa/"+ thingyName +".git";
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
            +"tVnNcuMoEL7nKbTXzUKc2WRmQk1tZav2Ppd9AYRaEgoCCpBj79NvI0u2E9uJxUg+CJDpr4Fu+k+F"
            +"LMuMkEqGjN9Z0/o7D24tBdxZLj0nw4j4zoLD/+McumlVlk+ZfSN1AZssL+9L8fj9cUXpt+JhxfFR"
            +"Zver1deHhxtCyLQV3Nze3k5cxfNzRp5W9398f8puY/ste36+yT77/birDFf+rytmCqNLWXWOB2n0"
            +"FQQ9kXUG1xkkIAtyFUmk8kq2fyNVyUWYQhh/3FiulORaADvq//iNkH9//vOTZRrW4LJCOhBBbbPO"
            +"Q5FJnVnFQ2lcS8hEhqKm1vhAZaC9iChXMvJWvZgGce0ODxsHC6AXpuVSL4WOMhTg/VLwylSV1Iud"
            +"zSvkCdDGVZR7iyrSsKF9BY6K0+uR49rLINcw6k++zbx1cRe7yX6yFp1h6MKCSotWo+Q+gEPbwYTi"
            +"3rc8wMXd1TIHp3EGWePxFjwYl8RTG1DSeOrABwWBnXlHYRNolB72L66naaWWm6WWMDvbg6Iit9Zo"
            +"GjWS7fq9dpIWAsdj5ZP3gwie5MB1F6Ty7OTNAkfYMxCmAMHejFKBlEKtRqfi2Zl3aaClVNBZZXjB"
            +"Tl+lQUrDDt00CMV1xY4HiTA7i8nejWcFI9zK2QHZ0xNdobcCT7QJBDbSh2lMNNoHX1KoBRc1sKFN"
            +"MPAj0H+tcbZmQzv3ZYlWfW866d50sjPm9FeAG77mG4qBlscDhRj5HBg0lpMv9H66PHuPZOPx0joE"
            +"i+K0RoMOnvVDJbE/K2Kak76I18p2ajxx7BTxUMWLH031MCBco+LyNMP0GXZCAPQ5aPQpOWYocwBH"
            +"rLC1b8HjC9J49+f96nJsVEOhjHhJuj9VDE5K6WuKoRzbqTqoaTgj1Z58+nXYUR7kz96/SLKY1Hea"
            +"YpYj1yPoC3eBH71KWWUUWhQ6wm3y9HW9hUlTz1Mc2dqJ0ota0OTGezr6ln40epZFg9bI26vyoWGN"
            +"UMRgFE764XKheb/b3t2wXTNRA0zBSUDbx/a9JM/YxAuuJN64obNELF4ZUymgMXqkJWpI3lWeRWOy"
            +"epwGJg2tZKi7vPeFBIWOa0QkPzEoPRJ3p0gw54U9i4wHzzUocWyRa/9MzVcvAyY5/zFBOur3uRkK"
            +"3wgZtksES2d4XmRzJnFL4GmQl1kw4RsqExj8DuleeoD9AWjMl9E0zYPpt+j5W+LRr3V+3nVimuuk"
            +"mAkTheSIgwqDXpfqgs/hrqGWQqFi6Rdizet851pzBwUap7Ws5lzvESDezDmRY1kRE4pYQCUmj0qW"
            +"iH6wq/0zEaAvsZWOt/Bq3AsbS27GflaVw8ixXYs053+B6a7ONxterNdcrtUctjHnHoRB4W4SkriP"
            +"8eK3CWvcnLgp7vACGGwsOgs/ObL+ADLA1DLGB2Ao4zmxUO1TMoghYI4pyaH7SzWEMWpgn4YP0OZQ"
            +"FGgom3YT4oTEEHpHTEc4doKbvJehtLUvcVlj1JcF9xND8igX4bo293RMp9k+r97Je2bQtKJa3inV"
            +"47Yo52LLDt3Ee9w4g8kj2zXTU4xQm66qQ7wWnm4wUgDesqGd8Eny7t03ydurKd8SngBdyf74Q+qV"
            +"fE3nBFw5O/4wMUer3RsAqjGhigVz+vvN/wsTxCQ="
        ;
        patch = Buffer.from(patch, 'base64');
        patch = zlib.inflateRaw(patch, function( ex, patch ){
            if( ex ){ throw ex; }
            setImmediate(onDone, null, patch);
        });
    }


    function getJettyServiceNamesAsArray( app, onDone ){
        setImmediate(onDone, null, [ /*TODO get via args/file */
            "allitnil", "babelfish", "barman",
            //"benjy", "bentstick", "blart", "captain", "caveman",
            //"colin", "deep", "drdan", "guide", "heimdall", "hooli", "jeltz", "kwaltz", "lazlar",
            //"loon", "magician", "megacamel", "minetti", "mown", "neutron", "nowwhat", "pobble",
            //"poodoo", "prosser", "rob", "slarti", "streetmentioner", "thor", "towel", "trillian",
            //"vannharl", "vogon", "vroom", "zaphake", "zem",
        ]);
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
                "git", ["add", "Jenkinsfile"],
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
                    for( var buf in stdoutBufs ){ stdoutStr += buf.toString(); }
                    if( stdoutStr.length ){ log.write(stdoutStr); }
                    endFn(Error("code="+ code +", signal="+ signal +""));
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


    function setPlatformVersionInService( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        updateParent();
        function updateParent(){
            log.write("[DEBUG] "+ thingyName +" - Set platform version "+ app.platformSnapVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:update-parent", "-DparentVersion="+ app.platformSnapVersion],
                { cwd: workdirOfSync(app, jettyService) },
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
            log.write("[DEBUG] "+ thingyName +" - Set parent.version "+ app.platformSnapVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:set-property", "-Dproperty=parent.version", "-DnewVersion="+ app.platformSnapVersion],
                { cwd: workdirOfSync(app, jettyService) },
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
            child.on("close", function(){
                nextJettyService();
            });
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
            gitApply.stdin.write(patch);
            gitApply.stdin.end();
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


    function forEachJettyService( app, onService, onDone ){
        var iSvc = 0, services;
        var isOnDoneCalled = false;
        getJettyServiceNamesAsArray(app, onServicesArrived);
        function onServicesArrived( ex, ret ){
            if( ex ) throw ex;
            services = ret;
            nextService();
        }
        function nextService( ex ){
            if( ex ){ endFn(ex); return; }
            var service = services[iSvc++];
            if( service === undefined ){ endFn(); return; }
            onService(app, service, nextService);
        }
        function endFn( ex, ret ){
            if( isOnDoneCalled ){
                throw (ex) ? ex : Error("onDone MUST be called ONCE only");
            }else{
                isOnDoneCalled = true;
                onDone(ex, ret);
            }
        }
    }


    function resetHardToDevelop( app, thingyName, onDone ){
        if( typeof onDone !== "function" ) throw Error("onDone");
        var iRemoteName = 0;
        tryResetHard(iRemoteName++);
        function tryResetHard( i ){
            var remoteName = app.remoteNamesToTry[i];
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
                    tryResetHard(iRemoteName++);
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


    function run( app ){
        if( app.isResetHardToDevelop ){
            forEachJettyService(app, resetHardToDevelop, endFn);
            return;
        }
        updateFromRemote();
        function updateFromRemote( ex ){
            if( ex ) throw ex;
            forEachJettyService(app, fetchChangesFromGitit,
                onFetchChangesFromGititForAllJettyServicesDone);
        }
        function onFetchChangesFromGititForAllJettyServicesDone( ex ){
            if( ex ) throw ex;
            forEachJettyService(app, checkoutUpstreamDevelop,
                onCheckoutUpstreamDevelopDone);
        }
        function onCheckoutUpstreamDevelopDone( ex ){
            if( ex ) throw ex;
            patchAwaySlimPackagingInPlatform(app, onPatchAwaySlimPackagingInPlatformDone);
        }
        function onPatchAwaySlimPackagingInPlatformDone( ex, ret ){
            if( ex ) throw ex;
            setVersionInPlatform(app, onSetVersionInPlatformDone);
        }
        function onSetVersionInPlatformDone(){
            dropSlimFromAllJenkinsfiles(app, onDropSlimFromAllJenkinsfilesDone);
        }
        function onDropSlimFromAllJenkinsfilesDone( ex ){
            if( ex ) throw ex;
            forEachJettyService(app, setPlatformVersionInService, onSetPlatformVersionInServiceDone);
        }
        function onSetPlatformVersionInServiceDone( ex ){
            if( ex ) throw ex;
            if( app.isPush || app.isPushForce ){
                commitAllServices(app, onCommitAllServicesDone);
            }else{
                log.write("[DEBUG] Skip commit/push (disabled)\n");
                endFn();
            }
        }
        function onCommitAllServicesDone( ex ){
            if( ex ) throw ex;
            if( !app.isPush && !app.isPushForce ) throw Error("assert(isPush || isPushForce)");
            forEachJettyService(app, pushService, endFn);
        }
        function endFn( ex ){
            if( ex ) throw ex;
            log.write("[INFO ] App done\n");
        }
    }


    function main(){
        const app = {
            isHelp: false,
            isPrintIsaVersion: false,
            isPush: false,
            isPushForce: false,
            isResetHardToDevelop: false,
            remoteNamesToTry: ["origin"],
            platformSnapVersion: null,
            workdir: "C:/work/tmp/git-scripted",
            maxParallel:  1,
            numRunningTasks: 0,
            branchName: "SDCISA-15648-RemoveSlimPackaging-n1",
            commitMsg: "[SDCISA-15648] Remove slim packaging",
        };
        app.platformSnapVersion = "0.0.0-"+ app.branchName +"-SNAPSHOT";
        if( parseArgs(process.argv, app) !== 0 ){ process.exit(1); }
        if( app.isHelp ){ printHelp(); return; }
        run(app);
    }


}());
