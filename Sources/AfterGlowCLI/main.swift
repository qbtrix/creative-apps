// main.swift: the `afterglow` executable. Everything lives in
// AfterGlowCLICore's CLI.run, which the tests call in process on FakeIO; this
// file only hands it the arguments and LiveIO (the real file system, stdout
// and stderr), then exits with its code. CLIBinaryTests spawns the built
// binary to check the two agree.
import AfterGlowCLICore
import Foundation

let code = CLI.run(Array(CommandLine.arguments.dropFirst()), io: LiveIO())
exit(code)
