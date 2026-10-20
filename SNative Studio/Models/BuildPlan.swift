import Foundation

struct FileInspection: Equatable, Sendable {
    var exists: Bool
    var isDirectory: Bool
    var isReadable: Bool
    var isWritable: Bool
    var byteCount: Int64
}

struct BuildFacts: Equatable, Sendable {
    var engineRoot: String?
    var scriptExists: Bool
    var translatorExists: Bool
    var tools: [String: String]
    var missingPythonModules: [String]
    var environment: [String: String]
    var files: [String: FileInspection]
    var siblingNSPNames: [String]
    var profileIPANames: [String: String]
    /// True only when the resolved engine is the packaged copy. An external checkout does not receive SNATIVE_TOOL_PATH.
    var prefersPackagedTools: Bool = false
}

struct BuildCommand: Equatable, Sendable {
    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: String
    var expectedIPA: String
    var nspDirectory: String
}

struct IPANameError: Error, Equatable, Sendable {
    var message: String
}

enum BuildPlanResult: Equatable, Sendable {
    case ready(BuildCommand, summary: String)
    case needsOverwrite(path: String, command: BuildCommand, summary: String)
    case blocked(String)
}

protocol BuildPlanning: Sendable {
    func plan(draft: ProjectDraft, allowOverwrite: Bool) -> BuildPlanResult
}

enum BuildPlanner {
    /// Ejecutables que `check_prereqs` exige, más `python3`, que es el intérprete del comando documentado.
    static let requiredTools = ["python3", "xcodebuild", "xcodegen", "dotnet", "zstd", "spirv-cross", "zip", "make"]

    static func outputIPAPath(draft: ProjectDraft, profileIPANames: [String: String]) -> String? {
        guard case .success(let ipaName) = ipaFileName(draft: draft, profileIPANames: profileIPANames),
              !draft.outputDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(fileURLWithPath: draft.outputDirectory).appendingPathComponent(ipaName).path
    }

