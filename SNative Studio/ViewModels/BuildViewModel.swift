import Foundation
import Observation

@MainActor
@Observable
final class BuildViewModel {
    private(set) var snapshot: BuildSnapshot
    private(set) var readiness = "Selecciona un proyecto guardado para comprobar sus rutas."
    private(set) var isEvaluating = false
    private(set) var overwritePath: String?
    private(set) var compiledProjectID: UUID?
    private var pendingCommand: BuildCommand?
    private var plannedIPA: String?
    private var request = 0
    private var handle: (any RunningBuild)?
    private let planner: any BuildPlanning
    private let launcher: any BuildLaunching
    private let ipaExists: @Sendable (String) -> Bool
    private let gate = MainGate()
    var environmentGate: @MainActor () -> String? = { nil }

    var isRunning: Bool { snapshot.status == .running }

    init(
        snapshot: BuildSnapshot = .idle,
        planner: any BuildPlanning = LiveBuildPlanner(),
        launcher: any BuildLaunching = FoundationBuildLauncher(),
        ipaExists: @escaping @Sendable (String) -> Bool = LiveIPACheck.exists
    ) {
        self.snapshot = snapshot
        self.planner = planner
        self.launcher = launcher
        self.ipaExists = ipaExists
    }

    func refresh(draft: ProjectDraft) async {
        await evaluate(draft: draft, launch: false)
    }

    func generate(draft: ProjectDraft) async {
        await evaluate(draft: draft, launch: true)
    }

    func confirmOverwrite() {
        guard let command = pendingCommand, !isRunning else { return }
        if let message = environmentGate() {
            readiness = message
            pendingCommand = nil
            overwritePath = nil
            return
        }
        pendingCommand = nil
        overwritePath = nil
        launch(command)
    }

    func dismissOverwrite() {
        pendingCommand = nil
        overwritePath = nil
    }

    func cancel() {
        guard isRunning else { return }
        BuildLogReducer.cancel(&snapshot)
        handle?.cancel()
    }

    func elapsed(at date: Date) -> TimeInterval {
        snapshot.elapsed(at: date)
    }

    private func evaluate(draft: ProjectDraft, launch shouldLaunch: Bool) async {
        guard !isRunning else { return }
        compiledProjectID = draft.id
        request += 1
        let token = request
        if let message = environmentGate() {
            readiness = message
            pendingCommand = nil
            overwritePath = nil
            return
        }
        isEvaluating = true
        let planner = self.planner
        let result = await Task.detached(priority: .userInitiated) {
            planner.plan(draft: draft, allowOverwrite: false)
        }.value
        isEvaluating = false
        guard token == request, !isRunning else { return }
        if let message = environmentGate() {
            readiness = message
            pendingCommand = nil
            overwritePath = nil
            return
        }
        switch result {
        case .ready(let command, let summary):
            readiness = summary
            pendingCommand = nil
            overwritePath = nil
            if shouldLaunch { launch(command) }
        case .needsOverwrite(let path, let command, let summary):
            readiness = summary
            if shouldLaunch {
                pendingCommand = command
                overwritePath = path
            }
        case .blocked(let message):
            readiness = message
            pendingCommand = nil
            overwritePath = nil
        }
    }

    private func launch(_ command: BuildCommand) {
        snapshot.status = .running
        snapshot.phases = []
        snapshot.progress = nil
        snapshot.ipaPath = nil
        snapshot.announcedIPA = nil
        snapshot.startedAt = Date()
        snapshot.finishedAt = nil
        snapshot.message = "Ejecutando scripts/build_ipa_from_nsp.py."
        snapshot.log = """
        SNative Studio ejecuta el script oficial.
        Carpeta de NSP: \(command.nspDirectory)
        IPA prevista: \(command.expectedIPA)
        Los intermedios y la caché quedan en la carpeta de los NSP.

        """
        plannedIPA = command.expectedIPA
        let running = launcher.make(command)
        handle = running
        let gate = self.gate
        gate.model = self
        running.onLine = { line in
            gate.deliver(line) { model, line in model.consume(line) }
        }
        running.onExit = { code in
            gate.deliver(code) { model, code in model.finish(code) }
        }
        do {
            try running.start()
        } catch {
            snapshot.status = .failed
            snapshot.finishedAt = Date()
            snapshot.message = "No se pudo iniciar el proceso: \(error.localizedDescription)"
            snapshot.log += "SNative Studio: \(snapshot.message)\n"
            handle = nil
        }
    }

    fileprivate func consume(_ line: String) {
        if snapshot.status == .cancelled {
            snapshot.log += line + "\n"
            return
        }
        guard snapshot.status == .running else { return }
        BuildLogReducer.apply(line, to: &snapshot)
    }

    fileprivate func finish(_ code: Int32) {
        guard let plannedIPA else { return }
        BuildLogReducer.finish(&snapshot, exitCode: code, plannedIPA: plannedIPA, ipaExists: ipaExists)
        handle = nil
    }
}

private final class MainGate: @unchecked Sendable {
    weak var model: BuildViewModel?

    func deliver<Value: Sendable>(_ value: Value, body: @escaping @MainActor (BuildViewModel, Value) -> Void) {
        let gate = self
        let hop = {
            MainActor.assumeIsolated {
                if let model = gate.model {
                    body(model, value)
                }
            }
        }
        if Thread.isMainThread {
            hop()
        } else {
            DispatchQueue.main.async(execute: hop)
        }
    }
}
