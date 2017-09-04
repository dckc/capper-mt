# transcribed from elib/tables/makeCycleBreaker.emaker
# Copyright 2003 Hewlett Packard, Inc. under the terms of the MIT X license
# found at http://www.opensource.org/licenses/mit-license.html ................
exports (makeCycleBreaker)

def parts.build() as DeepFrozen {
    def makeTraversalKey := _equalizer.makeTraversalKey

    def makeFlexCycleBreaker
    def makeConstCycleBreaker

    def makeROCycleBreaker(roPMap) :Near {
        return object readOnlyCycleBreaker {

            method diverge()        :Near { makeFlexCycleBreaker(roPMap.diverge()) }
            method snapshot()       :Near { makeConstCycleBreaker(roPMap.snapshot()) }
            # The following implementation technique is only possible because we're
            # using delegation rather than inheritance.
            method readOnly()       :Near { readOnlyCycleBreaker }

            method contains(key)     :Bool { roPMap.contains(makeTraversalKey(key)) }
            method get(key)          :Any { roPMap[makeTraversalKey(key)] }
            method get(key, instead) :Any { roPMap.get(makeTraversalKey(key),instead) }

            method with(key, val) :Near {
                makeConstCycleBreaker(roPMap.with(makeTraversalKey(key), val))
            }
            method without(key) :Near {
                makeConstCycleBreaker(roPMap.without(makeTraversalKey(key)))
            }

            method getPowerMap()    :Near { roPMap.snapshot() }
        }
    }

    bind makeFlexCycleBreaker(flexPMap) :Near {
        # Note that this is just delegation, not inheritance, in that we are not
        # initializing the template with flexCycleBreaker. By the same token,
        # the template makes no reference to <tt>self</tt>.
        return object flexCycleBreaker extends makeROCycleBreaker(flexPMap.snapshot()) {

            to put(key, value)  :Void { flexPMap[makeTraversalKey(key)] := value }

            method getPowerMap()    :Near { flexPMap }

            method removeKey(key)   :Void { flexPMap.removeKey(makeTraversalKey(key)) }
        }
    }

    bind makeConstCycleBreaker(constPMap) :Near {
        return object constCycleBreaker extends makeROCycleBreaker(constPMap.snapshot()) {

            method getPowerMap()    :Near { constPMap.snapshot() }
        }
    }

    def EMPTYConstCycleBreaker := makeConstCycleBreaker([].asMap())
    return [EMPTYConstCycleBreaker]
}

object makeCycleBreaker as DeepFrozen {
    to run() :Near {
        def [EMPTYConstCycleBreaker] := parts.build()
        return EMPTYConstCycleBreaker
    }

    to byInverting(map) :Near {
        def result := makeCycleBreaker().diverge()
        for key => value in (map) {
            result[value] := key
        }
        return result.snapshot()
    }
}
