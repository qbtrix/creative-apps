// BodyCountSuites.swift: the one parent for every suite that reads a
// process-global DEBUG body-run counter (HaloWindow.bodyRuns,
// TimelineLane.bodyRuns, PhotoEditor.bodyRuns, ...). Those counters are static,
// so two such suites running at once count each other's renders (one run saw
// 49 window bodies where 24 is right). `.serialized` on a suite orders only its
// own tests and nested suites; separate `.serialized` suites still run in
// parallel with each other, so these suites nest here with `extension
// BodyCountSuites`, and a new counter-reading suite must do the same.
import Testing

@Suite(.serialized) enum BodyCountSuites {}