    static func ipaFileName(draft: ProjectDraft, profileIPANames: [String: String]) -> Result<String, IPANameError> {
        let typed = draft.ipaName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            guard let safe = sanitizedIPAName(typed) else {
                return .failure(IPANameError(message: "El nombre de la IPA no es válido. Tiene que terminar en .ipa y no puede incluir carpetas."))
            }
            return .success(safe)
        }
        let baseName = URL(fileURLWithPath: draft.baseNSP).lastPathComponent
        if let identifier = TitleIdentity.applicationID(in: baseName), let profileName = profileIPANames[identifier] {
            return .success(profileName)
        }
        return .failure(IPANameError(message: "Indica un nombre de IPA o elige un NSP base cuyo título tenga la clave ipa en el perfil. SNative Studio no abre el NSP ni inventa ese nombre."))
    }

    static func sanitizedIPAName(_ name: String) -> String? {
        guard name.hasSuffix(".ipa"), name != ".ipa", !name.hasPrefix(".") else { return nil }
        guard !name.contains("/"), !name.contains("\\"), !name.contains("..") else { return nil }
        return name
    }

    static func decide(draft: ProjectDraft, facts: BuildFacts, allowOverwrite: Bool) -> BuildPlanResult {
        guard let root = facts.engineRoot, facts.scriptExists else {
            return .blocked(EngineLocator.absentMessage)
        }
        guard facts.translatorExists else {
            return .blocked("El repositorio no contiene el traductor dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate.")
        }

        let missingTools = requiredTools.filter { facts.tools[$0] == nil }
        if !missingTools.isEmpty {
            var message = "Faltan herramientas: \(missingTools.joined(separator: ", ")). SNative Studio no las instala."
            if missingTools.contains("xcodebuild") {
                message += " xcodebuild, el SDK de iOS y el compilador Metal tienen que estar instalados con Xcode."
            }
            return .blocked(message)
        }
        if !facts.missingPythonModules.isEmpty {
            return .blocked("Faltan módulos de Python: \(facts.missingPythonModules.joined(separator: ", ")). El script importa lz4.block, capstone y fontTools. SNative Studio no los instala.")
        }

        let validation = ProjectValidation.evaluate(draft) { path in
            guard let file = facts.files[path] else { return nil }
            return PathFacts(exists: file.exists, isDirectory: file.isDirectory)
        }
        guard validation.isComplete else { return .blocked(validation.summary) }

        if let problem = fileProblem("NSP del juego base", facts.files[draft.baseNSP]) { return .blocked(problem) }
        if !draft.updateNSP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let problem = fileProblem("NSP de actualización", facts.files[draft.updateNSP]) {
            return .blocked(problem)
        }
        if let problem = fileProblem("prod.keys", facts.files[draft.prodKeys]) { return .blocked(problem) }
        guard let output = facts.files[draft.outputDirectory], output.isDirectory, output.isWritable else {
            return .blocked("La carpeta de salida no existe o no admite escritura.")
        }

        let baseDirectory = URL(fileURLWithPath: draft.baseNSP).resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL
        if !draft.updateNSP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let updateDirectory = URL(fileURLWithPath: draft.updateNSP).resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL
            guard baseDirectory.path == updateDirectory.path else {
                return .blocked("El script oficial recibe una carpeta con los NSP, no archivos sueltos. El juego base y la actualización tienen que estar en la misma carpeta.")
            }
        }

        let families = TitleIdentity.families(in: facts.siblingNSPNames)
        if families.count > 1 {
            return .blocked("La carpeta contiene NSP de más de un juego (\(families.sorted().joined(separator: ", "))). El script exige un solo juego por carpeta.")
        }

        let baseName = URL(fileURLWithPath: draft.baseNSP).lastPathComponent
        let applicationID = TitleIdentity.applicationID(in: baseName)
        if !draft.updateNSP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let applicationID,
           let updateID = TitleIdentity.applicationID(in: URL(fileURLWithPath: draft.updateNSP).lastPathComponent),
           updateID != applicationID {
            return .blocked("El título del NSP de actualización no corresponde al juego base.")
        }
        let ipaName: String
        switch ipaFileName(draft: draft, profileIPANames: facts.profileIPANames) {
        case .success(let name):
            ipaName = name
        case .failure(let error):
            return .blocked(error.message)
        }
        let outputPath = URL(fileURLWithPath: draft.outputDirectory).appendingPathComponent(ipaName).path
        if let existing = facts.files[outputPath], existing.exists, existing.isDirectory {
            return .blocked("La ruta prevista de la IPA es una carpeta: \(outputPath).")
        }

        guard let python = facts.tools["python3"] else {
            return .blocked("No se encuentra python3.")
        }
        let script = URL(fileURLWithPath: root).appendingPathComponent("scripts/build_ipa_from_nsp.py").path
        var environment = facts.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONIOENCODING"] = "utf-8"
        if let dotnet = facts.tools["dotnet"] {
            let dotnetRoot = URL(fileURLWithPath: dotnet).deletingLastPathComponent().path
            environment["DOTNET_ROOT"] = dotnetRoot
            environment["DOTNET_ROOT_ARM64"] = dotnetRoot
        }

        environment = pathPrependingToolDirectories(environment, tools: facts.tools)
        if facts.prefersPackagedTools, let packagedTools = packagedToolPath(engineRoot: root, tools: facts.tools) {
            environment["SNATIVE_TOOL_PATH"] = packagedTools
        }
        let command = BuildCommand(
            executable: python,
            arguments: [script, baseDirectory.path, "-k", draft.prodKeys, "-o", outputPath, "--progress", "lines"],
            environment: environment,
            workingDirectory: root,
            expectedIPA: outputPath,
            nspDirectory: baseDirectory.path
        )
        let workFolder = applicationID.map { "\(baseDirectory.path)/\($0)_build" } ?? "la carpeta de trabajo del script, junto a los NSP"
        let summary = "Motor en \(root). La IPA se escribirá en \(outputPath). Los intermedios y la caché quedan en \(workFolder)."
        if let existing = facts.files[outputPath], existing.exists, !existing.isDirectory, !allowOverwrite {
            return .needsOverwrite(path: outputPath, command: command, summary: summary)
        }
        return .ready(command, summary: summary)
    }

    /// Puts the directories of the tools this plan selected ahead of PATH for this process only.
    /// The packaged script then prepends SNATIVE_TOOL_PATH to its own TOOL_PATHS. The user's login PATH is left unchanged.
    static func packagedToolPath(engineRoot: String, tools: [String: String]) -> String? {
        let engine = URL(fileURLWithPath: engineRoot).standardizedFileURL
        guard engine.lastPathComponent == BundledLayout.engineDirectoryName else { return nil }
        let toolsRoot = BundledLayout.toolsDirectory(resources: engine.deletingLastPathComponent()).standardizedFileURL.path
        let prefix = toolsRoot.hasSuffix("/") ? toolsRoot : toolsRoot + "/"
        let preferred = ["python3", "dotnet", "xcodegen", "zstd", "spirv-cross"]
        var directories: [String] = []
        for name in preferred {
            guard let path = tools[name], !path.isEmpty else { continue }
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard standardized.hasPrefix(prefix) else { continue }
            let directory = URL(fileURLWithPath: standardized).deletingLastPathComponent().standardizedFileURL.path
            if !directories.contains(directory) {
                directories.append(directory)
            }
        }
        guard !directories.isEmpty else { return nil }
        return directories.joined(separator: ":")
    }

    /// Puts the directories of the tools this plan selected ahead of PATH for this process only.
    static func pathPrependingToolDirectories(_ environment: [String: String], tools: [String: String]) -> [String: String] {
        let preferred = ["python3", "dotnet", "xcodegen", "zstd", "spirv-cross"]
        var directories: [String] = []
        for name in preferred {
            guard let path = tools[name], !path.isEmpty else { continue }
            let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
            if !directories.contains(directory) {
                directories.append(directory)
            }
        }
        guard !directories.isEmpty else { return environment }
        var environment = environment
        let current = environment["PATH"] ?? ""
        var seen = Set<String>()
        let merged = (directories + current.split(separator: ":").map(String.init)).filter { seen.insert($0).inserted }
        environment["PATH"] = merged.joined(separator: ":")
        return environment
    }

    /// Points a launch at a writable engine copy and keeps MSBuild, NuGet and temp files outside the app bundle.
    static func applyingWritableEngine(
        _ result: BuildPlanResult,
        from engineRoot: String,
        to writableRoot: String,
        layout: EngineWorkLayout
    ) -> BuildPlanResult {
        switch result {
        case .blocked:
            return result
        case .ready(let command, let summary):
            return .ready(relocated(command, from: engineRoot, to: writableRoot, layout: layout), summary: relocatedSummary(summary, from: engineRoot, to: writableRoot))
        case .needsOverwrite(let path, let command, let summary):
            return .needsOverwrite(path: path, command: relocated(command, from: engineRoot, to: writableRoot, layout: layout), summary: relocatedSummary(summary, from: engineRoot, to: writableRoot))
        }
    }

    private static func relocated(_ command: BuildCommand, from engineRoot: String, to writableRoot: String, layout: EngineWorkLayout) -> BuildCommand {
        var command = command
        command.workingDirectory = relocate(command.workingDirectory, from: engineRoot, to: writableRoot)
        command.arguments = command.arguments.map { relocate($0, from: engineRoot, to: writableRoot) }
        var environment = command.environment
        environment["NUGET_PACKAGES"] = layout.nugetPackages.path
        environment["TMPDIR"] = layout.temporaryDirectory.path
        environment["TEMP"] = layout.temporaryDirectory.path
        environment["TMP"] = layout.temporaryDirectory.path
        environment["DOTNET_CLI_HOME"] = layout.dotnetHome.path
        environment["BaseIntermediateOutputPath"] = layout.intermediateOutput.path.hasSuffix("/") ? layout.intermediateOutput.path : layout.intermediateOutput.path + "/"
        environment["MSBuildProjectExtensionsPath"] = environment["BaseIntermediateOutputPath"]
        environment["BaseOutputPath"] = layout.buildOutput.path.hasSuffix("/") ? layout.buildOutput.path : layout.buildOutput.path + "/"
        command.environment = environment
        return command
    }

    private static func relocate(_ path: String, from source: String, to destination: String) -> String {
        let sourceURL = URL(fileURLWithPath: source).standardizedFileURL
        let pathURL = URL(fileURLWithPath: path).standardizedFileURL
        let prefix = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"
        guard pathURL.path == sourceURL.path || pathURL.path.hasPrefix(prefix) else { return path }
        let relative = pathURL.path == sourceURL.path ? "" : String(pathURL.path.dropFirst(prefix.count))
        return URL(fileURLWithPath: destination).appendingPathComponent(relative).path
    }

    private static func relocatedSummary(_ summary: String, from engineRoot: String, to writableRoot: String) -> String {
        summary.replacingOccurrences(of: engineRoot, with: writableRoot)
    }

    private static func fileProblem(_ title: String, _ file: FileInspection?) -> String? {
        guard let file, file.exists else { return "\(title): no existe." }
        if file.isDirectory { return "\(title): se esperaba un archivo." }
        if !file.isReadable { return "\(title): la ruta no es legible." }
        if file.byteCount == 0 { return "\(title): el archivo está vacío." }
        return nil
    }
}
