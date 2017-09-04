import "deSubGraphKit" =~ [=>deSubGraphKit :DeepFrozen]
import "deJSONKit" =~ [=>deJSONKit :DeepFrozen]
exports (main)

def main(_argv) :Vow[Int] as DeepFrozen:
    def x := [1, x, 3]
    traceln(x)
    def jb := deJSONKit.makeBuilder()
    traceln(deSubGraphKit.recognize(x, jb))
    return 0
