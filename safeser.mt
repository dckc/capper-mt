exports (makeUnevaler)

"Safe Serialization Under Mutual Suspicion
http://wiki.erights.org/wiki/Safe_Serialization_Under_Mutual_Suspicion
http://www.erights.org/data/serial/jhu-paper/index.html
"

# Fundamental Data-E Constructs
# as JSON-happy data structures
def Expr
def Literal := Any[Int, Double, Char, Str]
def VarName := Any[Same[null], Same[true], Same[false],
                   Map[Str, Str]] # {"@id": "......" } note: disjoint from tempName
def TempName := Map[Str, Int]  # { "@id": 1}
def Call := Pair[Pair[Expr, Str], Pair[List[Expr], Map[Str, Expr]]]
def DefExpr := Pair[TempName, Expr]
bind Expr := Any[Literal, VarName, TempName, Call, DefExpr]

def NotNull.coerce(specimen, ej) as DeepFrozen:
    if (specimen == null) { throw.eject(ej, null) }
    return null


# deSubgraphKit
def makeUnevaler(uncallerList, scalpelMap :Map[Any, Str]) :Near as DeepFrozen:
    return def unevaler.recognize(root, builder) :(def _Root := builder.getRootType()):
        def Node := builder.getNodeType()
        def uncallers := uncallerList.snapshot()
        def scalpel := scalpelMap.diverge()

        def generate

        def genCall(rec, verb :Str, args :List, nargs :Map[Str, Any]) :Node:
            builder.buildCall(
                generate(rec), verb,
                [for arg in (args) generate(arg)],
                [for name => arg in (nargs) name => generate(arg)])

        def genObject(obj) :Node:
            if (obj =~ _:Literal) { return builder.buildLiteral(obj) }
            for uncaller in (uncallers):
                if (uncaller.optUncall(obj) =~ [rec, verb, args, nargs]):
                    return genCall(rec, verb, args, nargs)
            throw(`Can't uneval ${M.toQuote(obj)}`)

        def genVarUse(varID :Any[Str, Int]) :Node:
            if (varID =~ varName :Str):
                builder.buildImport(varName)
            else:
                builder.buildIbid(varID)

        def generate(obj) :Node:
            if (scalpel.get(obj, fn { null }) =~ varID :NotNull):
                return genVarUse(varID)
            def promIndex :Int := builder.buildPromise()
            scalpel[obj] := promIndex
            def rValue := genObject(obj)
            builder.buildDefrec(promIndex + 1, rValue)

        return builder.buildRoot(generate(root))

