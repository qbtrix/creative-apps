// main.swift: the `afterglow` executable. Everything lives in
// AfterGlowCLICore's CLI.run, which the tests call in process; this file only
// hands it the arguments and the process's stdout and stderr, then exits with
// its code.
import AfterGlowCLICore
import Foundation

let code = CLI.run(
    Array(CommandLine.arguments.dropFirst()),
    out: { print($0) },
    err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
)
exit(code)
