import "lib/json" =~ [=> JSON :DeepFrozen]
import "lib/monte/monte_lexer" =~ [=> makeMonteLexer :DeepFrozen]
import "lib/monte/monte_parser" =~ [=> parseModule :DeepFrozen]
import "lib/monte/monte_expander" =~ [=> expand :DeepFrozen]
exports (makeSaver, makeUnique, makeReviver)


def load(code :Str, name: Str, badCode,
         =>package := null, # umm...
         =>scope := safeScope) as DeepFrozen:
    traceln(`loading $name`)
    # traceln(code)
    def tokens := makeMonteLexer(code, name)
    def ast := expand(parseModule(tokens, astBuilder, badCode),
                      astBuilder, badCode)
    # traceln(`app $name AST: $ast`)
    def moduleBody := eval(ast, scope)
    def moduleExports := moduleBody(package)
    # traceln(`app $name module: $module`)
    return moduleExports


def makeReviver(appDir) as DeepFrozen:
    return object reviver:
        to toMaker(name):
            return when (def code := (appDir / "apps" / name / "server.mt").getText()) ->
                def [=> make :DeepFrozen] | _ := load(code, name, throw)
                make

        to sendUI(_res, _reviver, _path):
            throw("not implemented but get off my back about the SMOs")

def makeUnique(nextInt) as DeepFrozen:
    def chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    return def unique() :Str:
        return "".join([for _ in (1..25) chars[nextInt(chars.size())].asString()])

def SimpleData :DeepFrozen := Any[Void, Bool, Int, Double, Str]

object JSONData as DeepFrozen:
    to coerce(specimen, ej):
        escape notSimple:
            return SimpleData.coerce(specimen, notSimple)
        escape notJDList:
            return List[JSONData].coerce(specimen, notJDList)
        escape notJDMap:
            return Map[Str, JSONData].coerce(specimen, notJDMap)
        throw.eject(ej, "not JSON Data")

    to supersetOf(g):
        if (g == JSONData):
            return true
        if (Any.extractGuards(SimpleData, throw).contains(g)):
            return true
        escape notList:
            def itemGuard := List.extractGuard(g, notList)
            return JSONData.supersetOf(itemGuard)
        escape notStrMap:
            def [==Str, itemGuard] exit notStrMap := Map.extractGuards(g, notStrMap)
            return JSONData.supersetOf(itemGuard)
        return false


def Cred :DeepFrozen := Str
def Key :DeepFrozen := Map[Str, Cred]  # ["@id" => cred]
def ModuleName :DeepFrozen := Str
def Verb :DeepFrozen := Str
def Reviver :DeepFrozen := Pair[ModuleName, NullOk[Verb]]

def newQ(v) as DeepFrozen:
    def [p, r] := Ref.promise()
    r.resolve(v)
    return p
    
