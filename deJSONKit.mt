import "DEBuilderOf" =~ [=> DEBuilderOf :DeepFrozen]
exports (deJSONKit)

object deJSONKit as DeepFrozen {
    to makeBuilder() {
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


        var nextTemp :Int := 0
        var varReused := [].diverge()

        object deJSONBuilder implements DEBuilderOf[Expr, Expr] {
            method getNodeType() :Near { Expr }
            method getRootType() :Near { Expr }
        }
    }

    to recognize() {
    }
}
