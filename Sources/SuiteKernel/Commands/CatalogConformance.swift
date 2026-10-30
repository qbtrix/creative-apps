// CatalogConformance.swift (command-catalog CC-1 stub, CC-8 body): the laws every app's catalog keeps.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One law a catalog keeps. A problem reads "<command id>: <law>: <what happened>".
public enum CatalogLaw: String, CaseIterable, Sendable {
    case idRule, removedIsRetired, retiredNeverReused, describeRoundTrips, exampleValidates, exampleRuns
    case refusalChangesNothing, queryOrViewChangesNoBytes, editRecordsOneStep, stepNamedTitle, undoRestoresBytes, redoRestoresBytes
    /// The problem `id` has under this law.
    func problem(_ id: String, _ detail: String) -> String { "\(id): \(rawValue): \(detail)" }
}

/// The conformance suite any `HeadlessDocument`'s catalog runs.
public enum CatalogConformance {
    /// The history commands: view commands that move the history (or close a request span), so they may change save()
    /// bytes by design. They are exempt from the query-and-view law, and on a fixture with nothing to undo (or no
    /// request) their refused example is fine;
    /// each edit's undo and redo checks them instead.
    public static let historyIDs: Set<String> = ["edit.undo", "edit.redo", "history.end", "history.undo-request"]

    /// The id rule, the same as `CommandCatalog`'s (CC-7): 1 to 64 characters of a-z, 0-9, "." and "-", starting
    /// with a letter, with no empty dot-separated part. Digits are allowed anywhere after the first character.
    private static func isValidID(_ id: String) -> Bool {
        guard let first = id.first, first.isASCII, first.isLowercase, id.count <= 64 else { return false }
        return id.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isWholeNumber || $0 == "." || $0 == "-") }
            && !id.split(separator: ".", omittingEmptySubsequences: false).contains { $0.isEmpty }
    }

    /// Every spec of D's catalog on `fixture`: the example validates and runs, an edit records one step named
    /// its title and "edit.undo" restores save() bytes, query and view leave save() bytes equal, a refusal changes
    /// nothing, describe round trips through JSON. Returns the problems, empty when it conforms.
    public static func check<D: HeadlessDocument>(_ type: D.Type, fixture: D) -> [String] {
        let catalog = D.catalog
        return catalog.ids.flatMap { id in catalog.spec(id).map { laws(of: $0, in: catalog, fixture: fixture) } ?? [] }
    }

    /// The problems one spec has on `fixture`.
    static func laws<D: HeadlessDocument>(of spec: CommandSpec<D>, in catalog: CommandCatalog<D>, fixture: D) -> [String] {
        let id = spec.id
        var problems = [String]()
        if !isValidID(id) {
            problems.append(CatalogLaw.idRule.problem(id, "use 1 to 64 characters of a-z, 0-9, \".\" and \"-\", starting with a letter, with no empty dotted part"))
        }
        problems += describes(id, in: catalog)
        problems += refusal(id, in: catalog, fixture: fixture)
        let issues = spec.params.validate(spec.example)
        guard issues.isEmpty else {
            let why = issues.map { "\($0.path.isEmpty ? "/" : $0.path) \($0.message)" }.joined(separator: "; ")
            return problems + [CatalogLaw.exampleValidates.problem(id, "the example fails its params schema: \(why)")]
        }
        let before = try? fixture.save()
        var doc = fixture
        do {
            _ = try catalog.run(id, params: spec.example, on: &doc)
        } catch {
            if historyIDs.contains(id), case .unavailable(_, _) = error { return problems }
            return problems + [CatalogLaw.exampleRuns.problem(id, "the example refused on the fixture: \(error)")]
        }
        switch spec.kind {
        case .query, .view where !historyIDs.contains(id):
            if (try? doc.save()) != before {
                problems.append(CatalogLaw.queryOrViewChangesNoBytes.problem(id, "a \(spec.kind.rawValue) command changed the save() bytes"))
            }
        case .edit: problems += edit(spec, in: catalog, fixture: fixture, before: before, after: doc)
        default: break
        }
        return problems
    }

    /// An edit's laws: one step more than the fixture, named its title; undo gives back the bytes, redo the edit's.
    static func edit<D: HeadlessDocument>(_ spec: CommandSpec<D>, in catalog: CommandCatalog<D>, fixture: D, before: Data?, after doc: D) -> [String] {
        let id = spec.id
        var problems = [String]()
        let name = catalog.history(doc).undoName
        if name != spec.title {
            problems.append(CatalogLaw.stepNamedTitle.problem(id, "its undo step reads \(name.map { "\"\($0)\"" } ?? "nothing"), not \"\(spec.title)\""))
        }
        guard catalog.spec("edit.undo") != nil else {
            return problems + [CatalogLaw.undoRestoresBytes.problem(id, "the catalog has no edit.undo to take it back")]
        }
        let steps = depth(doc, in: catalog) - depth(fixture, in: catalog)
        if steps != 1 { problems.append(CatalogLaw.editRecordsOneStep.problem(id, "it recorded \(steps) undo steps, not one")) }
        var undone = doc
        do { _ = try catalog.run("edit.undo", params: .object([:]), on: &undone) } catch {
            return problems + [CatalogLaw.undoRestoresBytes.problem(id, "edit.undo refused after it: \(error)")]
        }
        if (try? undone.save()) != before {
            problems.append(CatalogLaw.undoRestoresBytes.problem(id, "edit.undo after it leaves save() bytes unlike those before it"))
        }
        guard catalog.spec("edit.redo") != nil else { return problems }
        var redone = undone
        let redid = (try? catalog.run("edit.redo", params: .object([:]), on: &redone)) != nil
        if !redid || (try? redone.save()) != (try? doc.save()) {
            problems.append(CatalogLaw.redoRestoresBytes.problem(id, "edit.redo after its undo does not give back the bytes it saved"))
        }
        return problems
    }

    /// How many times "edit.undo" runs on `doc` before it refuses, at most 1000.
    static func depth<D: HeadlessDocument>(_ doc: D, in catalog: CommandCatalog<D>) -> Int {
        var copy = doc, count = 0
        while count < 1000, catalog.history(copy).canUndo, (try? catalog.run("edit.undo", params: .object([:]), on: &copy)) != nil { count += 1 }
        return count
    }

    /// A run with params that are not an object must refuse and leave the bytes and the history as they were.
    static func refusal<D: HeadlessDocument>(_ id: String, in catalog: CommandCatalog<D>, fixture: D) -> [String] {
        var doc = fixture
        guard (try? catalog.run(id, params: .string("not params"), on: &doc)) == nil else { return [] }
        let same = (try? doc.save()) == (try? fixture.save()) && catalog.history(doc).undoName == catalog.history(fixture).undoName
        return same ? [] : [CatalogLaw.refusalChangesNothing.problem(id, "a refused run changed the document")]
    }

    /// `describe` exists and its description survives a JSON round trip unchanged.
    static func describes<D>(_ id: String, in catalog: CommandCatalog<D>) -> [String] {
        guard let description = catalog.describe(id) else { return [CatalogLaw.describeRoundTrips.problem(id, "describe returned nothing")] }
        let back = try? JSONDecoder().decode(CommandDescription.self, from: JSONEncoder().encode(description))
        return back == description ? [] : [CatalogLaw.describeRoundTrips.problem(id, "its description does not survive a JSON round trip")]
    }
}
