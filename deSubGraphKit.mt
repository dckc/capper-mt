import "makeCycleBreaker" =~ [=>makeCycleBreaker :DeepFrozen]
import "notnull" =~ [=>NotNull :DeepFrozen]
import "makeUncaller" =~ [=>makeUncaller :DeepFrozen, =>Uncaller :DeepFrozen]
import "DEBuilderOf" =~ [=> DEBuilderOf :DeepFrozen]
exports (makeUnevaler, deSubgraphKit)

# Copyright 2003 Hewlett Packard, Inc. under the terms of the MIT X license
# found at http://www.opensource.org/licenses/mit-license.html ................

"Safe Serialization Under Mutual Suspicion
http://wiki.erights.org/wiki/Safe_Serialization_Under_Mutual_Suspicion
http://www.erights.org/data/serial/jhu-paper/index.html
"

# See comment on getMinimalScope() below.
def minimalScope :DeepFrozen := [
    "null"              => null,
    "false"             => false,
    "true"              => true,
    "NaN"               => NaN,
    "Infinity"          => Infinity,
    "_makeList"        => _makeList,
#    "__identityFunc"    => __identityFunc,
    "_makeInt"         => _makeInt,
]

def defaultScope :DeepFrozen := minimalScope
def minimalScalpel :DeepFrozen := makeCycleBreaker.byInverting(minimalScope)
def defaultScalpel :DeepFrozen := minimalScalpel

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
            if (obj =~ _:Any[Int, Double, Char, Str]) { return builder.buildLiteral(obj) }
            for uncaller in (uncallers):
                if (uncaller.optUncall(obj) =~ [rec, verb, args, nargs]):
                    return genCall(rec, verb, args, nargs)
            throw(`Can't uneval ${M.toQuote(obj)}`)

        def genVarUse(varID :Any[Str, Int]) :Node:
            if (varID =~ varName :Str):
                builder.buildImport(varName)
            else:
                builder.buildIbid(varID)

        bind generate(obj) :Node:
            if (scalpel.get(obj, fn { null }) =~ varID :NotNull):
                return genVarUse(varID)
            def promIndex :Int := builder.buildPromise()
            scalpel[obj] := promIndex
            def rValue := genObject(obj)
            builder.buildDefrec(promIndex + 1, rValue)

        return builder.buildRoot(generate(root))

def defaultUncallers := makeUncaller.getDefaultUncallers()
def defaultRecognizer := makeUnevaler(defaultUncallers, defaultScalpel)

# /**
#  * Unserializes/evals by building a subgraph of objects, or serializes/unevals
#  * by recognizing/traversing a subgraph of objects.
#  *
#  * @author Mark S. Miller
#  */
object deSubgraphKit {

    # /**
    #  * This is the default scope used for recognizing/serializing/unevaling and
    #  * for building/unserializing/evaling.
    #  * <p>
    #  * The minimal scope only has bindings for<ul>
    #  * <li>the scalars which can't be written literally<ul>
    #  *     <li><tt>null</tt>
    #  *     <li><tt>false</tt>
    #  *     <li><tt>true</tt>
    #  *     <li>floating point <tt>NaN</tt>. Same as 0.0/0.0
    #  *     <li>floating point <tt>Infinity</tt>. Same as 1.0/0.0.
    #  *     </ul>
    #  *     The additional scalars which can't be written literally are the
    #  *     negative numbers, including negative infinity. The can instead be
    #  *     expressed by a unary "-" or by calling ".negate()" on the magnitude.
    #  * <li><tt>__makeList</tt>. Many things are built from lists.
    #  * <li><tt>__identityFunc</tt>. Enables the equivalent of JOSS's
    #  *     <tt>{@link java.io.ObjectOutputStream#replaceObject
    #  *                replaceObject()}</tt>
    #  * <li><tt>__makeInt</tt>. So large integers (as used by crypto) can print
    #  *     in base64 by using <tt>__makeInt.fromString64("...")</tt>.
    #  * <li><tt>import__uriGetter</tt>. Used to name safe constructor / makers
    #  *     of behaviors.
    #  * </ul>
    #  */
    method getMinimalScope() :Near { minimalScope }

    # /**
    #  * XXX For now, it's the same as the minimalScope, but we expect to add
    #  * more bindings from the safeScope; possibly all of them.
    #  */
    method getDefaultScope() :Near { defaultScope }

    method getMinimalScalpel() :Near { minimalScalpel }

    # /**
    #  * XXX For now, it's the same as the minimalScalpel, but we expect to add
    #  * more bindings from the safeScope; possibly all of them.
    #  */
    method getDefaultScalpel() :Near { defaultScalpel }

    method getDefaultUncallers() :List[Uncaller] { defaultUncallers }

    # /**
    #  * Makes a builder which evaluates a Data-E tree in the default scope to a
    #  * value.
    #  *
    #  * @see #getMinimalScope
    #  */
    method makeBuilder() :Near {
        deSubgraphKit.makeBuilder(defaultScope)
    }

    # /**
    #  * Makes a builder which evaluates a Data-E tree in a scope to a value.
    #  * <p>
    #  * This <i>is</i> Data-E Unserialization. It is also a subset of E
    #  * evaluation.
    #  */
    method makeBuilder(scope) :Near {

        # The index of the next temp variable
        var nextTemp := 0

        # The frame of temp variables
        def temps := [].diverge()

        def Node := Any
        def Root := Any

        object deSubgraphBuilder implements DEBuilderOf[Node, Root] {
            method getNodeType() :Near { Node }
            method getRootType() :Near { Root }

            method buildRoot(root :Node)        :Root { root }
            method buildLiteral(value)          :Node { value }
            method buildImport(varName :Str) :Node { scope[varName] }
            method buildIbid(tempIndex :Int)    :Node { temps[tempIndex] }

            method buildCall(rec :Node, verb :Str, args :List[Node], nargs :Map[Str, Node]) :Node {
                M.call(rec, verb, args, nargs)
            }

            method buildDefine(rValue :Node) :Pair[Node, Int] {
                def tempIndex := nextTemp
                nextTemp += 1
                temps[tempIndex] := rValue
                [rValue, tempIndex]
            }

            method buildPromise() :Int {
                def promIndex := nextTemp
                nextTemp += 2
                def [prom,res] := Ref.promise()
                temps[promIndex] := prom
                temps[promIndex+1] := res
                promIndex
            }

            method buildDefrec(resIndex :Int, rValue :Node) :Node {
                temps[resIndex].resolve(rValue)
                rValue
            }
        }
    }

    method getDefaultRecognizer() :Near { defaultRecognizer }

    method makeRecognizer(optUncallers, optScalpel) :Near {
        def uncallers := if (null == optUncallers) {
            defaultUncallers
        } else {
            optUncallers
        }
        def scalpel := if (null == optScalpel) {
            defaultScalpel
        } else {
            optScalpel
        }
        makeUnevaler(uncallers, scalpel)
    }

    # /**
    #  * Uses the default recognizer
    #  */
    method recognize(root, builder) :(def _Root := builder.getRootType()) {
        defaultRecognizer.recognize(root, builder)
    }
}


# porting notes:
#  - docstrings: comment-region
#  - guards
#      any -> Any
#      nullOk -> NullOk
#      notNull -> NotNull (imported)
#      G[] --> List[G]
#  - implicit return: to -> method
#  - def -> object