def makeSaver(unique, dbfile, reviverToMaker) as DeepFrozen:
    var modifiedObjs :Set[Cred] := [].asSet()
    def checkpoint
    def live

    # see Capper/blob/master/saver.js#L31-L54
    var lastCheckpointQueued :Vow[Bool] := newQ(true)
    var checkpointNeeded :Bool := false
    def checkpointIfNeeded():
        if (checkpointNeeded):
            checkpoint()
    def setupCheckpoint():
        if (!checkpointNeeded):
            checkpointNeeded := true
            checkpointIfNeeded <- ()

    def credToId(cred :Cred) :Key {return ["@id" => cred ]}
    def idToCred(id :Key, =>FAIL) :Cred {return id.fetch("@id", FAIL)}

    var sysState :Map[Cred, Pair[JSONData, Reviver]] := [].asMap()
    def loadSysState():
        return when (def jsonState := dbfile.getText()) ->
            sysState := JSON.decode(jsonState, throw)
        catch `@_msg(ENOENT)`:
            when(dbfile.setContents(b`{}`)) ->
                sysState := [].asMap()
    loadSysState()  #@@TODO: when(loadSysState()) ->
    def validStateObj

    bind checkpoint():
        def [promise, resolver] := Ref.promise()
        for next in (modifiedObjs):
            try:
                checkpointNeeded := true
                def [initState, revive] := sysState[next]
                def state := validStateObj(initState)
                if (!state):
                    traceln(`!!!ERROR bad function in checkpoint for object of type $revive`)
            catch err:
                trace("missing cred in modifiedObjs, probably dropped from the table: ")
                traceln.exception(err)

        modifiedObjs := [].asSet()
        if (!checkpointNeeded):
            resolver.resolve(lastCheckpointQueued)
        else:
            checkpointNeeded := false
            # force sequentiality on multiple pending checkpoints
            var last := lastCheckpointQueued
            lastCheckpointQueued := promise
            when (last) ->
                def jsonState := JSON.encode(sysState)
                checkpointNeeded := false # yes, say it again on each turn

                return when(dbfile.writeText(jsonState)) ->
                    resolver.resolve(true)
                catch err:
                    trace("checkpoint failed: ")
                    traceln.exception()
                    resolver.reject(err)

                    when (def [=> size] | _ := dbfile.stat()) ->
                        traceln(`db size after write: $size`)

        return promise

    var liveState :Map[Cred, Any] := [].asMap()

    var liveToId :Map[Near, Key] := [].asMap()
    def asId(ref):
        def id := liveToId.fetch(ref, fn { throw("asId bad ref") })
        return id
    bind validStateObj(obj :Near):
        if (obj == null) { return null }
        escape notLive:
            return liveToId.fetch(obj, notLive)
        escape notData:
            def [rx, verb :Str, args :List, namedArgs :Map[Str, Any]] exit notData := obj._uncall()
            # TODO@@?? add makers (rx) to liveToId
            return [validStateObj(rx), verb,
                    [for nextval in (args) validStateObj(nextval)],
                    [for name => nextval in (namedArgs) name => validStateObj(nextval)]]
        catch whyNot:
            trace(`!!!ERROR found non-data, non-live object in validStateObj $obj:`)
            traceln.exception(whyNot)
    def drop(id :Key):
        setupCheckpoint()
        def cred := idToCred(id)
        if (liveState[cred]) { liveToId without= (liveState[cred]) }
        liveState without= (cred)
        sysState without= (cred)

    def makePersister(id: Key):
        def cred := idToCred(id)
        def [data, constructorLocation] := sysState[cred]
        #does modify in place converting ids to live objs; impossible complications
        # when making a copy, context.state.array[3] = 5 cannot update state
        def convertForExport(thing):
            if (thing =~ _ :SimpleData) {return thing;}
            if (liveToId.contains(thing)) {return thing;}
            if (idToCred(thing)) {return live(thing);}
            for next in (thing):
                def replacement := convertForExport(thing[next]);
                if (thing[next] != replacement) {thing[next] := replacement;}

            return thing;

        # var p = new Proxy({}, ...
        return "@@p";

    def State(id :Key):
        return makePersister(id)

    def makeContext(id :Key) :DeepFrozen:
        def cred := idToCred(id)
        return object context as DeepFrozen:
            to drop():
                drop(id)
            to make():
                throw("not yet implemented")

            to slot(init, =>guard :DeepFrozen := JSONData):
                if (!DeepFrozen.supersetOf(guard)):
                    throw(`persistence requires JSONData.supersetOf($guard)`)
                var contents :guard := init
                return object persistentSlot:
                    to get() :guard:
                        return contents
                    to put(v :guard):
                        setupCheckpoint()
                        modifiedObjs with= (cred)
                        traceln(`@@slot of $id set to $v`)
                        contents := v
    return object saver:
        to make(makerLocation):
            #@@ , _optInitArgs
            # setupCheckpoint();
            def cred := unique()
            def newId := credToId(cred)
            # sysState[cred] = {data: {}, reviver: makerLocation};
            def newContext := makeContext(newId)
            return when (def maker := reviverToMaker(makerLocation)) ->
                def obj := maker(newContext)
                #liveState[cred] = obj;
                # liveToId.set(obj, newId);

                #var initArgs = [];
                #for (var i = 1; i <arguments.length; i++) {initArgs.push(arguments[i]);}
                #if ("init" in obj) {obj.init.apply(undefined, initArgs);}
                obj

        to deliver(_id, _verb, _optArgs):
            throw("Not implemented")
