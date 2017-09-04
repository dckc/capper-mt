# transcribed from elib/tables/makeCycleBreaker.emaker
# Copyright 2003 Hewlett Packard, Inc. under the terms of the MIT X license
# found at http://www.opensource.org/licenses/mit-license.html ................
exports (makeCycleBreaker)

def makeTraversalKey :DeepFrozen := _equalizer.makeTraversalKey

object it as DeepFrozen {

    to makeROCycleBreaker(roPMap) :Near {
        return object readOnlyCycleBreaker {

            method diverge()        :Near { it.makeFlexCycleBreaker(roPMap.diverge()) }
            method snapshot()       :Near { it.makeConstCycleBreaker(roPMap.snapshot()) }
            # The following implementation technique is only possible because we're
            # using delegation rather than inheritance.
            method readOnly()       :Near { readOnlyCycleBreaker }

            method contains(key)     :Bool { roPMap.contains(makeTraversalKey(key)) }
            method get(key)          :Any { roPMap[makeTraversalKey(key)] }
            method fetch(key, instead) :Any { roPMap.fetch(makeTraversalKey(key),instead) }

            method with(key, val) :Near {
                it.makeConstCycleBreaker(roPMap.with(makeTraversalKey(key), val))
            }
            method without(key) :Near {
                it.makeConstCycleBreaker(roPMap.without(makeTraversalKey(key)))
            }

            method getPowerMap()    :Near { roPMap.snapshot() }
        }
    }

    to makeFlexCycleBreaker(flexPMap) :Near {
        # Note that this is just delegation, not inheritance, in that we are not
        # initializing the template with flexCycleBreaker. By the same token,
        # the template makes no reference to <tt>self</tt>.
        return object flexCycleBreaker extends it.makeROCycleBreaker(flexPMap.snapshot()) {

            to put(key, value)  :Void { flexPMap[makeTraversalKey(key)] := value }

            method getPowerMap()    :Near { flexPMap }

            method removeKey(key)   :Void { flexPMap.removeKey(makeTraversalKey(key)) }
        }
    }

    to makeConstCycleBreaker(constPMap) :Near {
        return object constCycleBreaker extends it.makeROCycleBreaker(constPMap.snapshot()) {

            method getPowerMap()    :Near { constPMap.snapshot() }
        }
    }

    to EMPTYConstCycleBreaker() { return it.makeConstCycleBreaker([].asMap()) }
}

object makeCycleBreaker as DeepFrozen {
    to run() :Near {
        return it.EMPTYConstCycleBreaker()
    }

    to byInverting(map) :Near {
        def result := makeCycleBreaker().diverge()
        for key => value in (map) {
            result[value] := key
        }
        return result.snapshot()
    }
}
